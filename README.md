# scripts

## backup.ps1 — обычная Windows

Бэкап пользовательских данных (Desktop, Documents, Pictures, Videos, Music, Downloads без установщиков, AppData\Roaming, AppData\Local) на внешний диск. Сам находит подключённые флешки / SD / внешние SSD и HDD; если дисков несколько — спросит номер.

Запуск в **cmd**:

```cmd
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm 'https://raw.githubusercontent.com/IsmatillaevM/scripts/main/backup.ps1' | iex"
```

Чтобы задать букву внешнего диска заранее:

```cmd
set BACKUP_DEST=E:\
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm 'https://raw.githubusercontent.com/IsmatillaevM/scripts/main/backup.ps1' | iex"
```

## winpe-backup.cmd — Windows не загружается (WinPE / среда восстановления)

Автономный `.cmd` для WinPE: не требует PowerShell и интернета. Положи файл на флешку заранее, в WinPE запусти с неё.

Скачать: <https://raw.githubusercontent.com/IsmatillaevM/scripts/main/winpe-backup.cmd>

Использование:

1. На рабочем компьютере сохрани файл в корень флешки/внешнего диска.
2. На сломанном ноутбуке загрузись в WinPE (среду восстановления).
3. Открой cmd (`Shift+F10` на экране восстановления).
4. Запусти с буквы флешки, например:

```cmd
E:\winpe-backup.cmd
```

Назначение — тот же диск, с которого запущен скрипт. Источник — автоматически найденный профиль `\Users\<имя>` на подключённых дисках. Результат попадает в `E:\Backup_<имя>_YYYYMMDD_HHMM\`.
