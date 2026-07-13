#!/usr/bin/env bash
#
# Sauvegarde de la plateforme FiveM (SPECS §10) :
#   - dump de la base MariaDB
#   - archive des ressources, txData, config et .env
#   - compression gzip + rotation (garde les N plus récentes)
#
set -euo pipefail

cd "$(dirname "$0")/.."   # racine du projet

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

BACKUP_DIR="data/backups"
RETENTION="${BACKUP_RETENTION:-7}"          # nombre de sauvegardes conservées
STAMP="$(date +%Y%m%d-%H%M%S)"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

mkdir -p "${BACKUP_DIR}"

echo "[backup] Dump MariaDB (${MYSQL_DATABASE})..."
docker compose exec -T mariadb \
    mariadb-dump -u root -p"${MYSQL_ROOT_PASSWORD}" --databases "${MYSQL_DATABASE}" \
    > "${WORK}/database.sql"

echo "[backup] Archivage des fichiers..."
# --ignore-failed-read : ne pas échouer si un dossier optionnel est absent.
tar czf "${BACKUP_DIR}/fivem-backup-${STAMP}.tar.gz" \
    --ignore-failed-read \
    -C "${WORK}" database.sql \
    -C "${PWD}" .env config \
    $( [[ -d data/resources ]] && echo "data/resources" ) \
    $( [[ -d data/txData ]] && echo "data/txData" )

echo "[backup] Rotation (conserve ${RETENTION})..."
ls -1t "${BACKUP_DIR}"/fivem-backup-*.tar.gz 2>/dev/null \
    | tail -n +"$((RETENTION + 1))" \
    | xargs -r rm -f

echo "[backup] Terminé : ${BACKUP_DIR}/fivem-backup-${STAMP}.tar.gz"
