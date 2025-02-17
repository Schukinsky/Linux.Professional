# Systemd. Работа с NFS

## Задача:
1. Написать service, который будет раз в 30 секунд мониторить лог на предмет наличия ключевого слова (файл лога и ключевое слово должны задаваться в /etc/default);
2. Установить spawn-fcgi и создать unit-файл (spawn-fcgi.sevice) с помощью переделки init-скрипта (https://gist.github.com/cea2k/1318020);
3. Доработать unit-файл Nginx (nginx.service) для запуска нескольких инстансов сервера с разными конфигурационными файлами одновременно;


### Ход выполнения работы:
1.  
1.1 Cоздаём файл с конфигурацией для сервиса в директории /etc/default - из неё сервис будет брать необходимые переменные
```bash
sudo bash -c 'cat > /etc/default/watchlog << "EOF"
# Configuration file for my watchlog service
# Place it to /etc/default

# File and word in that file that we will be monit
WORD="ALERT"
LOG=/var/log/watchlog.log
EOF'
```

1.2 Затем создаем `/var/log/watchlog.log` :
```bash
sudo bash -c 'cat > /var/log/watchlog.log <<EOF
2025-02-16 10:15:23, ALERT: an important event occurred
2025-02-16 10:16:23, INFO: a normal event message
2025-02-16 10:17:23, ALERT: an important event occurred
2025-02-16 10:15:23, INFO: a normal event message
2025-02-16 11:15:23, INFO: a normal event message
2025-02-16 13:15:23, ALERT: an important event occurred
2025-02-16 14:15:23, INFO: a normal event message
2025-02-16 15:15:23, ALERT: an important event occurred
2025-02-16 16:15:23, ALERT: an important event occurred
2025-02-16 17:15:23, INFO: a normal event message
EOF'
```
1.3  Создадим скрипт: `/opt/watchlog.sh` (Команда logger отправляет лог в системный журнал.)
``` bash
sudo bash -c 'cat > /opt/watchlog.sh << "EOF"
#!/bin/bash

WORD=\$1
LOG=\$2
DATE=\`date\`

if grep \$WORD \$LOG &> /dev/null
then
  logger "\$DATE: I found word, Master!"
else
  exit 0
fi
EOF'
```
1.4 Добавим права на запуск файла:
```
chmod +x /opt/watchlog.sh
```
1.5 Создадим юнит для сервиса:
```bash
sudo bash -c 'cat > /etc/systemd/system/watchlog.service << EOF
[Unit]
Description=My watchlog service

[Service]
Type=oneshot
EnvironmentFile=/etc/default/watchlog
ExecStart=/opt/watchlog.sh \$WORD \$LOG
EOF'
```
1.6 Создадим юнит для таймера:
```bash
sudo bash -c 'cat > /etc/systemd/system/watchlog.timer << EOF
[Unit]
Description=Run watchlog script every 30 second

[Timer]
# Run every 30 second
OnUnitActiveSec=30
Unit=watchlog.service

[Install]
WantedBy=multi-user.target
EOF'
```
1.7 Запускаем timer:
```
systemctl start watchlog.timer
```
1.8 Проверяем лог:
```bash
tail -n 1000 /var/log/syslog  | grep word
```

root@ubuntu2204:~# sudo systemctl start watchlog.service
root@ubuntu2204:~# journalctl -u watchlog.service
Feb 16 18:05:49 ubuntu2204.localdomain watchlog.sh[3168]: /opt/watchlog.sh: line 5: Feb: command not found
Feb 16 18:05:49 ubuntu2204.localdomain systemd[1]: Starting My watchlog service...
Feb 16 18:05:49 ubuntu2204.localdomain systemd[1]: watchlog.service: Deactivated successfully.
Feb 16 18:05:49 ubuntu2204.localdomain systemd[1]: Finished My watchlog service.