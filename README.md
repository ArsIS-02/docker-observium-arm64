# Observium в Docker на Raspberry Pi (ARM64) и не только

Этот репозиторий содержит готовые файлы для сборки собственного Docker-образа **Observium Community Edition** под архитектуру ARM64 (Raspberry Pi, RedOS, и другие ARM-хосты), а также для запуска всей системы мониторинга через `docker-compose`.

> **Статья-спутник**: «Мониторинг под микроскопом: Observium в самодельном Docker-образе для Raspberry Pi против зоопарка ОС и архитектур» — [ссылка на статью в журнале «Хакер»](#) (будет добавлена после публикации).

## 🧩 Что внутри?

- `Dockerfile` – сборка образа Observium на основе Ubuntu 22.04 с PHP 8.1, Apache, RRDtool, SNMP и Supervisor.
- `entrypoint.sh` – скрипт инициализации: ожидание БД, настройка `config.php`, импорт схемы, создание администратора, запуск первоначального discovery/poller, установка часового пояса.
- `observium.cron` – cron-задачи для автоматического опроса (poller каждые 5 минут, discovery каждые 6 минут).
- `docker-compose.yml` – оркестрация двух контейнеров: MariaDB и Observium.
- `.env.example` – пример переменных окружения (пароли, часовой пояс, URL).

## 🚀 Быстрый старт

### 1. Клонируйте репозиторий
```bash
git clone https://github.com/yourusername/observium-docker-arm.git
cd observium-docker-arm

2. Настройте переменные окружения
Скопируйте .env.example в .env и отредактируйте под себя:

bash
cp .env.example .env
nano .env
Обязательно измените пароли и OBSERVIUM_BASE_URL на ваш реальный IP/домен.

3. Соберите образ (если не хотите использовать готовый)
bash
docker build --platform linux/arm64 -t my-observium:latest .
4. Запустите систему
bash
docker-compose up -d
5. Проверьте логи
bash
docker-compose logs -f
6. Откройте веб-интерфейс
Перейдите по адресу http://<IP_вашего_хоста>:10001. Логин и пароль администратора задаются в .env (по умолчанию admin / observium).

🛠️ Что дальше?
Добавляйте устройства через Devices → Add Device (SNMP community по умолчанию public).

Запустите принудительный опрос для всех устройств:

bash
docker exec observiumapp /opt/observium/poller.php -h all -f
Настройте SNMP на ваших хостах (Linux, Windows, macOS, роутеры). Примеры конфигураций смотрите в статье.

📁 Структура файлов
Файл	Назначение
Dockerfile	Инструкция для сборки образа Observium
entrypoint.sh	Скрипт первичной настройки при запуске контейнера
observium.cron	Расписание для poller и discovery
docker-compose.yml	Описание сервисов (БД + Observium)
.env.example	Шаблон переменных окружения (скопируйте в .env)
🔐 Безопасность
Никогда не публикуйте реальный .env с паролями в Git! Используйте .env.example.

Перед выкладыванием в открытый доступ проверьте, что в файлах нет реальных IP-адресов, паролей или доменов:

bash
grep -r "ваш_реальный_IP" .
Рекомендуется изменить пароль администратора после первого входа.

🐛 Известные проблемы и решения
Ошибка монтирования ./hosts: создайте пустой файл hosts в папке проекта:

bash
touch hosts
Ошибка прав на RRD-файлы: внутри контейнера Apache и poller работают от пользователя www-data (UID 33). Выставьте права на хосте:

bash
sudo chown -R 33:33 ./rrd
Apache не запускается: проверьте, что в entrypoint.sh используется apache2ctl -DFOREGROUND (в нашем Dockerfile уже исправлено).

📦 Готовый образ
Если вы не хотите собирать образ самостоятельно, вы можете скачать готовый архив:

bash
docker load -i my-observium.tar
(файл my-observium.tar необходимо получить из релизов репозитория или собрать самостоятельно по инструкции).

🤝 Вклад в проект
Pull Request'ы приветствуются. Если вы нашли ошибку или хотите улучшить документацию – создавайте Issue.

📄 Лицензия
MIT (или укажите свою). Observium имеет собственную лицензию (QPL для Community Edition).

🙏 Благодарности
Команде Observium за отличный продукт.

Всем читателям журнала «Хакер» за вдохновение.

Удачного мониторинга! 📊
