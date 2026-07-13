#!/usr/bin/env bash
#
# Installation de la couche RP ESX (framework ESX Legacy + stack « ox ») :
#   1. clone/télécharge chaque ressource à une révision ÉPINGLÉE dans
#      data/resources/<catégorie>/ (idempotent : re-run = re-pin) ;
#   2. copie les overrides (overrides/) par-dessus les clones ;
#   3. importe le schéma SQL ESX (sql/esx-base.sql, versionné dans le dépôt) +
#      le SQL des ressources maison, si la stack MariaDB tourne.
#
# Le dépôt git du projet ne versionne QUE overrides/, resources/[custom] et sql/ ;
# tout ce que ce script télécharge vit dans data/resources (gitignoré).
#
# ⚠️  PINS À VÉRIFIER : ce script a été (re)généré lors de la migration QBCore→ESX
#     SANS accès réseau. Les révisions ci-dessous (tags/branches) sont les refs
#     ESX/ox attendues mais doivent être CONFIRMÉES au premier `make resources`
#     (un `fetch` qui échoue = ref à corriger). Épingler ensuite sur un SHA.
#
set -euo pipefail

cd "$(dirname "$0")/.."   # racine du projet

log() { echo "[resources] $*"; }
die() { echo "[resources] ERREUR : $*" >&2; exit 1; }

