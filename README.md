# Claude Workstation

Удалённая Ubuntu 24.04 x86_64: XFCE/X11 headless, официальный Claude Desktop и Code CLI, Chromium, Playwright MCP, Tailscale и RustDesk. LITE для текущего VPS; FULL подготавливает KVM/Cowork на подходящем сервере.

## Установка с GitHub

На новом Ubuntu 24.04 x86_64 скачайте bootstrap из релиза и запустите через sudo. Команда приведена ниже; она автоматически скачает весь репозиторий и установит окружение. Выполняйте её на новом сервере, а не на Mac.

```bash
CW_BOOTSTRAP=$(mktemp) && curl --proto '=https' --tlsv1.2 -fsSL https://raw.githubusercontent.com/SomAThi/claude-workstation/v1.0.1/bootstrap.sh -o "$CW_BOOTSTRAP" && sudo bash "$CW_BOOTSTRAP" --ref v1.0.1
```

Требуется curl (на стандартном Ubuntu VPS обычно установлен); при его отсутствии: `sudo apt-get update && sudo apt-get install -y curl`.

Bootstrap устанавливает git/ca-certificates/python3, скачивает исходники в новый каталог /opt/claude-workstation-sources/source.*, выводит фактический commit и запускает install.sh. Рабочие данные и учётные записи не входят в репозиторий. Для закрепления точной версии можно передать `--ref` с полным commit SHA вместо тега.

```bash
sudo bash /path/to/bootstrap.sh --mode LITE
sudo bash /path/to/bootstrap.sh --mode FULL
```

Для ручного клонирования:

```bash
sudo apt-get update && sudo apt-get install -y git
git clone --depth 1 --branch v1.0.1 https://github.com/SomAThi/claude-workstation.git
cd claude-workstation
sudo ./install.sh
```

## После установки

1. Выполните `sudo tailscale up --accept-routes=false --accept-dns=false` и откройте выданную ссылку в своём браузере.
2. Выполните `sudo bash /opt/claude-workstation-current/scripts/enable-rustdesk.sh`.
3. Получите адрес: `tailscale ip -4`. В RustDesk на Mac подключитесь к этому адресу с `:21118`. Mac должен быть в том же tailnet.
4. Пароль RustDesk получите в собственном root-терминале из `/var/lib/claude-workstation/rustdesk-password`; пароль Linux workstation — из `/var/lib/claude-workstation/initial-login-password`. Не публикуйте их.
5. Войдите в Claude через GUI. Настройка разрешённой папки Mac выполняется отдельно по инструкции.

## Команды из каталога исходников

```bash
sudo ./install.sh                   # AUTO
sudo ./install.sh --mode LITE
sudo ./scripts/verify.sh
sudo ./scripts/diagnose.sh
sudo ./scripts/update.sh            # сначала просмотр, затем явное UPDATE
```

[Установка](docs/INSTALL.md) · [Mac и SMB](docs/MAC_SETUP.md) · [Миграция](docs/MIGRATION.md) · [Cowork](docs/COWORK.md) · [Диагностика](docs/TROUBLESHOOTING.md)

Установщик не включает autologin и не выполняет авторизацию вместо владельца. После установки авторизуйте Tailscale, активируйте защищённый RustDesk, войдите workstation и авторизуйтесь в Claude через GUI. CLI: открыть Projects в терминале, запустить `claude`, пройти обычный официальный вход по подписке. Не используйте API-ключ, если хотите вход через подписку. Не копируйте OAuth или cookies.

Claude Code CLI имеет пользовательский MCP playwright-workstation. Для графической вкладки Code проверьте список MCP после авторизации; если она не использует CLI-конфигурацию, используйте отдельный ярлык Claude Code Terminal и не считайте интеграцию Desktop подтверждённой. MCP запускает отдельный headless браузер, не управляет открытыми вкладками ручного Chromium. Нет blanket approvals.

В `config/` закреплены Node, RustDesk и npm-зависимости. Версии системных пакетов сохраняются на сервере. Это не архив исторических APT/snap-репозиториев. Проверено на одном Ubuntu 24.04 VPS: графический запуск, MCP, backup/restore и повторная установка. Отдельная чистая установка и FULL/Cowork ещё не проверены.

Тесты: `python3 -m unittest discover -s tests`; syntax/ShellCheck: `tests/static-check.sh`; реальный MCP smoke под workstation после установки: `python3 tests/mcp-smoke.py`. Безопасная локальная тестовая страница; никаких внешних публикаций.

Backup/restore запускаются под workstation, restore только после ввода RESTORE и только в новый staging-каталог. Никогда не включайте /var/lib/claude-workstation, профили браузеров или целый /home в переносимый установочный архив.
