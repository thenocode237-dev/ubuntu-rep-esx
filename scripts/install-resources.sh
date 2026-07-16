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
