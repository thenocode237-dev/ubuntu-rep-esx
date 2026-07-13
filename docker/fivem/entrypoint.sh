#!/usr/bin/env bash
#
# FiveM container entrypoint.
#   1. Resolve the artifact build to run (pinned or from the changelog API).
#   2. Download + verify + extract it into a persistent cache (skipped if unchanged).
#   3. Generate server.cfg from the template via envsubst.
#   4. Start txAdmin (default) or a headless server, driven entirely by .env.
#
set -euo pipefail

log() { echo "[entrypoint] $*"; }
die() { echo "[entrypoint] ERROR: $*" >&2; exit 1; }

# --- Paths ------------------------------------------------------------------
FIVEM_HOME="/opt/fivem"
ARTIFACT_DIR="${FIVEM_HOME}/artifacts"          # persistent (bind: data/artifacts)
SERVER_DIR="${ARTIFACT_DIR}/server"             # extracted FXServer lives here
VERSION_MARKER="${ARTIFACT_DIR}/.artifact_version"
CONFIG_TEMPLATE="${FIVEM_HOME}/config/server.cfg.template"
CONFIG_OUT="${FIVEM_HOME}/config/server.cfg"
TXDATA_DIR="${FIVEM_HOME}/txData"

# --- Tunables (env, all optional) -------------------------------------------
FIVEM_BUILD_CHANNEL="${FIVEM_BUILD_CHANNEL:-recommended}"   # recommended | latest
FIVEM_BUILD="${FIVEM_BUILD:-}"                              # pin: full fx.tar.xz URL (overrides channel)
FIVEM_FORCE_UPDATE="${FIVEM_FORCE_UPDATE:-0}"
TXADMIN_ENABLE="${TXADMIN_ENABLE:-true}"
CHANGELOG_URL="https://changelogs-live.fivem.net/api/changelog/versions/linux/server"

mkdir -p "${ARTIFACT_DIR}" "${SERVER_DIR}" "${TXDATA_DIR}"

# --- 1. Resolve the artifact URL --------------------------------------------
resolve_artifact_url() {
    if [[ -n "${FIVEM_BUILD}" ]]; then
        echo "${FIVEM_BUILD}"
        return
    fi
    log "Resolving '${FIVEM_BUILD_CHANNEL}' build from changelog API..." >&2
    local json field
    json="$(curl -fsSL --retry 3 --retry-delay 2 "${CHANGELOG_URL}")" \
        || die "Could not reach the FiveM changelog API (${CHANGELOG_URL})"
    field="${FIVEM_BUILD_CHANNEL}_download"
    # Extract "<field>":"<url>" without depending on jq.
    local url
    url="$(echo "${json}" | grep -o "\"${field}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
        | head -n1 | sed -E 's/.*:[[:space:]]*"([^"]*)".*/\1/')"
    [[ -n "${url}" ]] || die "Field '${field}' not found in changelog response"
    echo "${url}"
}

# --- 2. Download + verify + extract (idempotent via marker) -----------------
ensure_artifact() {
    local url current
    url="$(resolve_artifact_url)"
    log "Target artifact: ${url}"

    current="$(cat "${VERSION_MARKER}" 2>/dev/null || true)"
    if [[ "${current}" == "${url}" && "${FIVEM_FORCE_UPDATE}" != "1" && -x "${SERVER_DIR}/run.sh" ]]; then
        log "Artifact already installed and up to date — skipping download."
        return
    fi

    local tmp archive
    tmp="$(mktemp -d)"
    archive="${tmp}/fx.tar.xz"
    log "Downloading artifact..."
    curl -fSL --retry 3 --retry-delay 2 -o "${archive}" "${url}" \
        || die "Artifact download failed"

    log "Verifying archive integrity..."
    xz -t "${archive}" || die "Archive failed xz integrity check"

    log "Extracting..."
    local extract="${tmp}/extract"
    mkdir -p "${extract}"
    tar -xJf "${archive}" -C "${extract}" || die "Extraction failed"
    [[ -f "${extract}/run.sh" ]] || die "run.sh missing from artifact — aborting, keeping previous build"

    # Swap in atomically-ish: clear old server dir, move new content in.
    rm -rf "${SERVER_DIR:?}/"* 2>/dev/null || true
    mv "${extract}"/* "${SERVER_DIR}/"
    chmod +x "${SERVER_DIR}/run.sh" 2>/dev/null || true
    echo "${url}" > "${VERSION_MARKER}"
    rm -rf "${tmp}"
    log "Artifact installed."
}

# --- 3. Generate server.cfg -------------------------------------------------
generate_config() {
    [[ -f "${CONFIG_TEMPLATE}" ]] || die "Template not found: ${CONFIG_TEMPLATE}"
    log "Generating server.cfg from template..."
    local tmp="${CONFIG_OUT}.tmp"
    envsubst < "${CONFIG_TEMPLATE}" > "${tmp}"
    # Drop optional directives left empty in .env (a bare value would be invalid).
    sed -i -E \
        -e '/^sv_enforceGameBuild[[:space:]]*$/d' \
        -e '/^set steam_webApiKey ""[[:space:]]*$/d' \
        -e '/^rcon_password ""[[:space:]]*$/d' \
        -e '/^sets tags ""[[:space:]]*$/d' \
        -e '/^set discord_webhook ""[[:space:]]*$/d' \
        "${tmp}"
    mv "${tmp}" "${CONFIG_OUT}"
}

# --- 4. Start ---------------------------------------------------------------
start_server() {
    if [[ "${TXADMIN_ENABLE,,}" == "true" ]]; then
        cd "${SERVER_DIR}"
        log "Starting FXServer with txAdmin (web UI on :${TXADMIN_PORT:-40120})..."
        export TXHOST_DATA_PATH="${TXDATA_DIR}"
        export TXHOST_TXA_PORT="40120"
        export TXHOST_GAME_PORT="30120"
        exec ./run.sh
    else
        # Le cwd est le "server data dir" : FXServer y cherche resources/ et
        # cache/ — il doit donc être FIVEM_HOME (où resources/ est monté),
        # pas le dossier des artifacts.
        cd "${FIVEM_HOME}"
        log "Starting FXServer headless with server.cfg..."
        exec "${SERVER_DIR}/run.sh" +exec "${CONFIG_OUT}"
    fi
}

ensure_artifact
generate_config
start_server
