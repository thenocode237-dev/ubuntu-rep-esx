#!/usr/bin/env bash
#
# Restauration d'une sauvegarde produite par backup.sh (SPECS §10).
# Usage : scripts/restore.sh [chemin/vers/fivem-backup-XXXX.tar.gz]
# Sans argument, la sauvegarde la plus récente est proposée.
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
ARCHIVE="${1:-}"

if [[ -z "${ARCHIVE}" ]]; then
    ARCHIVE="$(ls -1t "${BACKUP_DIR}"/fivem-backup-*.tar.gz 2>/dev/null | head -n1 || true)"
fi
[[ -n "${ARCHIVE}" && -f "${ARCHIVE}" ]] || { echo "Aucune archive trouvée. Usage: $0 <archive.tar.gz>"; exit 1; }

echo "[restore] Archive : ${ARCHIVE}"
read -r -p "Ceci va ÉCRASER la base et les fichiers actuels. Continuer ? [y/N] " ans
[[ "${ans,,}" == "y" ]] || { echo "Annulé."; exit 0; }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

echo "[restore] Extraction..."
tar xzf "${ARCHIVE}" -C "${WORK}"

echo "[restore] Restauration des fichiers (config, .env, ressources, txData)..."
[[ -f "${WORK}/.env" ]]  && cp "${WORK}/.env" ./.env
[[ -d "${WORK}/config" ]] && cp -r "${WORK}/config/." ./config/
[[ -d "${WORK}/data/resources" ]] && { mkdir -p data/resources && cp -r "${WORK}/data/resources/." data/resources/; }
[[ -d "${WORK}/data/txData" ]]    && { mkdir -p data/txData    && cp -r "${WORK}/data/txData/." data/txData/; }

if [[ -f "${WORK}/database.sql" ]]; then
    echo "[restore] Restauration de la base MariaDB..."
    docker compose up -d mariadb
    # Attente que la base réponde.
    for _ in $(seq 1 30); do
        docker compose exec -T mariadb mariadb-admin ping -u root -p"${MYSQL_ROOT_PASSWORD}" --silent && break
        sleep 2
    done
    docker compose exec -T mariadb \
        mariadb -u root -p"${MYSQL_ROOT_PASSWORD}" < "${WORK}/database.sql"
fi

echo "[restore] Terminé. Relancez la stack : make up"
