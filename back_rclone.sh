#!/bin/bash

#install rclone
#curl https://rclone.org/install.sh | sudo bash
#
#crontab
#PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/mysql/bin
#HOME=/root
#SHELL=/bin/bash
#RCLONE_CONFIG=/etc/_script/rclone.conf
#MAILTO=root
#1 3 * * * /etc/_script/back_rclone_.sh mailru  >> /var/log/backup_mailru.log 2>&1
#1 2 * * * /etc/_script/back_rclone_.sh mega1  >> /var/log/backup_mega1.log 2>&1

export RCLONE_CONFIG=/etc/_script/rclone.conf
readonly RCLONE_REMOTE=$1
readonly BACKUP_NAME="dtrfo-vpn"
readonly CLOUD_DIR="_DTRAFO_VPN_"
readonly LOCAL_WORKDIR="/tmp/${BACKUP_NAME}"
readonly LOCAL_BACKUP_DIR="/tmp/${CLOUD_DIR}"
readonly BACKUP_COUNT=30
readonly DATE_FORMAT="%Y_%m_%d-%H%M"
readonly LOG_FILE="/var/log/backup_${RCLONE_REMOTE}.log"

#для выгрузки MySQL
#readonly MYSQL_USER="root"
#readonly MYSQL_PASS="---"

readonly TIMESTAMP=$(date +"${DATE_FORMAT}")
readonly BACKUP_FILE="${TIMESTAMP}-${BACKUP_NAME}"
readonly BACKUP_PATH="${LOCAL_BACKUP_DIR}/${BACKUP_FILE}.tar.gz"

# Cron compatibility - полные пути для всех систем
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/mysql/bin"
export HOME="/root"
export SHELL="/bin/bash"

log() {
  echo "[$(date +"%F %T")] $1" | tee -a "${LOG_FILE}"
}

error_exit() {
  log "ОШИБКА: $1" >&2
  start_services
  exit 1
}

check_dependencies() {
  local dependencies=("mysqldump" "rclone" "tar")
  
  for cmd in "${dependencies[@]}"; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
      error_exit "Не найдена команда: ${cmd}"
    fi
  done
  log "✅ Все зависимости найдены"
}

stop_services() {
  log "Остановка сервисов ..."
  sleep 2  # Даем время на остановку
}

start_services() {
  log "Запуск сервисов ..."
#  systemctl start aspia-router 2>/dev/null || log "Предупреждение: не удалось запустить aspia-router"
#  systemctl start aspia-relay 2>/dev/null || log "Предупреждение: не удалось запустить aspia-relay"
  sleep 2  # Даем время на запуск
}

backup_databases() {
  log "Создание дампов баз данных..."
  local databases=("postfix" "roundcubemail")

  for db in "${databases[@]}"; do
    local dump_file="${LOCAL_WORKDIR}/${db}-sql-${TIMESTAMP}.sql"
    if ! mysqldump -u "${MYSQL_USER}" --password="${MYSQL_PASS}" "${db}" > "${dump_file}"; then
      error_exit "Ошибка при создании дампа базы ${db}"
    fi
    log "Дамп базы ${db} создан: ${dump_file}"
  done
}

backup_system_files() {
  log "Копирование системных файлов..."
  if ! cp -r /etc "${LOCAL_WORKDIR}/etc"; then
    error_exit "Ошибка копирования /etc"
  fi

  local cron_file="${LOCAL_WORKDIR}/crontab.txt"

  if ! crontab -l > "${cron_file}"; then
    error_exit "Ошибка сохранения crontab"
  fi
  log "Системные файлы скопированы"
}

create_archive() {
  log "Создание архива ${BACKUP_PATH}..."
  mkdir -p "${LOCAL_BACKUP_DIR}" || error_exit "Не удалось создать директорию для бэкапов"
  if ! tar czf "${BACKUP_PATH}" -C "${LOCAL_WORKDIR}" .; then
    error_exit "Ошибка при создании архива"
  fi
  log "✅ Архив успешно создан: ${BACKUP_PATH} ($(du -h "${BACKUP_PATH}" | cut -f1))"
}

manage_cloud_backups() {
  log "Работа с облаком через rclone (${RCLONE_REMOTE})..."
  
  # Проверка количества бэкапов в облаке
  log "Проверка количества бэкапов в облаке..."
  local backup_list=$(rclone ls "${RCLONE_REMOTE}:${CLOUD_DIR}/" 2>/dev/null | grep -E "${BACKUP_NAME}.tar.gz" | awk '{print $2}' | sort -r)
  local backup_count=$(echo "${backup_list}" | wc -l)

  log "Найдено бэкапов в облаке: ${backup_count}/${BACKUP_COUNT}"

  while [ "${backup_count}" -gt "${BACKUP_COUNT}" ]; do
    local oldest_backup=$(echo "${backup_list}" | tail -n1)
    log "Удаление старого бэкапа: ${oldest_backup}"
    rclone deletefile "${RCLONE_REMOTE}:${CLOUD_DIR}/${oldest_backup}" || log "Предупреждение: не удалось удалить ${oldest_backup}"
    backup_count=$((backup_count - 1))
  done

  log "Загрузка бэкапа в облако..."
  if ! rclone copy "${BACKUP_PATH}" "${RCLONE_REMOTE}:${CLOUD_DIR}/" -v --progress; then
    error_exit "Ошибка загрузки бэкапа в облако"
  fi
  log "✅ Бэкап успешно загружен в облако: /${CLOUD_DIR}/${BACKUP_FILE}.tar.gz"
}

cleanup() {
  log "Очистка временных файлов..."
  rm -rf "${LOCAL_WORKDIR}" || log "Предупреждение: не удалось удалить ${LOCAL_WORKDIR}"
  rm -f "${BACKUP_PATH}" || log "Предупреждение: не удалось удалить ${BACKUP_PATH}"
}

# Trap для корректной очистки
trap 'start_services; cleanup; log "Скрипт прерван"' INT TERM
trap cleanup EXIT
set -euo pipefail

log "🚀 === Начало выполнения бэкапа (${TIMESTAMP}) ==="

#check_dependencies
#stop_services

mkdir -p "${LOCAL_WORKDIR}" || error_exit "Не удалось создать рабочую директорию"

#backup_databases
backup_system_files
create_archive
manage_cloud_backups

#start_services
log "✅ === Бэкап  успешно завершен ==="
