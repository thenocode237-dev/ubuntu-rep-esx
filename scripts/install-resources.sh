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

# ESX addons (métiers + comptes société) : monorepo esx-framework/ESX-Legacy-Addons.
# Même modèle qu'esx_core, mais on copie SEULEMENT les addons voulus (clôture des
# dépendances d'esx_policejob + esx_property pour le housing). NE PAS aplatir tout
# [esx_addons] : il embarque esx_banking/esx_shops/esx_jobs/esx_garage/... qui
# entreraient en conflit avec ubuntu-banque et ajouteraient des jobs/shops par défaut.
# Le dépôt n'a PAS de release → on épingle un SHA de main (GitHub autorise le fetch SHA).
ESX_ADDONS_VERSION="a94ede6f0965947d5fe2cb145fd894e32220a1ff"
ESX_ADDONS_URL="https://github.com/esx-framework/ESX-Legacy-Addons"
# Clôture Phase 2 (police) : esx_policejob -> esx_billing + esx_vehicleshop ;
# esx_society -> cron (déjà dans esx_core) + esx_addonaccount ; + esx_datastore.
# esx_property = housing (Phase 3). esx_ambulancejob (EMS : mort/réanimation/détresse)
# = activé ; sa dépendance dure esx_skin est retirée par un override (fivem-appearance
# remplace esx_skin ; les appels skinchanger:* du vestiaire restent no-op non fatals,
# comme esx_policejob).
ESX_ADDONS=(esx_addonaccount esx_datastore esx_society esx_billing esx_vehicleshop esx_policejob esx_ambulancejob esx_property)

