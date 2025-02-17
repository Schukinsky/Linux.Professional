cat << EOF > /etc/default/watchlog
# Configuration file for my watchlog service
# Place it to /etc/default

# File and word in that file that we will be monit
WORD="ALERT"
LOG="/var/log/watchlog.log"
EOF

cat << EOF > /var/log/watchlog.log
"ALERT"
EOF
cat << EOF > /opt/watchlog.sh
#!/bin/bash

# Используем переменные окружения
WORD=$WORD
LOG=$LOG
DATE=$(date)

# Логируем запуск скрипта
logger "Running watchlog script with WORD: $WORD and LOG: $LOG"

# Проверяем, найдено ли слово в логе
if grep "$WORD" "$LOG" &> /dev/null
then
    logger "$DATE: I found word, Master!"
else
    logger "$DATE: Word not found."
    exit 0
fi
EOF
chmod +x /opt/watchlog.sh

cat << EOF > /etc/systemd/system/watchlog.service
[Unit]
Description=My watchlog service

[Service]
Type=oneshot
EnvironmentFile=/etc/default/watchlog
ExecStart=/opt/watchlog.sh "$WORD" "$LOG"
EOF

cat << EOF > /etc/systemd/system/watchlog.timer
[Unit]
Description=Run watchlog script every 30 second

[Timer]
# Run every 30 second
OnUnitActiveSec=30
Unit=watchlog.service

[Install]
WantedBy=multi-user.target
EOF

systemctl start watchlog.timer