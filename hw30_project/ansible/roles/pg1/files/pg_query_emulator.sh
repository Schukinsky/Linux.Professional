#!/bin/bash

# Настройка логгирования в JSON-формате
LOG_DIR="/var/log/pg_query_emulator"
LOG_FILE="$LOG_DIR/pg_query_emulator.log"
mkdir -p "$LOG_DIR"
chown postgres:postgres "$LOG_DIR"
chmod 755 "$LOG_DIR"

# Функция для записи в лог в JSON-формате (без использования jq)
log() {
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local level="info"
  local message="$1"
  # Экранируем кавычки и спецсимволы для JSON вручную
  message=${message//\\/\\\\}  # Экранируем обратные слеши
  message=${message//\"/\\\"}  # Экранируем кавычки
  message=${message//$'\n'/\\n}  # Экранируем переносы строк
  echo "{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"message\":\"$message\"}" >> "$LOG_FILE"
}

# Конфигурация подключения к БД
DB_HOST="localhost"
DB_PORT="5432"
DB_NAME="gate"
DB_USER="admin_user"
DB_PASS="admin_user"
export PGPASSWORD="$DB_PASS"

# Список SQL-запросов для выполнения
SQL_QUERIES=(
  "CALL gate01.add_event_camera_in('А111АА111');"
  "CALL gate01.add_event_camera_in('А222АА111');"
  "CALL gate01.add_event_camera_in('А333АА111');"
  "CALL gate01.add_event_camera_in('А111АА112');"
  "CALL gate01.add_event_camera_in('А222АА113');"
  "CALL gate01.add_event_call('79263333333', 2, 'Т111ТТ111');"
  "CALL gate01.add_event_call('79261111111', 1, 'О111ОО111');"
  "CALL gate01.add_event_call('79262222221', 1, 'Е111ЕЕ111');"
  "CALL gate01.add_event_call('79263333331', 1, 'Т111ТТ111');"
  "CALL gate01.add_event_camera_out('А111АА111');"
  "CALL gate01.add_event_camera_out('А222АА111');"
  "CALL gate01.add_event_camera_out('А333АА111');"
  "CALL gate01.add_event_camera_in('X888XX999');"
  "CALL gate01.add_event_call('79260000000', 1, 'X888XX999');"
  "CALL gate01.add_event_call('79261111111', 2, 'О111ОО111');"
  "CALL gate01.add_event_call('79262222221', 2, 'Е111ЕЕ111');"
  "CALL gate01.add_event_call('79263333331', 2, 'Т111ТТ111');"
  "CALL gate01.add_event_camera_out('Е001КХ77');"  
)

# Интервал между выполнениями (в секундах)
QUERY_INTERVAL=25

# Функция для выполнения одного запроса с JSON-логгированием
execute_query() {
  local query="$1"
  log "Executing query: ${query:0:50}..."  # Обрезаем длинные запросы для лога
  
  # Выполняем запрос и логируем вывод построчно
  local error_occurred=0
  while IFS= read -r line; do
    # Пропускаем пустые строки
    [ -z "$line" ] && continue
    
    # Логируем все строки
    log "$line"
    
    # Проверяем на наличие сообщений об ошибках (раздельно для совместимости)
    if [[ "$line" =~ ERROR: ]] || [[ "$line" =~ FATAL: ]] || [[ "$line" =~ "could not connect" ]]; then
      error_occurred=1
    fi
  done < <(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "$query" 2>&1)

  return $error_occurred
}

# Основной цикл выполнения
log "Starting PostgreSQL Query Emulator"
while true; do
  for query in "${SQL_QUERIES[@]}"; do
    if ! execute_query "$query"; then
      log "Error executing query. Waiting 5 seconds before retry..."
      sleep 5
      continue 2  # Переходим к новой попытке подключения
    fi
    sleep "$QUERY_INTERVAL"
  done
done