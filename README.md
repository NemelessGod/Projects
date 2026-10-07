# Spin Kingdom

Основа оригинальной онлайн casual-игры для вертикального Android: восстановите парящие острова, получайте монеты и искры из трёхбарабанного механизма, улучшайте постройки. Рабочее название легко заменяется.

**Статус: первый вертикальный срез, локальная разработка. NOT PRODUCTION READY.** Поздние игровые системы не выдаются за реализованные. Актуальная проверка: [PROJECT_STATE.md](PROJECT_STATE.md).

## Стек и структура

Godot **4.6.3** (GDScript, GL Compatibility), Python **3.12**, FastAPI, PostgreSQL **17**, SQLAlchemy/psycopg. Сравнение Flutter/Flame и Godot: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

```
backend/app/          HTTP, транзакции, экономика, конфигурация, миграции
backend/config/       исходный баланс economy.v1.json
backend/migrations/   PostgreSQL schema
backend/tests/        unit + integration на настоящем PostgreSQL
client/scripts/       UI, сцены, слот, сеть, сессия, локальный кэш
client/tests/         реальный Godot → HTTP → PostgreSQL smoke/restart
client/scenes/        корневая сцена
scripts/              воспроизводимая установка, запуск, тесты, APK
.local/               БД и backups; ignored, не коммитить
build/                debug APK; ignored
 docs/                архитектура, экономика, API, события, roadmap
```

## Быстрый запуск в этой среде

Нужны Python 3.12, Docker daemon, Godot 4.6.3 и Java 21. Они доступны здесь. Используйте существующий checkout `/workspace/Projects`; облачная задача уже изолирована, worktree не нужен.

```bash
cd /workspace/Projects
scripts/setup.sh
scripts/start.sh
```

`start.sh` работает в foreground: оставьте его запущенным. Он запускает PostgreSQL на `127.0.0.1:55432`, использует `.local/postgres`, применяет миграции и запускает API на `127.0.0.1:8000`. В другом терминале:

```bash
curl --fail http://127.0.0.1:8000/health
source scripts/env.sh
godot --path client
```

Первый старт автоматически создаёт гостя. Слот расходует искру, сервер выдаёт результат, Остров позволяет улучшить объект. После перезапуска восстанавливается тот же игрок. Адреса localhost используются для внутренних проверок и не являются облачным веб-превью.

## Настройки и база данных

[.env.example](.env.example) содержит только безопасные локальные значения. Backend читает `DATABASE_URL`. Передача переменной:

```bash
export DATABASE_URL='postgresql+psycopg://postgres@127.0.0.1:55432/spin_kingdom'
cd backend
../.venv/bin/python -m app.migrate
```

`.env` не загружается автоматически — задавайте переменные процессу или через настройки среды. Пароли не хранить в Git. Локальная БД использует trust authentication **только на loopback**; для deployment нужны секретные credentials и роль с минимальными привилегиями. Миграции транзакционные и повторяемые. Не запускайте тесты на игровой БД.

Данные сохраняются в `.local/postgres`; процессы и Docker daemon нельзя считать сохраняемыми между облачными задачами. `start.sh` пересоздаёт контейнер с сохранённым каталогом при необходимости. Backups можно делать так:

```bash
mkdir -p .local/backups
docker exec spin-kingdom-db pg_dump -Fc -p 55432 -U postgres spin_kingdom > .local/backups/game.dump
# Восстановление выполнять только в отдельную пустую БД, затем проверять данные.
```

## Тесты

Сначала запустите `scripts/start.sh`, затем:

```bash
scripts/test.sh             # formatter/linter + 28 backend tests
scripts/client_smoke.sh     # новый тестовый гость, слот, upgrade, lost-response replay, restart
```

Backend-тесты используют только `spin_kingdom_test`. Для другого сервера задайте `TEST_DATABASE_URL` с именем БД, оканчивающимся `_test`. API принимает UUID idempotency keys, запрещает лишние поля, не доверяет цене/награде/времени клиента. Тесты действительно используют PostgreSQL и конкурентные запросы.

`client_smoke.sh` сохраняет отдельный клиентский каталог для диагностики, не удаляет игровую сессию разработчика. Число искр может увеличиться между запусками из-за серверной регенерации.

## Android debug APK

```bash
scripts/install_android.sh    # Android SDK 36 + проверенные templates 4.6.3
scripts/build_android.sh      # build/spin-kingdom-debug.apk
source scripts/env.sh
adb install -r build/spin-kingdom-debug.apk
adb reverse tcp:8000 tcp:8000
adb shell am start -n com.starharbor.spinkingdom/org.godotengine.godot.GodotApp
```

SDK устанавливается в `/workspace/tooling/android-sdk`, templates/settings/cache — в writable XDG-каталогах. Путь можно заменить `SPIN_TOOLING_DIR`; путь Java определяется через `java.home` или `SPIN_JAVA_ROOT`. Проверка архивов: официальный SHA-1 Android tools и SHA-512 Godot release. Не отключать TLS/checksum verification. Интернет нужен к PyPI, dl.google.com, GitHub release assets и Docker registry (стандартные package-manager domains).

Debug APK включает arm64-v8a (телефоны) и x86_64 (эмулятор); минимальная версия Android — 7.0/API 24, target — 36. Без ускорения первая загрузка эмулятора может занять много минут. При ограниченной песочнице Android-эмулятор/adb могут требовать writable `.android` и console auth file в домашней папке; служебный грамматический кэш gdtoolkit скрипт перенаправляет в writable XDG. Не менять HOME и не класть токены в setup scripts.

Телефон через USB с `adb reverse` использует `http://127.0.0.1:8000`. Без USB задайте доступный backend в debug-профиле. Смена адреса создаёт нового гостя и удаляет локальный ключ старого сервера; не переключайтесь, если нужен прежний аккаунт. Desktop поддерживает `SPIN_API_URL`. Release требует HTTPS в `game/api_url`; production signing, Google-вход и публикация пока не настроены. Debug keystore не подходит для Google Play.

## Баланс и live configuration

Seed: `backend/config/economy.v1.json`. Runtime: активная запись `game_config`. Публичный API её не изменяет. Для новой версии сделайте копию конфигурации вне tracked seed, увеличьте `revision`, затем доверенный CLI:

```bash
cd backend
../.venv/bin/python -m app.publish_config /absolute/path/economy.v2.json
```

CLI проверяет диапазоны, уникальность IDs и совместимость сохранённого прогресса. Запрещено удалить/переименовать существующий мир, здание или изменить число его уровней. Можно менять цены, вероятности, регенерацию и награды; добавлять миры. Клиент получает конфиг при подключении, сервер использует активный revision при каждой новой команде. Уже выполненные команды сохраняют исходный результат. `initial` влияет только на новых гостей.

## Ограничения и продолжение

Google-вход, attacks/raids/shields, cards/chests, wheel/dailies, events/tournaments, friends/inbox, shop/ads/audio/analytics — следующие этапы, сейчас не реализованы. Валюта crystals зарезервирована без покупок. Графика оригинальная векторная временная, не финальные ассеты.

Перед релизом нужны account linking/recovery и безопасное хранение ключа, renewal/revocation, HTTPS hosting, rate limiting/guest anti-abuse, production DB roles/backups, privacy/analytics consent, нагрузочное тестирование, accessibility, производительность на физическом телефоне и release signing. Архитектура и правила следующих этапов: [docs/ROADMAP.md](docs/ROADMAP.md), [docs/EVENT_SYSTEM.md](docs/EVENT_SYSTEM.md).
