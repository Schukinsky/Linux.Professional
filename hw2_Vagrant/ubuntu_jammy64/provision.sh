#!/bin/bash

# Обновление списка пакетов
sudo apt-get update

# Обновление установленных пакетов
sudo apt-get upgrade -y

# Очистка ненужных пакетов
sudo apt-get autoremove -y

# Путь к каталогу
SHARED_FOLDER="/home/vagrant/shared_folder"

# Проверка, существует ли каталог
if [ ! -d "$SHARED_FOLDER" ]; then
  echo "Каталог $SHARED_FOLDER не существует."
  exit 1
fi

# Получение количества файлов в каталоге
FILE_COUNT=$(ls -1 "$SHARED_FOLDER" | wc -l)

# Создание нового файла с порядковым номером
NEW_FILE_NAME="test_ubuntu$(printf "%02d" $((FILE_COUNT + 1))).txt"
touch "$SHARED_FOLDER/$NEW_FILE_NAME"

echo "Создан файл: $NEW_FILE_NAME"