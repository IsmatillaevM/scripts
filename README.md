# scripts

## backup.ps1

Бэкап пользовательских данных (Desktop, Documents, Pictures, Videos, Music, Downloads без установщиков, AppData\Roaming, AppData\Local) на внешний диск. Сам находит подключённые флешки / SD / внешние SSD и HDD; если дисков несколько — спросит номер.

### Запуск

Открой **cmd** и вставь одну строку:

```cmd
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm 'https://raw.githubusercontent.com/IsmatillaevM/scripts/main/backup.ps1' | iex"
```

Чтобы задать букву внешнего диска заранее и не отвечать на вопрос:

```cmd
set BACKUP_DEST=E:\
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm 'https://raw.githubusercontent.com/IsmatillaevM/scripts/main/backup.ps1' | iex"
```
