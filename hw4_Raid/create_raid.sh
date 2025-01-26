#!/bin/bash
# Создание RAID 10
sudo mdadm --create --verbose /dev/md0 -l 10 -n 4 /dev/sd{c,d,e,f}
sudo mdadm /dev/md0 --add /dev/sdg
# Создание конфигурационного файла для mdadm
mdadm --detail --scan >> /etc/mdadm/mdadm.conf
# Обновление initramfs
update-initramfs -u
# Создание GPT раздела и 5 партиций
sudo parted -s /dev/md0 mklabel gpt
# Создание партиций по 20% от общего объема
parted /dev/md0 --script mkpart primary ext4 0% 20%
parted /dev/md0 --script mkpart primary ext4 20% 40%
parted /dev/md0 --script mkpart primary ext4 40% 60%
parted /dev/md0 --script mkpart primary ext4 60% 80%
parted /dev/md0 --script mkpart primary ext4 80% 100%
# Форматирование партиций
for i in {1..5}; do
    mkfs.ext4 /dev/md0p$i
done
# Создание точек монтирования
mkdir -p /mnt/raid/part1
mkdir -p /mnt/raid/part2
mkdir -p /mnt/raid/part3
mkdir -p /mnt/raid/part4
mkdir -p /mnt/raid/part5
# Монтирование партиций
mkdir -p /mnt/raid
for i in {1..5}; do
    mount /dev/md0p$i /mnt/raid/part$i
done
# Добавление записей в fstab для автоматического монтирования
echo "/dev/md0p1 /mnt/raid/part1 ext4 defaults 0 0" >> /etc/fstab
echo "/dev/md0p2 /mnt/raid/part2 ext4 defaults 0 0" >> /etc/fstab
echo "/dev/md0p3 /mnt/raid/part3 ext4 defaults 0 0" >> /etc/fstab
echo "/dev/md0p4 /mnt/raid/part4 ext4 defaults 0 0" >> /etc/fstab
echo "/dev/md0p5 /mnt/raid/part5 ext4 defaults 0 0" >> /etc/fstab