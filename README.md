# docker-observium-arm64

**Observium Community** в Docker для ARM64 (Raspberry Pi 4/5 и другие ARM-хосты).

Собирает и запускает [Observium Community](https://www.observium.org/) — систему
сетевого мониторинга и учёта устройств по SNMP — в связке с MariaDB. Стек:
Ubuntu 22.04 + Apache 2.4 + PHP 8.1 + SNMP + RRDtool.

## Что внутри

| Сервис | Роль | Образ |
|---|---|---|
| `observium` | веб-интерфейс, discovery и poller | собирается локально из `Dockerfile` |
| `db` | база данных Observium | `mariadb:10.11` |

Сервисы объединены в сеть `observium-net`; `observium` ждёт готовности БД через
`depends_on` и проверку `mysql SELECT 1` в `entrypoint.sh`.

## Требования

- хост на **ARM64** (Raspberry Pi 4/5 и т. п.);
- Docker и Docker Compose;
- свободный порт **10001** (веб-интерфейс) — при необходимости поменяй в
  `docker-compose.yml`.

## Быстрый старт

```bash
# 1. клонируй репозиторий
git clone https://github.com/ArsIS-02/docker-observium-arm64.git
cd docker-observium-arm64

# 2. настрой переменные (обязательно смени пароли!)
nano .env

# 3. собери и запусти
docker-compose up -d --build

# 4. смотри логи
docker-compose logs -f observium
```

Веб-интерфейс: **http://<IP-хоста>:10001**

## Настройка — файл `.env`

| Переменная | Назначение | По умолчанию |
|---|---|---|
| `MYSQL_ROOT_PASSWORD` | пароль root MariaDB | `MyStr0ngP@ss` |
| `MYSQL_USER` | пользователь БД Observium | `observium` |
| `MYSQL_PASSWORD` | пароль пользователя БД | `BasePassword` |
| `MYSQL_DATABASE` | имя БД | `observium` |
| `TZ` | часовой пояс | `Asia/Yekaterinburg` |
| `OBSERVIUM_ADMIN_USER` | логин администратора веб-интерфейса | `admin` |
| `OBSERVIUM_ADMIN_PASS` | пароль администратора | `observium` |
| `OBSERVIUM_BASE_URL` | внешний адрес веб-интерфейса | `http://192.168.1.148:10001` |

> ⚠️ Смени пароли и `OBSERVIUM_BASE_URL` на свои перед первым запуском.

## Структура репозитория

```
.
├── Dockerfile            ← сборка Observium (Ubuntu 22.04 + Apache + PHP 8.1)
├── docker-compose.yml    ← Observium + MariaDB
├── entrypoint.sh         ← инициализация БД, создание админа, discovery/poller
├── snmpd.conf            ← пример конфига snmpd (для устройств под наблюдением)
├── .env                  ← переменные окружения (шаблон)
└── data/ logs/ rrd/ hosts/   ← каталоги-тома, создаются при запуске
```

Тома (в `docker-compose.yml`):

| Том (хост) | Куда монтируется | Зачем |
|---|---|---|
| `./data` | `/var/lib/mysql` | данные MariaDB |
| `./logs` | `/opt/observium/logs` | логи Observium |
| `./rrd` | `/opt/observium/rrd` | RRD-базы графиков |
| `./hosts` | `/etc/hosts` | статическое сопоставление имён |

## Что делает `entrypoint.sh` при старте

1. проверяет, что заданы переменные подключения к БД;
2. ждёт готовности MariaDB (`mysql SELECT 1` в цикле);
3. подставляет параметры БД в `config.php`;
4. если таблиц нет — импортирует схему из `update/db_schema_mysql.sql`;
5. создаёт/обновляет администратора через `adduser.php`;
6. запускает первый `discovery` и `poller` в фоне;
7. настраивает часовой пояс и запускает supervisor (Apache + cron).

## Добавление устройств

Observium опрашивает устройства по SNMP, поэтому на каждом устройстве должен
работать SNMP-агент с community-строкой. В качестве отправной точки подойдёт
[`snmpd.conf`](snmpd.conf) из этого репозитория (стандартный пример ucd-snmp):
скопируй его на устройство, задай community и `rocommunity`.

Дальше в веб-интерфейсе Observium: **Devices → Add Device** → указать IP/имя и
SNMP-community. После этого Observium сам выполнит discovery и начнёт собирать
данные.

## Диагностика

```bash
# логи приложения
docker-compose logs -f observium

# зайти в контейнер с приложением
docker exec -it observiumapp bash

# проверить БД
docker exec -it observiumdb mysql -uobservium -pBasePassword observium

# пересобрать после правок
docker-compose up -d --build
```

## Известные особенности

- Сборка **только для ARM64** (базовый образ `arm64v8/ubuntu:22.04`). На x86_64
  поменяй базовый образ в `Dockerfile` на `ubuntu:22.04`.
- Observium Community скачивается с `observium.org` по HTTP (у сайта нет HTTPS
  для этого пути) — если нужен строгий контроль целостности, скачай архив вручную
  и положи в контекст сборки.
- `snmpd` в контейнере установлен, но не запускается — он нужен для устройств
  под наблюдением, а не для самого Observium.
