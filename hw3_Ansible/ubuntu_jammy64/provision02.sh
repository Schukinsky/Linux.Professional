#!/bin/bash

# Обновление списка пакетов
echo "Обновление списка пакетов..."
sudo apt-get update

# Обновление установленных пакетов
echo "Обновление установленных пакетов..."
sudo apt-get upgrade -y

# Очистка ненужных пакетов
echo "Очистка ненужных пакетов..."
sudo apt-get autoremove -y

# Установка Ansible
echo "Установка Ansible..."
sudo apt-get install -y ansible

echo "Провиженинг завершен!"