# Charge .env sans l'exécuter (les valeurs peuvent contenir des espaces).
load_env() {
    [[ -f .env ]] || return 0
    local key val
    while IFS='=' read -r key val; do
        [[ "${key}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
        export "${key}=${val}"
    done < <(grep -v '^[[:space:]]*#' .env | grep '=')
}
load_env

RES_DIR="data/resources"
SQL_MARKER="data/.esx-sql-imported"

# Schéma ESX officiel : fourni par le monorepo esx_core dans data/resources/[SQL]/
# (legacy.sql), importé par import_sql après l'installation d'esx_core.
ESX_SQL_DIR="${RES_DIR}/[SQL]"

# --- Ressources distribuées en RELEASE BUILDÉE (zip) --------------------------
# (elles embarquent un build web/dist absent du clone source).
OXMYSQL_VERSION="v2.9.1"
OXMYSQL_URL="https://github.com/overextended/oxmysql/releases/download/${OXMYSQL_VERSION}/oxmysql.zip"

OXLIB_VERSION="v3.38.0"
OXLIB_URL="https://github.com/overextended/ox_lib/releases/download/${OXLIB_VERSION}/ox_lib.zip"

OXINV_VERSION="v2.47.8"
OXINV_URL="https://github.com/overextended/ox_inventory/releases/download/${OXINV_VERSION}/ox_inventory.zip"

OXTARGET_VERSION="v1.18.1"
OXTARGET_URL="https://github.com/overextended/ox_target/releases/download/${OXTARGET_VERSION}/ox_target.zip"


# ESX Legacy est distribué en MONOREPO `esx_core` : il embarque es_extended,
# esx_identity, esx_multicharacter, esx_skin/skinchanger, esx_menu_*/esx_context/
# esx_notify/esx_textui/esx_progressbar (dans [core]/) + le schéma SQL (dans [SQL]/).
# On le clone puis on APLATIT ses dossiers catégorie dans data/resources.
ESX_CORE_VERSION="1.13.5"
ESX_CORE_URL="https://github.com/esx-framework/esx_core"

# -----------------------------------------------------------------------------
# Ressources clonées (git). Format : catégorie|nom|url|révision
# NB : esx_identity / esx_multicharacter / esx_skin / esx_menu_* viennent du
# monorepo esx_core (install_esx_core), pas d'entrées séparées ici.
# Les métiers ESX (police/ambulance/…) ne sont PAS sous l'org esx-framework en
# dépôts séparés (intégrés/déplacés) → à sourcer en Phase 2 (voir README/CHANGELOG).
# -----------------------------------------------------------------------------
RESOURCES=(
    # --- Standalone (framework-agnostiques) -----------------------------------
    "[standalone]|PolyZone|https://github.com/mkafrin/PolyZone|master"
    "[standalone]|interact-sound|https://github.com/plunkettscott/interact-sound|master"
    "[standalone]|rpemotes-reborn|https://github.com/alberttheprince/rpemotes-reborn|master"
    "[standalone]|LegacyFuel|https://github.com/InZidiuz/LegacyFuel|master"
    # --- Apparence : fivem-appearance ESX + ox_lib (build web/game committé).
    # Remplace esx_skin/skinchanger (corrige les pieds/peau invisibles) ET fournit
    # la compat `skinchanger:modelLoaded` que es_extended attend pour finir le spawn.
    "[core]|fivem-appearance|https://github.com/wasabirobby/fivem-appearance|1.3.0"
)

command -v git >/dev/null || die "git est requis"
command -v curl >/dev/null || die "curl est requis"

# --- 1. Clonage épinglé (idempotent via marqueur .pin) ------------------------
fetch_pinned() {
    local category="$1" name="$2" url="$3" ref="$4"
    local dest="${RES_DIR}/${category}/${name}"

    if [[ -f "${dest}/.pin" && "$(cat "${dest}/.pin")" == "${ref}" ]]; then
        log "  ${name} déjà à ${ref} — ignoré"
        return 0
    fi

    log "  ${name} @ ${ref}..."
    rm -rf "${dest}"
    mkdir -p "${dest}"
    git init -q "${dest}"
    git -C "${dest}" remote add origin "${url}"
    git -C "${dest}" fetch -q --depth 1 origin "${ref}" \
        || die "fetch impossible : ${name} @ ${ref} (${url}) — vérifier la ref (voir en-tête)"
    git -C "${dest}" checkout -q FETCH_HEAD
    rm -rf "${dest}/.git"                      # on ne garde que les fichiers
    echo "${ref}" > "${dest}/.pin"
}

# --- Installateur générique de release buildée (zip) --------------------------
# install_release_zip <categorie> <nom> <version> <url>
# Gère les deux formes d'archive : dossier <nom>/ englobant, ou fichiers à la racine.
install_release_zip() {
    local category="$1" name="$2" version="$3" url="$4"
    local dest="${RES_DIR}/${category}/${name}"
    if [[ -f "${dest}/.pin" && "$(cat "${dest}/.pin")" == "${version}" ]]; then
        log "  ${name} déjà en ${version} — ignoré"
        return 0
    fi
    log "  ${name} ${version} (release buildée)..."
    command -v unzip >/dev/null || die "unzip est requis pour ${name}"
    local tmp
    tmp="$(mktemp -d)"
    curl -fsSL --retry 3 -o "${tmp}/${name}.zip" "${url}" \
        || { rm -rf "${tmp}"; die "téléchargement ${name} impossible (${url})"; }
    rm -rf "${dest}"
    mkdir -p "${RES_DIR}/${category}"
    unzip -qo "${tmp}/${name}.zip" -d "${tmp}/extract"
    mv "${tmp}/extract/${name}" "${dest}" 2>/dev/null || mv "${tmp}/extract" "${dest}"
    echo "${version}" > "${dest}/.pin"
    rm -rf "${tmp}"
}

# ESX Legacy (monorepo esx_core) : clone puis aplatit les dossiers catégorie
# ([core]/es_extended, [core]/esx_menu_default...) dans data/resources. Idempotent
# via le marqueur .pin d'es_extended.
install_esx_core() {
    local marker="${RES_DIR}/[core]/es_extended/.pin"
    if [[ -f "${marker}" && "$(cat "${marker}")" == "${ESX_CORE_VERSION}" ]]; then
        log "  esx_core déjà en ${ESX_CORE_VERSION} — ignoré"
        return 0
    fi
    log "  esx_core ${ESX_CORE_VERSION} (monorepo ESX Legacy)..."
    local staging="${RES_DIR}/.esx_core_staging"
    rm -rf "${staging}"
    mkdir -p "${staging}"
    git init -q "${staging}"
    git -C "${staging}" remote add origin "${ESX_CORE_URL}"
    git -C "${staging}" fetch -q --depth 1 origin "${ESX_CORE_VERSION}" \
        || die "fetch impossible : esx_core @ ${ESX_CORE_VERSION} (${ESX_CORE_URL}) — vérifier la ref"
    git -C "${staging}" checkout -q FETCH_HEAD
    rm -rf "${staging}/.git"
    # Remonte le CONTENU (dossiers ressources ET fichiers, ex. [SQL]/legacy.sql)
    # de chaque dossier catégorie ([core], [SQL]...) dans data/resources.
    local cat catname
    for cat in "${staging}"/*/; do
        [[ -d "${cat}" ]] || continue
        catname="$(basename "${cat}")"
        case "${catname}" in
            \[*\]) ;;          # dossier catégorie -> on remonte son contenu
            *) continue ;;
        esac
        mkdir -p "${RES_DIR}/${catname}"
        cp -r "${cat}." "${RES_DIR}/${catname}/"
    done
    rm -rf "${staging}"
    [[ -d "${RES_DIR}/[core]/es_extended" ]] \
        || die "esx_core : es_extended introuvable après aplatissement (structure du monorepo modifiée ?)"
    echo "${ESX_CORE_VERSION}" > "${marker}"
}

log "Installation des ressources dans ${RES_DIR}/ ..."
mkdir -p "${RES_DIR}"
install_esx_core
install_release_zip "[standalone]" "oxmysql"             "${OXMYSQL_VERSION}"    "${OXMYSQL_URL}"
install_release_zip "[standalone]" "ox_lib"              "${OXLIB_VERSION}"      "${OXLIB_URL}"
install_release_zip "[core]"       "ox_inventory"        "${OXINV_VERSION}"      "${OXINV_URL}"
install_release_zip "[core]"       "ox_target"           "${OXTARGET_VERSION}"   "${OXTARGET_URL}"

# --- PHASE 3 (optionnel, DÉSACTIVÉ par défaut) : téléphone + housing ----------
# Ces ressources sont lourdes (build NUI, DB, config dédiée) et à VALIDER EN JEU.
# Pour les préparer : décommenter les lignes ci-dessous (+ ajuster versions/refs),
# puis décommenter les `ensure` correspondants dans config/server.cfg.template.
#
# Téléphone npwd (project-error/npwd) — release buildée, bridge ESX intégré.
#   Nécessite aussi une ressource voix (pma-voice) + import de son SQL (npwd.sql).
# install_release_zip "[standalone]" "npwd" "v2.4.0" \
#   "https://github.com/project-error/npwd/releases/download/v2.4.0/npwd.zip"
#
# Housing (au choix) — remplace ps-housing (QBCore) par une variante ESX :
#   loaf_housing (clone) OU esx_property. Ajouter l'entrée dans RESOURCES + son SQL.
#   Ex. RESOURCES : "[economy]|loaf_housing|https://github.com/<...>/loaf_housing|master"

for entry in "${RESOURCES[@]}"; do
    IFS='|' read -r category name url ref <<< "${entry}"
    fetch_pinned "${category}" "${name}" "${url}" "${ref}"
done

# --- Ajuste la disposition (idempotent, chaque run) ---------------------------
#  - MONO-PERSONNAGE : retire esx_multicharacter du disque. es_extended fait
#    `Config.Multichar = GetResourceState("esx_multicharacter") ~= "missing"` :
#    présent (même non-`ensure`) => Multichar=true => le joueur ne spawn jamais
#    (« waiting for script »). Absent => auto-chargement de l'unique perso.
#  - APPARENCE : retire esx_skin/skinchanger d'esx_core (remplacés par
#    fivem-appearance, qui fournit la compat skinchanger + corrige les pieds) et
#    l'ancien illenium-appearance (build qb-core, ne démarre pas sous ESX).
#  - Nettoie les résidus de l'ancienne couche QBCore.
finalize_esx_core_layout() {
    rm -rf "${RES_DIR}/[core]/esx_multicharacter" \
           "${RES_DIR}/[core]/esx_skin" \
           "${RES_DIR}/[core]/skinchanger" \
           "${RES_DIR}/[core]/illenium-appearance"
    rm -rf "${RES_DIR}/[core]/qb-"* "${RES_DIR}/[economy]" "${RES_DIR}/[jobs]" \
           "${RES_DIR}/[standalone]/fivem-freecam" 2>/dev/null || true
    log "  disposition ajustée : mono-perso (esx_multicharacter retiré), apparence = fivem-appearance"
}
finalize_esx_core_layout

# --- 2. Overrides (config es_extended, données ox_inventory) -------------------
# Chaque dossier overrides/<nom> est copié par-dessus la ressource <nom> installée.
apply_overrides() {
    [[ -d overrides ]] || return 0
    local src name target
    for src in overrides/*/; do
        [[ -d "${src}" ]] || continue   # aucun override (glob non étendu) → rien à faire
        name="$(basename "${src}")"
        target="$(find "${RES_DIR}" -mindepth 2 -maxdepth 2 -type d -name "${name}" | head -n1)"
        if [[ -z "${target}" ]]; then
            log "AVERTISSEMENT : override '${name}' sans ressource installée — ignoré"
            continue
        fi
        log "  override ${name} -> ${target}"
        cp -r "${src}." "${target}/"
    done
}
log "Application des overrides..."
apply_overrides

# --- 2b. Items custom dans ox_inventory (drogue / braquage) --------------------
# ox_inventory définit ses items dans data/items.lua ; on y AJOUTE nos items
# (sans remplacer le fichier, version-spécifique) juste après le `return {`.
# Idempotent via un marqueur commentaire. Requis par ubuntu-drogue/ubuntu-braquages.
append_ox_items() {
    local file
    file="$(find "${RES_DIR}" -path '*/ox_inventory/data/items.lua' -type f 2>/dev/null | head -n1)"
    if [[ -z "${file}" ]]; then
        log "ox_inventory/data/items.lua introuvable — items custom non ajoutés"
        return 0
    fi
    if grep -qF -- 'UBUNTU-RP items' "${file}"; then
        log "  items ox_inventory custom déjà présents — ignoré"
        return 0
    fi
    local block
    block=$'\t-- UBUNTU-RP items (ubuntu-drogue / ubuntu-braquages)\n\t[\'joint\'] = { label = \'Joint\', weight = 5, stack = true, close = true },\n\t[\'xtcbaggy\'] = { label = \'Ecstasy\', weight = 5, stack = true, close = true },\n\t[\'crack_baggy\'] = { label = \'Crack\', weight = 5, stack = true, close = true },\n\t[\'coke_baggy\'] = { label = \'Cocaine\', weight = 5, stack = true, close = true },\n\t[\'electronickit\'] = { label = \'Kit electronique\', weight = 500, stack = true, close = true },\n\t[\'thermite\'] = { label = \'Thermite\', weight = 1000, stack = true, close = true },'
    local tmp
    tmp="$(mktemp)"
    awk -v ins="${block}" '!done && /return[ \t]*[{]/ { print; print ins; done=1; next } { print }' \
        "${file}" > "${tmp}" && mv "${tmp}" "${file}"
    if grep -qF -- 'UBUNTU-RP items' "${file}"; then
        log "  items ox_inventory custom ajoutés (joint, baggies, electronickit, thermite)"
    else
        rm -f "${tmp}"
        log "  AVERTISSEMENT : insertion items ox_inventory échouée (pas de 'return {') — à ajouter à la main"
    fi
}
append_ox_items

# --- 3. Import du schéma SQL ESX (si la stack tourne) --------------------------
import_sql() {
    if [[ -f "${SQL_MARKER}" ]]; then
        log "Schéma SQL déjà importé (${SQL_MARKER} présent) — ignoré"
        return 0
    fi
    # On importe avec l'utilisateur applicatif (privilèges suffisants sur la base
    # du serveur) — plus robuste que root (le mot de passe root du volume peut différer).
    local dbuser="${MYSQL_USER:-fivem}" dbpass="${MYSQL_PASSWORD:-}" db="${MYSQL_DATABASE:-fivem}"
    if ! docker compose exec -T mariadb mariadb -u"${dbuser}" -p"${dbpass}" \
            -e "SELECT 1" "${db}" >/dev/null 2>&1; then
        log "MariaDB injoignable — lancez 'make up' puis relancez 'make resources' pour importer le SQL."
        return 0
    fi

    # Schéma ESX officiel : data/resources/[SQL]/legacy.sql (fourni par esx_core).
    if [[ -d "${ESX_SQL_DIR}" ]]; then
        local s
        for s in "${ESX_SQL_DIR}"/*.sql; do
            [[ -f "${s}" ]] || continue
            log "Import du schéma ESX officiel ($(basename "${s}"))..."
            docker compose exec -T mariadb mariadb -u"${dbuser}" -p"${dbpass}" "${db}" < "${s}" \
                || die "import du schéma ESX ($(basename "${s}")) échoué"
        done
    else
        log "AVERTISSEMENT : ${ESX_SQL_DIR} introuvable — schéma ESX officiel non importé (esx_core installé ?)"
    fi

    # SQL additionnels livrés par les ressources (es_extended.sql, ox_inventory...).
    # Non-fatals ; migrations exclues.
    local f
    while IFS= read -r f; do
        log "  import $(basename "$(dirname "${f}")")/$(basename "${f}")"
        docker compose exec -T mariadb mariadb -u"${dbuser}" -p"${dbpass}" \
            "${db}" < "${f}" 2>/dev/null \
            || log "  AVERTISSEMENT : import partiel (déjà couvert par le schéma officiel) — ignoré"
    done < <(find "${RES_DIR}" -mindepth 3 -maxdepth 4 -name '*.sql' \
                  ! -name 'migrate*' ! -iname '*upgrade*' | sort)

    touch "${SQL_MARKER}"
    log "SQL importé (supprimez ${SQL_MARKER} pour forcer un ré-import)."
}
import_sql

# --- 4. SQL des ressources maison ([custom]) ----------------------------------
# Idempotent (CREATE TABLE IF NOT EXISTS), rejoué à chaque `make resources`.
import_custom_sql() {
    [[ -d "resources/[custom]" ]] || return 0
    local dbuser="${MYSQL_USER:-fivem}" dbpass="${MYSQL_PASSWORD:-fivem}" db="${MYSQL_DATABASE:-fivem}"
    if ! docker compose exec -T mariadb mariadb -u"${dbuser}" -p"${dbpass}" \
            -e "SELECT 1" "${db}" >/dev/null 2>&1; then
        log "MariaDB injoignable — SQL des ressources [custom] non importé (relancez après 'make up')."
        return 0
    fi
    local f found=0
    while IFS= read -r f; do
        found=1
        log "  import [custom] $(basename "$(dirname "${f}")")/$(basename "${f}")"
        docker compose exec -T mariadb mariadb -u"${dbuser}" -p"${dbpass}" \
            "${db}" < "${f}" 2>/dev/null \
            || log "  AVERTISSEMENT : import [custom] partiel — ignoré"
    done < <(find "resources/[custom]" -mindepth 2 -maxdepth 2 -name '*.sql' | sort)
    [[ "${found}" -eq 1 ]] && log "SQL des ressources [custom] importé (idempotent)."
    return 0
}
import_custom_sql

log "Terminé. Ressources prêtes — (re)démarrez le serveur : make restart"
