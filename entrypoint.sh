#!/bin/bash
set -e

wait_for_db() {
    echo "Ожидание подключения к базе данных ${OBSERVIUM_DB_HOST}..."
    until mysql -h "${OBSERVIUM_DB_HOST}" -u "${OBSERVIUM_DB_USER}" -p"${OBSERVIUM_DB_PASS}" -e "SELECT 1" &>/dev/null; do
        sleep 2
    done
    echo "База данных готова!"
}

if [ -z "${OBSERVIUM_DB_HOST}" ] || [ -z "${OBSERVIUM_DB_USER}" ] || [ -z "${OBSERVIUM_DB_PASS}" ]; then
    echo "Ошибка: не заданы переменные окружения для подключения к базе данных"
    exit 1
fi

echo "Настройка подключения к базе данных..."
wait_for_db

update_config() {
    local key=$1
    local value=$2
    sed -i "s/^\$config\['${key}'\][[:space:]]*=[[:space:]]*'[^']*';/\$config['${key}'] = '${value}';/" /opt/observium/config.php
}

if [ ! -f /opt/observium/config.php ]; then
    cp /opt/observium/config.php.default /opt/observium/config.php
fi

update_config "db_host" "${OBSERVIUM_DB_HOST}"
update_config "db_user" "${OBSERVIUM_DB_USER}"
update_config "db_pass" "${OBSERVIUM_DB_PASS}"
update_config "db_name" "${OBSERVIUM_DB_NAME}"

TABLE_COUNT=$(mysql -h "${OBSERVIUM_DB_HOST}" -u "${OBSERVIUM_DB_USER}" -p"${OBSERVIUM_DB_PASS}" -D "${OBSERVIUM_DB_NAME}" -e "SHOW TABLES;" | wc -l)
if [ "$TABLE_COUNT" -lt 2 ]; then
    echo "Инициализация базы данных Observium..."
    SQL_FILE="/opt/observium/update/db_schema_mysql.sql"
    if [ -f "$SQL_FILE" ]; then
        mysql -h "${OBSERVIUM_DB_HOST}" -u "${OBSERVIUM_DB_USER}" -p"${OBSERVIUM_DB_PASS}" "${OBSERVIUM_DB_NAME}" < "$SQL_FILE"
        echo "Схема базы данных успешно импортирована."
    else
        echo "Ошибка: файл схемы $SQL_FILE не найден!"
        exit 1
    fi
else
    echo "База данных уже инициализирована, пропускаем импорт схемы."
fi

if [ -n "${OBSERVIUM_ADMIN_USER}" ] && [ -n "${OBSERVIUM_ADMIN_PASS}" ]; then
    echo "Добавление/обновление администратора ${OBSERVIUM_ADMIN_USER}..."
    php /opt/observium/adduser.php "${OBSERVIUM_ADMIN_USER}" "${OBSERVIUM_ADMIN_PASS}" 10
fi

echo "Запуск первоначального discovery..."
php /opt/observium/discovery.php -u &
echo "Запуск первоначального poller..."
php /opt/observium/poller.php -h all &

if [ -n "$TZ" ] && [ -f /usr/share/zoneinfo/$TZ ]; then
    echo "Настройка часового пояса: $TZ"
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
    echo $TZ > /etc/timezone
    sed -i "s|^;date.timezone =.*|date.timezone = $TZ|" /etc/php/8.1/apache2/php.ini
    sed -i "s|^;date.timezone =.*|date.timezone = $TZ|" /etc/php/8.1/cli/php.ini
fi

exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