# -----------------------------------------------------------------------------
# Ressources clonées (git). Format : catégorie|nom|url|révision
# NB : esx_identity / esx_multicharacter / esx_skin / esx_menu_* viennent du
# monorepo esx_core (install_esx_core), pas d'entrées séparées ici.
# Les métiers ESX (police/ambulance/…) vivent dans le MONOREPO officiel
# esx-framework/ESX-Legacy-Addons (dossiers [esx_addons]/) — installés sélectivement
# par install_esx_addons (ci-dessus), pas d'entrées séparées ici.
# -----------------------------------------------------------------------------
RESOURCES=(
    # --- Standalone (framework-agnostiques) -----------------------------------
    "[standalone]|PolyZone|https://github.com/mkafrin/PolyZone|master"
    "[standalone]|interact-sound|https://github.com/plunkettscott/interact-sound|master"
    "[standalone]|rpemotes-reborn|https://github.com/alberttheprince/rpemotes-reborn|master"
    "[standalone]|LegacyFuel|https://github.com/InZidiuz/LegacyFuel|master"
    # --- MLO : intérieur d'hôpital Pillbox (map streamée, framework-agnostique) ---
    # Nettoie/remplace la coquille Pillbox vanilla → toutes les coords ESX existantes
    # (esx_ambulancejob : blip/pharmacie EMS/vestiaire/spawns/respawn) restent valides.
    # Pas de tag amont → épinglé sur `master` (noter le SHA courant en live pour un pin
    # reproductible). ⚠️ Licence non explicite côté amont : vérifier avant usage public
    # (alternative gratuite : github.com/evgenius33/Pillbox-Hospital-Interior).
    "[standalone]|PillboxHospital|https://github.com/jobscraft/PillboxHospital-by-Jobscraft|master"
    # --- Apparence : fivem-appearance ESX + ox_lib (build web/game committé).
    # Remplace esx_skin/skinchanger (corrige les pieds/peau invisibles) ET fournit
    # la compat `skinchanger:modelLoaded` que es_extended attend pour finir le spawn.
    "[core]|fivem-appearance|https://github.com/wasabirobby/fivem-appearance|1.3.0"
    # --- Phase 3 : voix + téléphone -------------------------------------------
    # pma-voice : voix de proximité (mumble natif) — support des appels du téléphone.
    "[standalone]|pma-voice|https://github.com/AvarianKnight/pma-voice|v7.0.0"
    # z-phone : téléphone open-source ESX/ox (NUI pré-buildée, aucun build node).
    # Framework forcé en ESX par configure_zphone (défaut du dépôt = QBX).
    "[standalone]|z-phone|https://github.com/alfaben12/z-phone|v3.0.0"
    # --- Contenu « otaku » / anime (gratuit) ----------------------------------
    # Katana thermique add-on (arme de mêlée, glow anime) — ressource libre GitHub,
    # compatible ox_inventory. Déclarée dans weapons.lua + vendue à l'armurerie par
    # append_custom_weapons (ci-dessous). Crédit : bobodori (GTA5-mods). ⚠️ Licence
    # non explicite côté amont : vérifier avant usage public (même statut que Pillbox).
    "[standalone]|ThermalKatana|https://github.com/koolaash/ThermalKatana|6bc38edf127cb488324b39d4fd59c5f96f1a267b"
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

# ESX addons (monorepo ESX-Legacy-Addons) : clone en staging puis copie SÉLECTIVE des
# dossiers de ${ESX_ADDONS[@]} dans data/resources/[esx_addons]/. Idempotent via .pin.
install_esx_addons() {
    local marker="${RES_DIR}/[esx_addons]/.pin"
    # Idempotent SEULEMENT si le pin correspond ET que tous les addons voulus sont
    # présents : ajouter un nom à ${ESX_ADDONS[@]} (ex. esx_ambulancejob) doit
    # re-déclencher le clone même si la version n'a pas bougé.
    if [[ -f "${marker}" && "$(cat "${marker}")" == "${ESX_ADDONS_VERSION}" ]]; then
        local have_all=1 a
        for a in "${ESX_ADDONS[@]}"; do
            [[ -d "${RES_DIR}/[esx_addons]/${a}" ]] || { have_all=0; break; }
        done
        if [[ "${have_all}" -eq 1 ]]; then
            log "  esx addons déjà en ${ESX_ADDONS_VERSION} — ignoré"
            return 0
        fi
        log "  esx addons : nouvel addon demandé absent du disque — re-clonage..."
    fi
    log "  esx addons ${ESX_ADDONS_VERSION} (monorepo ESX-Legacy-Addons, sélectif)..."
    local staging="${RES_DIR}/.esx_addons_staging"
    rm -rf "${staging}"
    mkdir -p "${staging}"
    git init -q "${staging}"
    git -C "${staging}" remote add origin "${ESX_ADDONS_URL}"
    git -C "${staging}" fetch -q --depth 1 origin "${ESX_ADDONS_VERSION}" \
        || die "fetch impossible : ESX-Legacy-Addons @ ${ESX_ADDONS_VERSION} (${ESX_ADDONS_URL}) — vérifier la ref"
    git -C "${staging}" checkout -q FETCH_HEAD
    rm -rf "${staging}/.git"
    mkdir -p "${RES_DIR}/[esx_addons]"
    local name src dest
    for name in "${ESX_ADDONS[@]}"; do
        src="${staging}/[esx_addons]/${name}"
        dest="${RES_DIR}/[esx_addons]/${name}"
        [[ -d "${src}" ]] || die "addon introuvable dans le monorepo : ${name} (structure [esx_addons] modifiée ?)"
        rm -rf "${dest}"
        cp -r "${src}" "${dest}"
    done
    rm -rf "${staging}"
    echo "${ESX_ADDONS_VERSION}" > "${marker}"
}

log "Installation des ressources dans ${RES_DIR}/ ..."
mkdir -p "${RES_DIR}"
install_esx_core
install_esx_addons
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
    block=$'\t-- UBUNTU-RP items (ubuntu-drogue / ubuntu-braquages)\n\t[\'joint\'] = { label = \'Joint\', weight = 5, stack = true, close = true },\n\t[\'xtcbaggy\'] = { label = \'Ecstasy\', weight = 5, stack = true, close = true },\n\t[\'crack_baggy\'] = { label = \'Crack\', weight = 5, stack = true, close = true },\n\t[\'coke_baggy\'] = { label = \'Cocaine\', weight = 5, stack = true, close = true },\n\t[\'electronickit\'] = { label = \'Kit electronique\', weight = 500, stack = true, close = true },\n\t[\'thermite\'] = { label = \'Thermite\', weight = 1000, stack = true, close = true },\n\t-- UBUNTU-RP premium items (ubuntu-premium — QoL non pay-to-win)\n\t[\'premium_snack\'] = { label = \'En-cas premium\', weight = 150, stack = true, close = true, consume = 1, client = { status = { hunger = 150000 }, usetime = 2500 } },\n\t[\'premium_drink\'] = { label = \'Boisson premium\', weight = 150, stack = true, close = true, consume = 1, client = { status = { thirst = 150000 }, usetime = 2000 } },\n\t[\'premium_coffee\'] = { label = \'Cafe premium\', weight = 100, stack = true, close = true, consume = 1, client = { status = { thirst = 80000, stress = -40000 }, usetime = 2000 } },\n\t[\'premium_giftbox\'] = { label = \'Coffret cadeau\', weight = 200, stack = true, close = true },'
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

# --- 2c. Téléphone achetable en supérette -------------------------------------
# z-phone EXIGE l'item `phone` pour s'ouvrir (callback serveur HasPhone) ; sans
# point de vente il est inaccessible. On ajoute `phone` à la boutique GENERAL
# (supérettes 24/7) d'ox_inventory à 10 000 $. Idempotent via marqueur commentaire.
append_phone_to_shop() {
    local file
    file="$(find "${RES_DIR}" -path '*/ox_inventory/data/shops.lua' -type f 2>/dev/null | head -n1)"
    if [[ -z "${file}" ]]; then
        log "ox_inventory/data/shops.lua introuvable — téléphone non ajouté en boutique"
        return 0
    fi
    if grep -qF -- 'UBUNTU-RP phone' "${file}"; then
        log "  téléphone déjà vendu en supérette — ignoré"
        return 0
    fi
    local tmp
    tmp="$(mktemp)"
    # Insère la ligne juste après le `inventory = {` de la boutique GENERAL (1re boutique).
    awk '
        /General[ \t]*=[ \t]*\{/ { ingeneral=1 }
        ingeneral && !done && /inventory[ \t]*=[ \t]*\{/ {
            print
            print "\t\t\t{ name = \x27phone\x27, price = 10000 }, -- UBUNTU-RP phone"
            done=1; ingeneral=0; next
        }
        { print }
    ' "${file}" > "${tmp}" && mv "${tmp}" "${file}"
    if grep -qF -- 'UBUNTU-RP phone' "${file}"; then
        log "  téléphone ajouté en supérette (item phone, 10 000 $)"
    else
        rm -f "${tmp}"
        log "  AVERTISSEMENT : ajout du téléphone en supérette échoué (structure shops.lua modifiée ?)"
    fi
}
append_phone_to_shop

# --- 2c-bis. Arsenal complet à l'armurerie civile (Ammunation) -----------------
# Par défaut, l'armurerie civile d'ox_inventory ne vend que couteau/batte/pistolet.
# On y AJOUTE l'arsenal STANDARD (armes blanches libres + armes à feu gatées
# license='weapon' + munitions), SANS explosifs (pas de RPG/minigun/grenades).
# Le permis d'arme s'accorde via le panel ubuntu-admin (action weaponlicense).
# Noms d'items validés contre ox_inventory/data/weapons.lua. Idempotent (marqueur).
append_weapons_to_ammunation() {
    local file
    file="$(find "${RES_DIR}" -path '*/ox_inventory/data/shops.lua' -type f 2>/dev/null | head -n1)"
    if [[ -z "${file}" ]]; then
        log "ox_inventory/data/shops.lua introuvable — arsenal armurerie non ajouté"
        return 0
    fi
    if grep -qF -- 'UBUNTU-RP arsenal' "${file}"; then
        log "  arsenal armurerie déjà présent — ignoré"
        return 0
    fi
    # WEAPON_KNIFE/WEAPON_BAT/WEAPON_PISTOL/ammo-9 sont déjà dans le shop → omis ici.
    local block
    block=$'\t\t\t-- UBUNTU-RP arsenal (armes standard, sans explosifs)'
    block+=$'\n\t\t\t{ name = \'ammo-rifle\', price = 5 },'
    block+=$'\n\t\t\t{ name = \'ammo-shotgun\', price = 6 },'
    block+=$'\n\t\t\t{ name = \'ammo-sniper\', price = 10 },'
    block+=$'\n\t\t\t{ name = \'ammo-heavysniper\', price = 15 },'
    block+=$'\n\t\t\t{ name = \'ammo-50\', price = 8 },'
    block+=$'\n\t\t\t{ name = \'ammo-44\', price = 8 },'
    block+=$'\n\t\t\t{ name = \'ammo-45\', price = 5 },'
    block+=$'\n\t\t\t{ name = \'ammo-rifle2\', price = 5 },'
    block+=$'\n\t\t\t{ name = \'WEAPON_KNUCKLE\', price = 150 },'
    block+=$'\n\t\t\t{ name = \'WEAPON_NIGHTSTICK\', price = 150 },'
    block+=$'\n\t\t\t{ name = \'WEAPON_MACHETE\', price = 300 },'
    block+=$'\n\t\t\t{ name = \'WEAPON_HATCHET\', price = 300 },'
    block+=$'\n\t\t\t{ name = \'WEAPON_CROWBAR\', price = 200 },'
    block+=$'\n\t\t\t{ name = \'WEAPON_COMBATPISTOL\', price = 1500, metadata = { registered = true, ammo = 250 }, license = \'weapon\' },'
    block+=$'\n\t\t\t{ name = \'WEAPON_APPISTOL\', price = 2500, metadata = { registered = true, ammo = 250 }, license = \'weapon\' },'
    block+=$'\n\t\t\t{ name = \'WEAPON_SNSPISTOL\', price = 1200, metadata = { registered = true, ammo = 250 }, license = \'weapon\' },'
    block+=$'\n\t\t\t{ name = \'WEAPON_HEAVYPISTOL\', price = 2500, metadata = { registered = true, ammo = 250 }, license = \'weapon\' },'
    block+=$'\n\t\t\t{ name = \'WEAPON_VINTAGEPISTOL\', price = 2000, metadata = { registered = true, ammo = 250 }, license = \'weapon\' },'
    block+=$'\n\t\t\t{ name = \'WEAPON_PISTOL50\', price = 3000, metadata = { registered = true, ammo = 250 }, license = \'weapon\' },'
    block+=$'\n\t\t\t{ name = \'WEAPON_REVOLVER\', price = 3500, metadata = { registered = true, ammo = 250 }, license = \'weapon\' },'
    block+=$'\n\t\t\t{ name = \'WEAPON_PISTOLXM3\', price = 2800, metadata = { registered = true, ammo = 250 }, license = \'weapon\' },'
    block+=$'\n\t\t\t{ name = \'WEAPON_MICROSMG\', price = 6000, metadata = { registered = true, ammo = 250 }, license = \'weapon\' },'
    block+=$'\n\t\t\t{ name = \'WEAPON_SMG\', price = 7000, metadata = { registered = true, ammo = 250 }, license = \'weapon\' },'
    block+=$'\n\t\t\t{ name = \'WEAPON_ASSAULTSMG\', price = 8000, metadata = { registered = true, ammo = 250 }, license = \'weapon\' },'
    block+=$'\n\t\t\t{ name = \'WEAPON_COMBATPDW\', price = 8500, metadata = { registered = true, ammo = 250 }, license = \'weapon\' },'
    block+=$'\n\t\t\t{ name = \'WEAPON_MACHINEPISTOL\', price = 5000, metadata = { registered = true, ammo = 250 }, license = \'weapon\' },'
    block+=$'\n\t\t\t{ name = \'WEAPON_MINISMG\', price = 5500, metadata = { registered = true, ammo = 250 }, license = \'weapon\' },'
    block+=$'\n\t\t\t{ name = \'WEAPON_ASSAULTRIFLE\', price = 12000, metadata = { registered = true, ammo = 250 }, license = \'weapon\' },'
    block+=$'\n\t\t\t{ name = \'WEAPON_CARBINERIFLE\', price = 14000, metadata = { registered = true, ammo = 250 }, license = \'weapon\' },'
    block+=$'\n\t\t\t{ name = \'WEAPON_ADVANCEDRIFLE\', price = 15000, metadata = { registered = true, ammo = 250 }, license = \'weapon\' },'
    block+=$'\n\t\t\t{ name = \'WEAPON_SPECIALCARBINE\', price = 15000, metadata = { registered = true, ammo = 250 }, license = \'weapon\' },'
    block+=$'\n\t\t\t{ name = \'WEAPON_BULLPUPRIFLE\', price = 13000, metadata = { registered = true, ammo = 250 }, license = \'weapon\' },'
    block+=$'\n\t\t\t{ name = \'WEAPON_COMPACTRIFLE\', price = 11000, metadata = { registered = true, ammo = 250 }, license = \'weapon\' },'
    block+=$'\n\t\t\t{ name = \'WEAPON_MILITARYRIFLE\', price = 16000, metadata = { registered = true, ammo = 250 }, license = \'weapon\' },'
    block+=$'\n\t\t\t{ name = \'WEAPON_HEAVYRIFLE\', price = 16000, metadata = { registered = true, ammo = 250 }, license = \'weapon\' },'
    block+=$'\n\t\t\t{ name = \'WEAPON_TACTICALRIFLE\', price = 15000, metadata = { registered = true, ammo = 250 }, license = \'weapon\' },'
    block+=$'\n\t\t\t{ name = \'WEAPON_PUMPSHOTGUN\', price = 7000, metadata = { registered = true, ammo = 250 }, license = \'weapon\' },'
    block+=$'\n\t\t\t{ name = \'WEAPON_SAWNOFFSHOTGUN\', price = 6000, metadata = { registered = true, ammo = 250 }, license = \'weapon\' },'
    block+=$'\n\t\t\t{ name = \'WEAPON_ASSAULTSHOTGUN\', price = 9000, metadata = { registered = true, ammo = 250 }, license = \'weapon\' },'
    block+=$'\n\t\t\t{ name = \'WEAPON_BULLPUPSHOTGUN\', price = 8000, metadata = { registered = true, ammo = 250 }, license = \'weapon\' },'
    block+=$'\n\t\t\t{ name = \'WEAPON_COMBATSHOTGUN\', price = 9500, metadata = { registered = true, ammo = 250 }, license = \'weapon\' },'
    block+=$'\n\t\t\t{ name = \'WEAPON_HEAVYSHOTGUN\', price = 10000, metadata = { registered = true, ammo = 250 }, license = \'weapon\' },'
    block+=$'\n\t\t\t{ name = \'WEAPON_DBSHOTGUN\', price = 6500, metadata = { registered = true, ammo = 250 }, license = \'weapon\' },'
    block+=$'\n\t\t\t{ name = \'WEAPON_SNIPERRIFLE\', price = 18000, metadata = { registered = true, ammo = 250 }, license = \'weapon\' },'
    block+=$'\n\t\t\t{ name = \'WEAPON_MARKSMANRIFLE\', price = 16000, metadata = { registered = true, ammo = 250 }, license = \'weapon\' },'
    block+=$'\n\t\t\t{ name = \'WEAPON_HEAVYSNIPER\', price = 25000, metadata = { registered = true, ammo = 250 }, license = \'weapon\' },'
    block+=$'\n\t\t\t{ name = \'WEAPON_PRECISIONRIFLE\', price = 20000, metadata = { registered = true, ammo = 250 }, license = \'weapon\' },'
    local tmp
    tmp="$(mktemp)"
    # Insère le bloc juste après le `inventory = {` de la boutique Ammunation (civile).
    awk -v ins="${block}" '
        /Ammunation[ \t]*=[ \t]*\{/ { inammu=1 }
        inammu && !done && /inventory[ \t]*=[ \t]*\{/ {
            print; print ins; done=1; inammu=0; next
        }
        { print }
    ' "${file}" > "${tmp}" && mv "${tmp}" "${file}"
    if grep -qF -- 'UBUNTU-RP arsenal' "${file}"; then
        log "  arsenal ajouté à l'armurerie (pistolets/SMG/fusils/pompes/snipers + munitions)"
    else
        rm -f "${tmp}"
        log "  AVERTISSEMENT : ajout de l'arsenal échoué (structure shops.lua modifiée ?)"
    fi
}
append_weapons_to_ammunation

# --- 2c-ter. Pharmacie PUBLIQUE (civile) dans ox_inventory ---------------------
# La seule pharmacie existante (esx_ambulancejob) et le shop `Medicine` d'ox_inventory
# sont RÉSERVÉS au job `ambulance` (aucun civil ne peut se soigner). On AJOUTE un shop
# PUBLIC `Pharmacie` (sans `groups`) vendant bandage/medikit contre $, ciblé ox_target.
# Injecté juste après le `return {` de shops.lua. Idempotent (marqueur commentaire).
# Ne vend que medikit + bandage (seuls items médicaux présents dans data/items.lua).
append_pharmacy_shop() {
    local file
    file="$(find "${RES_DIR}" -path '*/ox_inventory/data/shops.lua' -type f 2>/dev/null | head -n1)"
    if [[ -z "${file}" ]]; then
        log "ox_inventory/data/shops.lua introuvable — pharmacie publique non ajoutée"
        return 0
    fi
    if grep -qF -- 'UBUNTU-RP pharmacie' "${file}"; then
        log "  pharmacie publique déjà présente — ignoré"
        return 0
    fi
    local block
    block=$'\tPharmacie = { -- UBUNTU-RP pharmacie'
    block+=$'\n\t\tname = \'Pharmacie\','
    block+=$'\n\t\tblip = { id = 51, colour = 25, scale = 0.9 },'
    block+=$'\n\t\tinventory = {'
    block+=$'\n\t\t\t{ name = \'bandage\', price = 250 },'
    block+=$'\n\t\t\t{ name = \'medikit\', price = 1500 },'
    block+=$'\n\t\t}, locations = {'
    block+=$'\n\t\t\tvec3(311.24, -593.52, 43.29), -- Entrée piétonne hôpital Pillbox (accessible)'
    block+=$'\n\t\t}, targets = {'
    block+=$'\n\t\t\t{ loc = vec3(311.24, -593.52, 43.29), length = 0.6, width = 0.6, heading = 0.0, minZ = 42.5, maxZ = 44.3, distance = 2.0 },'
    block+=$'\n\t\t}'
    block+=$'\n\t},'
    local tmp
    tmp="$(mktemp)"
    # Insère le nouveau shop juste après la 1re ligne `return {` du fichier shops.lua.
    awk -v ins="${block}" '
        !done && /return[ \t]*\{/ {
            print; print ins; done=1; next
        }
        { print }
    ' "${file}" > "${tmp}" && mv "${tmp}" "${file}"
    if grep -qF -- 'UBUNTU-RP pharmacie' "${file}"; then
        log "  pharmacie ajoutée en boutique (publique : bandage 250 $, medikit 1500 $)"
    else
        rm -f "${tmp}"
        log "  AVERTISSEMENT : ajout de la pharmacie publique échoué (structure shops.lua modifiée ?)"
    fi
}
append_pharmacy_shop

# --- 2c-quater. Armes custom (otaku) dans ox_inventory ------------------------
# Les armes add-on streamées (ThermalKatana) doivent être DÉCLARÉES dans
# ox_inventory/data/weapons.lua, sinon l'inventaire les ignore. On y AJOUTE nos
# armes juste après le `return {` (sans remplacer le fichier) PUIS on les met en
# vente à l'armurerie civile (shops.lua). Deux marqueurs distincts (weapons/shops)
# → indépendant du marqueur 'UBUNTU-RP arsenal', se ré-applique sur un install
# existant. Ajouter une arme custom = 1 ligne dans weap_block + 1 dans shop_line.
append_custom_weapons() {
    # (a) Déclaration dans weapons.lua ----------------------------------------
    local wfile
    wfile="$(find "${RES_DIR}" -path '*/ox_inventory/data/weapons.lua' -type f 2>/dev/null | head -n1)"
    if [[ -z "${wfile}" ]]; then
        log "ox_inventory/data/weapons.lua introuvable — armes custom non ajoutées"
        return 0
    fi
    if grep -qF -- 'UBUNTU-RP custom weapons' "${wfile}"; then
        log "  armes custom (katana) déjà déclarées — ignoré"
    else
        local weap_block
        weap_block=$'\t-- UBUNTU-RP custom weapons (otaku)'
        weap_block+=$'\n\t[\'WEAPON_THERMALKATANA\'] = { label = \'Katana thermique\', weight = 1000, durability = 0.0 },'
        local wtmp
        wtmp="$(mktemp)"
        awk -v ins="${weap_block}" '!done && /return[ \t]*[{]/ { print; print ins; done=1; next } { print }' \
            "${wfile}" > "${wtmp}" && mv "${wtmp}" "${wfile}"
        if grep -qF -- 'UBUNTU-RP custom weapons' "${wfile}"; then
            log "  arme custom déclarée dans weapons.lua (WEAPON_THERMALKATANA)"
        else
            rm -f "${wtmp}"
            log "  AVERTISSEMENT : déclaration WEAPON_THERMALKATANA échouée (pas de 'return {')"
        fi
    fi
    # (b) Mise en vente à l'armurerie (shops.lua) -----------------------------
    local sfile
    sfile="$(find "${RES_DIR}" -path '*/ox_inventory/data/shops.lua' -type f 2>/dev/null | head -n1)"
    [[ -n "${sfile}" ]] || return 0
    if grep -qF -- 'UBUNTU-RP katana' "${sfile}"; then
        log "  katana déjà vendu à l'armurerie — ignoré"
        return 0
    fi
    local stmp
    stmp="$(mktemp)"
    # Arme de mêlée → vendue librement (pas de license 'weapon'), comme la machette.
    awk '
        /Ammunation[ \t]*=[ \t]*\{/ { inammu=1 }
        inammu && !done && /inventory[ \t]*=[ \t]*\{/ {
            print
            print "\t\t\t{ name = \x27WEAPON_THERMALKATANA\x27, price = 6000 }, -- UBUNTU-RP katana"
            done=1; inammu=0; next
        }
        { print }
    ' "${sfile}" > "${stmp}" && mv "${stmp}" "${sfile}"
    if grep -qF -- 'UBUNTU-RP katana' "${sfile}"; then
        log "  katana ajouté à l'armurerie (WEAPON_THERMALKATANA, 6000 $)"
    else
        rm -f "${stmp}"
        log "  AVERTISSEMENT : ajout du katana à l'armurerie échoué (structure shops.lua modifiée ?)"
    fi
}
append_custom_weapons

# --- 2c-quinquies. Boissons de bar (ubuntu-boite) dans ox_inventory ------------
# Le bar de la boite de nuit (ubuntu-boite) vend des boissons qui doivent EXISTER
# dans ox_inventory/data/items.lua. On les AJOUTE juste après le `return {` (sans
# remplacer le fichier). Consommables (soif + un peu de stress en moins). Idempotent
# via marqueur commentaire. Ajouter une boisson = 1 ligne ici + 1 dans Config.Bar.drinks.
append_club_items() {
    local file
    file="$(find "${RES_DIR}" -path '*/ox_inventory/data/items.lua' -type f 2>/dev/null | head -n1)"
    if [[ -z "${file}" ]]; then
        log "ox_inventory/data/items.lua introuvable — boissons de bar non ajoutées"
        return 0
    fi
    if grep -qF -- 'UBUNTU-RP club items' "${file}"; then
        log "  boissons de bar déjà présentes — ignoré"
        return 0
    fi
    local block
    block=$'\t-- UBUNTU-RP club items (ubuntu-boite — bar de la boite de nuit)\n\t[\'biere\'] = { label = \'Biere\', weight = 350, stack = true, close = true, consume = 1, client = { status = { thirst = 120000, stress = -30000 }, usetime = 2000 } },\n\t[\'cocktail\'] = { label = \'Cocktail\', weight = 350, stack = true, close = true, consume = 1, client = { status = { thirst = 140000, stress = -50000 }, usetime = 2500 } },\n\t[\'shooter\'] = { label = \'Shooter\', weight = 120, stack = true, close = true, consume = 1, client = { status = { thirst = 60000, stress = -20000 }, usetime = 1500 } },\n\t[\'champagne\'] = { label = \'Champagne\', weight = 900, stack = true, close = true, consume = 1, client = { status = { thirst = 160000, stress = -70000 }, usetime = 3000 } },'
    local tmp
    tmp="$(mktemp)"
    awk -v ins="${block}" '!done && /return[ \t]*[{]/ { print; print ins; done=1; next } { print }' \
        "${file}" > "${tmp}" && mv "${tmp}" "${file}"
    if grep -qF -- 'UBUNTU-RP club items' "${file}"; then
        log "  boissons de bar ajoutées (biere, cocktail, shooter, champagne)"
    else
        rm -f "${tmp}"
        log "  AVERTISSEMENT : insertion boissons de bar échouée (pas de 'return {') — à ajouter à la main"
    fi
}
append_club_items

# --- 2c-sexies. Pack immobilier : maisons achetables (esx_property) ------------
# esx_property stocke les biens achetables dans data/resources/[esx_addons]/
# esx_property/properties.json (fichier réécrit AU RUNTIME par la ressource :
# SaveResourceFile lors des achats). On y AJOUTE une sélection de biens (villas /
# penthouses / appartements) SANS écraser le fichier ni l'état des propriétaires :
# fusion idempotente par `Name` (un bien déjà présent est ignoré). L'`Interior` de
# chaque bien réutilise un intérieur DÉJÀ défini dans esx_property/config.lua
# (Config.Interiors) → aucun MLO/override. Ajouter un bien = 1 entrée dans NEW_PROPS.
# Nécessite python3 (déjà utilisé pour les assets) ; non-fatal s'il manque.
append_properties() {
    local file
    file="$(find "${RES_DIR}" -path '*/esx_property/properties.json' -type f 2>/dev/null | head -n1)"
    if [[ -z "${file}" ]]; then
        log "esx_property/properties.json introuvable — pack immobilier non ajouté"
        return 0
    fi
    if ! command -v python3 >/dev/null 2>&1; then
        log "  AVERTISSEMENT : python3 absent — pack immobilier non ajouté (fusion JSON impossible)"
        return 0
    fi
    python3 - "${file}" <<'PY'
import json, sys

path = sys.argv[1]

# Biens à ajouter. `Interior` DOIT correspondre à un `value` de Config.Interiors
# (esx_property/config.lua). Coords d'entrée approximatives → à affiner en jeu.
NEW_PROPS = [
    {"Name": "Villa Vinewood Hills",   "Price": 550000, "Interior": "apa_v_mp_h_01_a",
     "Entrance": {"x": -174.94, "y": 502.56, "z": 137.42}},
    {"Name": "Penthouse Eclipse Towers","Price": 480000, "Interior": "apa_v_mp_h_02_a",
     "Entrance": {"x": -773.54, "y": 312.60, "z": 85.70}},
    {"Name": "Appartement Del Perro",  "Price": 165000, "Interior": "mid-end",
     "Entrance": {"x": -1447.06, "y": -538.83, "z": 34.74}},
    {"Name": "Appartement Vespucci",   "Price": 135000, "Interior": "mid-end",
     "Entrance": {"x": -1288.90, "y": -1116.80, "z": 6.70}},
    {"Name": "Studio Mirror Park",     "Price": 68000,  "Interior": "low-end",
     "Entrance": {"x": 1216.50, "y": -659.40, "z": 64.00}},
    {"Name": "Studio Sandy Shores",    "Price": 52000,  "Interior": "low-end",
     "Entrance": {"x": 1972.90, "y": 3815.50, "z": 32.40}},
]

DEFAULT_WARDROBE = {"x": 259.99, "y": -1003.46, "z": -99.01}

try:
    with open(path, "r", encoding="utf-8") as f:
        props = json.load(f)
    if not isinstance(props, list):
        raise ValueError("properties.json n'est pas un tableau JSON")
except Exception as e:
    print("  AVERTISSEMENT : lecture properties.json impossible (%s) — pack immobilier non ajouté" % e)
    sys.exit(0)

existing_names = {p.get("Name") for p in props if isinstance(p, dict)}

# Récupère un Wardrobe existant par Interior (pour rester cohérent avec l'intérieur).
wardrobe_by_interior = {}
for p in props:
    if isinstance(p, dict):
        interior = p.get("Interior")
        pos = (p.get("positions") or {}).get("Wardrobe")
        if interior and pos and interior not in wardrobe_by_interior:
            wardrobe_by_interior[interior] = pos

added = 0
for np in NEW_PROPS:
    if np["Name"] in existing_names:
        continue
    wardrobe = wardrobe_by_interior.get(np["Interior"], DEFAULT_WARDROBE)
    props.append({
        "Name": np["Name"],
        "Price": np["Price"],
        "Interior": np["Interior"],
        "Entrance": np["Entrance"],
        "positions": {"Wardrobe": wardrobe},
        "Owner": "", "OwnerName": "", "Owned": False, "Locked": False,
        "garage": {"StoredVehicles": [], "enabled": False},
        "furniture": [], "Keys": [], "plysinside": [], "setName": "",
        "cctv": {"enabled": False},
    })
    added += 1

if added > 0:
    with open(path, "w", encoding="utf-8") as f:
        json.dump(props, f, ensure_ascii=False, indent=2)
    print("  pack immobilier : %d bien(s) ajouté(s) à esx_property" % added)
else:
    print("  pack immobilier déjà présent — ignoré")
PY
}
append_properties

# --- 2c-septies. Playlists musicales (ubuntu-boite / ubuntu-loadscreen) --------
# FiveM ne sait pas lister un dossier au runtime (ni en Lua, ni en NUI). On SCANNE
# donc ici, à l'installation, chaque dossier `html/musics/` et on génère un
# `playlist.json` (tableau JSON des noms de fichiers audio, trié = ordre de lecture).
# La NUI lit ce fichier et joue les pistes dans l'ordre, en boucle. Régénéré à chaque
# `make resources` (idempotent). Déposer une piste = 1 fichier .mp3/.ogg/.wav dans le
# dossier + relancer `make resources`. N'exige PAS python3 (JSON écrit en bash).
generate_music_playlists() {
    local dirs=(
        "resources/[custom]/ubuntu-boite/html/musics"
        "resources/[custom]/ubuntu-loadscreen/html/musics"
    )
    local dir out first base
    for dir in "${dirs[@]}"; do
        mkdir -p "${dir}"
        out="${dir}/playlist.json"
        first=1
        {
            printf '['
            while IFS= read -r f; do
                base="$(basename "${f}")"
                base="${base//\\/\\\\}"   # échappe le backslash
                base="${base//\"/\\\"}"   # échappe le guillemet
                if [[ "${first}" -eq 1 ]]; then first=0; else printf ','; fi
                printf '\n  "%s"' "${base}"
            done < <(find "${dir}" -maxdepth 1 -type f \
                        \( -iname '*.mp3' -o -iname '*.ogg' -o -iname '*.wav' \) | sort)
            printf '\n]\n'
        } > "${out}"
        local n
        n="$(find "${dir}" -maxdepth 1 -type f \( -iname '*.mp3' -o -iname '*.ogg' -o -iname '*.wav' \) | wc -l | tr -d ' ')"
        log "  playlist ${dir##*/} (${dir%/html/musics}) : ${n} piste(s) → playlist.json"
    done
}
generate_music_playlists

# --- 2d. z-phone : sélection du framework ESX (défaut du dépôt = QBX) ----------
# Le téléphone lit Config.Core dans config/config.lua ; on force "ESX" (idempotent).
configure_zphone() {
    local file
    file="$(find "${RES_DIR}" -path '*/z-phone/config/config.lua' -type f 2>/dev/null | head -n1)"
    [[ -f "${file}" ]] || return 0
    if grep -qE '^[[:space:]]*Config\.Core[[:space:]]*=[[:space:]]*"ESX"' "${file}"; then
        log "  z-phone déjà en Config.Core=ESX — ignoré"
        return 0
    fi
    sed -i -E 's/^([[:space:]]*Config\.Core[[:space:]]*=[[:space:]]*)"[^"]*"/\1"ESX"/' "${file}"
    log "  z-phone configuré en Config.Core=ESX"
}
configure_zphone

# --- 3. Import du schéma SQL ESX (si la stack tourne) --------------------------
# Ensemble des codes d'erreur MariaDB « déjà présent » (ré-import idempotent bénin).
readonly SQL_BENIGN='ERROR (1050|1060|1061|1062|1022|1826|1359|1304|1537)'

# exec_sql_file <fichier> <user> <pass> <db>
# Importe un .sql en classant stderr par code d'erreur MariaDB.
# Renvoie : 0 = importé OK, 1 = tout bénin (déjà présent), 2 = vraie erreur (affichée).
exec_sql_file() {
    local f="$1" dbuser="$2" dbpass="$3" db="$4" err rc fatal
    # 2>&1 >/dev/null : ne capturer QUE stderr (stdout jeté) — l'ordre des redirections compte.
    err="$(docker compose exec -T mariadb mariadb -u"${dbuser}" -p"${dbpass}" \
              "${db}" < "${f}" 2>&1 >/dev/null)"
    rc=$?
    [[ "${rc}" -eq 0 ]] && return 0              # succès (bruit stderr éventuel ignoré)
    # Échec : ne garder que les lignes ERROR NON bénignes (le warning « Using a password… »
    # de mariadb ne commence pas par ^ERROR → naturellement ignoré).
    fatal="$(printf '%s\n' "${err}" | grep -E '^ERROR' | grep -Ev "${SQL_BENIGN}" || true)"
    [[ -z "${fatal}" ]] && return 1              # que du bénin (déjà présent)
    printf '%s\n' "${fatal}" | while IFS= read -r l; do
        log "    ${l}"
    done
    return 2                                       # vraie erreur
}

import_sql() {
    # On importe avec l'utilisateur applicatif (privilèges suffisants sur la base
    # du serveur) — plus robuste que root (le mot de passe root du volume peut différer).
    local dbuser="${MYSQL_USER:-fivem}" dbpass="${MYSQL_PASSWORD:-fivem}" db="${MYSQL_DATABASE:-fivem}"
    if ! docker compose exec -T mariadb mariadb -u"${dbuser}" -p"${dbpass}" \
            -e "SELECT 1" "${db}" >/dev/null 2>&1; then
        log "MariaDB injoignable — lancez 'make up' puis relancez 'make resources' pour importer le SQL."
        return 0
    fi

    # (a) Schéma ESX de base (data/resources/[SQL]/legacy.sql) : importé UNE fois (marqueur).
    # Ses CREATE TABLE sont sans IF NOT EXISTS => un ré-import (marqueur supprimé à la main)
    # tolère les tables déjà présentes (exec_sql_file les classe bénignes) au lieu de mourir.
    # Une VRAIE erreur (hors doublons) reste FATALE : le schéma de base conditionne tout.
    if [[ -f "${SQL_MARKER}" ]]; then
        log "Schéma ESX de base déjà importé (${SQL_MARKER}) — ignoré"
    elif [[ -d "${ESX_SQL_DIR}" ]]; then
        local s rc
        for s in "${ESX_SQL_DIR}"/*.sql; do
            [[ -f "${s}" ]] || continue
            log "Import du schéma ESX officiel ($(basename "${s}"))..."
            exec_sql_file "${s}" "${dbuser}" "${dbpass}" "${db}" && rc=0 || rc=$?
            [[ "${rc}" -eq 2 ]] && die "import du schéma ESX ($(basename "${s}")) échoué — voir l'erreur ci-dessus"
        done
        touch "${SQL_MARKER}"
    else
        log "AVERTISSEMENT : ${ESX_SQL_DIR} introuvable — schéma ESX officiel non importé (esx_core installé ?)"
    fi

    # (b) SQL livré par les ressources (jobs/grades police, addon_account, datastore,
    # z-phone, properties…) : rejoué à CHAQUE run (non-fatal, idempotent — CREATE IF NOT
    # EXISTS / INSERT déjà présent ignoré). Ajouter un addon n'exige donc PAS de supprimer
    # le marqueur. `legacy.sql` (profondeur 2) est hors de ce scan (mindepth 3).
    # `es_extended.sql` (bootstrap DB autonome d'ESX core : CREATE DATABASE + USE
    # `es_extended`) est EXCLU — on importe le schéma dans la base `fivem` via
    # esx-base.sql/legacy.sql ; l'exécuter échouerait (Access denied sur `es_extended`).
    local f rc ok=0 skip=0 err=0
    while IFS= read -r f; do
        # Appel protégé (&& / ||) : sous `set -e`, un retour ≠ 0 (1 = déjà présent,
        # 2 = vraie erreur) tuerait le script AVANT le `case`.
        exec_sql_file "${f}" "${dbuser}" "${dbpass}" "${db}" && rc=0 || rc=$?
        case "${rc}" in
            0) ok=$((ok+1)) ;;
            1) skip=$((skip+1)) ;;
            2) err=$((err+1))
               log "  ERREUR SQL : $(basename "$(dirname "${f}")")/$(basename "${f}") (voir ci-dessus)" ;;
        esac
    done < <(find "${RES_DIR}" -mindepth 3 -maxdepth 4 -name '*.sql' \
                  ! -name 'migrate*' ! -iname '*upgrade*' \
                  ! -name 'es_extended.sql' | sort)
    log "SQL ressources : ${ok} importé(s), ${skip} déjà présent(s) ignoré(s), ${err} en erreur."
    [[ "${err}" -gt 0 ]] && log "AVERTISSEMENT : ${err} fichier(s) SQL en vraie erreur — voir détail ci-dessus."
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
    local f rc found=0 ok=0 skip=0 err=0
    while IFS= read -r f; do
        found=1
        # Appel protégé (cf. import_sql) : `set -e` sinon tue au 1er SQL déjà présent.
        exec_sql_file "${f}" "${dbuser}" "${dbpass}" "${db}" && rc=0 || rc=$?
        case "${rc}" in
            0) ok=$((ok+1)) ;;
            1) skip=$((skip+1)) ;;
            2) err=$((err+1))
               log "  ERREUR SQL [custom] : $(basename "$(dirname "${f}")")/$(basename "${f}") (voir ci-dessus)" ;;
        esac
    done < <(find "resources/[custom]" -mindepth 2 -maxdepth 2 -name '*.sql' | sort)
    if [[ "${found}" -eq 1 ]]; then
        log "SQL [custom] : ${ok} importé(s), ${skip} déjà présent(s) ignoré(s), ${err} en erreur."
        [[ "${err}" -gt 0 ]] && log "AVERTISSEMENT : ${err} fichier(s) SQL [custom] en vraie erreur — voir détail ci-dessus."
    fi
    return 0
}
import_custom_sql

log "Terminé. Ressources prêtes — (re)démarrez le serveur : make restart"
