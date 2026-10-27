# Диагностика

- `sudo ./scripts/verify.sh`: отличает AUTO_PASS, WAIT_USER, NOT_SUPPORTED, NOT_TESTED и ERROR. Наличие пакета не равно полноценной работе GUI.
- `sudo ./scripts/diagnose.sh`: ОС, память, swap, службы, порты, OOM-события и версии. Перед передачей кому-либо просмотрите вывод: там могут быть IP/пути пользователя.
- `journalctl -u cw-resources.service`: счётчики памяти/OOM каждые 5 минут; `systemctl list-timers cw-resources.timer`.
- `tail /home/workstation/.xsession-errors`: ошибки графики. Не публикуйте журнал целиком без просмотра: приложения могут писать приватные данные.
- Чёрный экран: проверить `systemctl status lightdm`, `/var/log/Xorg.0.log`, `xrandr` с DISPLAY/XAUTHORITY текущей сессии. Экран приветствия отличается от пользовательского рабочего стола.
- XFCE failsafe: проверить владельца ~/.config, ~/.local и состояние xfconfd/DBus. Не запускайте приложения через sudo.
- Chromium sandbox: не применять --no-sandbox и не отключать AppArmor. Проверить профиль /etc/apparmor.d/cw-playwright-chromium и root-owned путь его браузера.
- RustDesk недоступен: сначала tailscale status и peer ping, затем BPF-ограничение службы, direct-server, 21118, whitelist, пароль, tailnet ACL. Пока Tailscale не авторизован, служба намеренно выключена. Не открывайте публичный порт как обход.
- После reboot: сначала SSH, Tailscale, RustDesk, LightDM; затем вручную войти workstation. Все активные чаты/AI-задачи автоматически не продолжаются.
- 4 GB: закрыть ручной браузер перед автоматизацией, не запускать Cowork и много вкладок. Swap помогает при пиках, но не заменяет RAM. Проверить OOM и PSI. Не использовать стресс-тесты без ограничений.
- Ошибка установки: исправить причину по root-only логу, повторить install.sh. При незавершённом dpkg сначала проверить отсутствие другого apt и выполнить `sudo dpkg --configure -a` осознанно. Не удалять пользовательские каталоги.
