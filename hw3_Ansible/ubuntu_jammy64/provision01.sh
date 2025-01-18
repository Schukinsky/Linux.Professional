#!/bin/bash

# Обновление списка пакетов
sudo apt-get update

# Обновление установленных пакетов
sudo apt-get upgrade -y

# Очистка ненужных пакетов
sudo apt-get autoremove -y

