## Raid. Работа с mdadm
Задача:  
• добавить в Vagrantfile еще дисков  
• собрать R0/R5/R10 на выбор  
• прописать собранный рейд в конф, чтобы рейд собирался при загрузке  
• сломать/починить raid  
• создать GPT раздел и 5 партиций и смонтировать их на диск.

### Ход выполнения работы:
1. Формируем [Vagrantfile](Vagrantfile) с 5 дополнительными дисками:
```
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  config.vm.hostname = "storage01"
  config.vm.network "public_network", ip: "192.168.1.101"

  config.vm.provider "virtualbox" do |vb|
    vb.memory = "1024"
    vb.cpus = 1
    vb.gui = false

    # Создаем 5 дисков и привязываем их к SCSI контроллеру
    (2..6).each do |i| # Порты 2, 3, 4, 5 и 6
      vb.customize ["createhd", "--filename", "disk_#{i}.vdi", "--size", 500] # Создаем диск размером 500 МБ
      vb.customize ["storageattach", :id, "--storagectl", "SCSI", "--port", i, "--device", 0, "--type", "hdd", "--medium", "disk_#{i}.vdi"]
    end
  end

  # Провизия для создания RAID
  config.vm.provision "shell", inline: <<-SHELL
    # Установка прав на выполнение для скрипта
    chmod +x /vagrant/create_raid.sh

    # Запуск скрипта для создания RAID
    bash /vagrant/create_raid.sh
  SHELL
end
```
2. Собираем RAID 10 из 4 дисков
```
sudo mdadm --create --verbose /dev/md0 -l 10 -n 4 /dev/sd{c,d,e,f}
```
2.1 Проверяем что RAID собрался
```
cat /proc/mdstat
```
```
Personalities : [linear] [multipath] [raid0] [raid1] [raid6] [raid5] [raid4] [raid10] 
md0 : active raid10 sdf[3] sde[2] sdd[1] sdc[0]
      1019904 blocks super 1.2 512K chunks 2 near-copies [4/4] [UUUU]
```
2.2 Смотрим более детальную информацию о собранном RAID md0
```
sudo mdadm -D /dev/md0
```
```
/dev/md0:
           Version : 1.2
     Creation Time : Sun Jan 26 09:41:00 2025
        Raid Level : raid10
        Array Size : 1019904 (996.00 MiB 1044.38 MB)
     Used Dev Size : 509952 (498.00 MiB 522.19 MB)
      Raid Devices : 4
     Total Devices : 4
       Persistence : Superblock is persistent

       Update Time : Sun Jan 26 09:41:05 2025
             State : clean
    Active Devices : 4
   Working Devices : 4
    Failed Devices : 0
     Spare Devices : 0

            Layout : near=2
        Chunk Size : 512K

Consistency Policy : resync

              Name : storage01:0  (local to host storage01)
              UUID : 8c4ffb83:f30865a6:7f1651f3:58cb5378
            Events : 17

    Number   Major   Minor   RaidDevice State
       0       8       32        0      active sync set-A   /dev/sdc
       1       8       48        1      active sync set-B   /dev/sdd
       2       8       64        2      active sync set-A   /dev/sde
       3       8       80        3      active sync set-B   /dev/sdf
```
2.3 Добавляем дополнительный диск sdg в RAID
```
sudo mdadm /dev/md0 --add /dev/sdg
```
2.4 Смотрим детальную информацию о собранном RAID md0
```
/dev/md0:
           Version : 1.2
     Creation Time : Sun Jan 26 09:41:00 2025
        Raid Level : raid10
        Array Size : 1019904 (996.00 MiB 1044.38 MB)
     Used Dev Size : 509952 (498.00 MiB 522.19 MB)
      Raid Devices : 4
     Total Devices : 5
       Persistence : Superblock is persistent

       Update Time : Sun Jan 26 09:49:12 2025
             State : clean
    Active Devices : 4
   Working Devices : 5
    Failed Devices : 0
     Spare Devices : 1

            Layout : near=2
        Chunk Size : 512K

Consistency Policy : resync

              Name : storage01:0  (local to host storage01)
              UUID : 8c4ffb83:f30865a6:7f1651f3:58cb5378
            Events : 18

    Number   Major   Minor   RaidDevice State
       0       8       32        0      active sync set-A   /dev/sdc
       1       8       48        1      active sync set-B   /dev/sdd
       2       8       64        2      active sync set-A   /dev/sde
       3       8       80        3      active sync set-B   /dev/sdf

       4       8       96        -      spare   /dev/sdg
```
3. Cоздание файла mdadm.conf:
   
3.1 Убедимся, что информация верна:
```
sudo mdadm --detail --scan --verbose
```
```
ARRAY /dev/md0 level=raid10 num-devices=4 metadata=1.2 spares=1 name=storage01:0 UUID=8c4ffb83:f30865a6:7f1651f3:58cb5378
   devices=/dev/sdc,/dev/sdd,/dev/sde,/dev/sdf,/dev/sdg
```
3.2 Создаем mdadm.conf
```
sudo su
echo "DEVICE partitions" > /etc/mdadm/mdadm.conf
mdadm --detail --scan --verbose | awk '/ARRAY/ {print}' >> /etc/mdadm/mdadm.conf
```
[mdadm.conf](mdadm.conf)
```
DEVICE partitions
ARRAY /dev/md0 level=raid10 num-devices=4 metadata=1.2 spares=1 name=storage01:0 UUID=8c4ffb83:f30865a6:7f1651f3:58cb5378
```
4. Сломать/починить RAID
   
4.1 Зафэйлим sdа
```
sudo mdadm /dev/md0 --fail /dev/sdf
```
4.2 Проверим состояние RAID
```
sudo mdadm -D /dev/md0
```
Видим, что диск sdg из состояния spare перешел в состояние active
```
/dev/md0:
           Version : 1.2
     Creation Time : Sun Jan 26 10:36:46 2025
        Raid Level : raid10
        Array Size : 1019904 (996.00 MiB 1044.38 MB)
     Used Dev Size : 509952 (498.00 MiB 522.19 MB)
      Raid Devices : 4
     Total Devices : 5
       Persistence : Superblock is persistent

       Update Time : Sun Jan 26 10:46:59 2025
             State : clean
    Active Devices : 4
   Working Devices : 4
    Failed Devices : 1
     Spare Devices : 0

            Layout : near=2
        Chunk Size : 512K

Consistency Policy : resync

              Name : storage01:0  (local to host storage01)
              UUID : 8c4ffb83:f30865a6:7f1651f3:58cb5378
            Events : 37

    Number   Major   Minor   RaidDevice State
       0       8       32        0      active sync set-A   /dev/sdc
       1       8       48        1      active sync set-B   /dev/sdd
       2       8       64        2      active sync set-A   /dev/sde
       4       8       96        3      active sync set-B   /dev/sdg

       3       8       80        -      faulty   /dev/sdf
```
4.3 Удалим сломанный диск sdf
```
sudo mdadm /dev/md0 --remove /dev/sdf
```
4.4 Зафэйлим sdg
```
sudo mdadm /dev/md0 --fail /dev/sdg
```
```
/dev/md0:
           Version : 1.2
     Creation Time : Sun Jan 26 10:36:46 2025
        Raid Level : raid10
        Array Size : 1019904 (996.00 MiB 1044.38 MB)
     Used Dev Size : 509952 (498.00 MiB 522.19 MB)
      Raid Devices : 4
     Total Devices : 4
       Persistence : Superblock is persistent

       Update Time : Sun Jan 26 10:53:53 2025
             State : clean, degraded
    Active Devices : 3
   Working Devices : 3
    Failed Devices : 1
     Spare Devices : 0

            Layout : near=2
        Chunk Size : 512K

Consistency Policy : resync

              Name : storage01:0  (local to host storage01)
              UUID : 8c4ffb83:f30865a6:7f1651f3:58cb5378
            Events : 40

    Number   Major   Minor   RaidDevice State
       0       8       32        0      active sync set-A   /dev/sdc
       1       8       48        1      active sync set-B   /dev/sdd
       2       8       64        2      active sync set-A   /dev/sde
       -       0        0        3      removed

       4       8       96        -      faulty   /dev/sdg
```
4.5 Удалим сломанный диск sdg
```
sudo mdadm /dev/md0 --remove /dev/sdg
```
4.6 Добавим диски sd{f,g} в RAID
```
sudo mdadm /dev/md0 --add /dev/sd{f,g}
```
```
/dev/md0:
           Version : 1.2
     Creation Time : Sun Jan 26 10:36:46 2025
        Raid Level : raid10
        Array Size : 1019904 (996.00 MiB 1044.38 MB)
     Used Dev Size : 509952 (498.00 MiB 522.19 MB)
      Raid Devices : 4
     Total Devices : 5
       Persistence : Superblock is persistent

       Update Time : Sun Jan 26 10:59:07 2025
             State : clean
    Active Devices : 4
   Working Devices : 5
    Failed Devices : 0
     Spare Devices : 1

            Layout : near=2
        Chunk Size : 512K

Consistency Policy : resync

              Name : storage01:0  (local to host storage01)
              UUID : 8c4ffb83:f30865a6:7f1651f3:58cb5378
            Events : 61

    Number   Major   Minor   RaidDevice State
       0       8       32        0      active sync set-A   /dev/sdc
       1       8       48        1      active sync set-B   /dev/sdd
       2       8       64        2      active sync set-A   /dev/sde
       5       8       96        3      active sync set-B   /dev/sdg

       4       8       80        -      spare   /dev/sdf
```
RAID восстановлен. Осуществлена проверка перехода spare диска в состояние active взамен сломанного и прехода Raid из состояния clean, degraded в clean после добавления новых дисков.

5. Создаем GPT раздел, пять партиций и монтируем их:
   
5.1 Создаем раздел GPT на RAID
```
sudo parted -s /dev/md0 mklabel gpt
```
5.2 Создаем партиции
```
sudo parted /dev/md0 mkpart primary ext4 0% 20%
sudo parted /dev/md0 mkpart primary ext4 20% 40%
sudo parted /dev/md0 mkpart primary ext4 40% 60%
sudo parted /dev/md0 mkpart primary ext4 60% 80%
sudo parted /dev/md0 mkpart primary ext4 80% 100%
```
5.3 Проверяем:
```
sudo fdisk -l
```
```
Disk /dev/md0: 996 MiB, 1044381696 bytes, 2039808 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 524288 bytes / 1048576 bytes
Disklabel type: gpt
Disk identifier: 317F0B5E-9ED0-4C46-9B5D-9BD666648B3D

Device       Start     End Sectors  Size Type
/dev/md0p1    2048  407551  405504  198M Linux filesystem
/dev/md0p2  407552  815103  407552  199M Linux filesystem
/dev/md0p3  815104 1224703  409600  200M Linux filesystem
/dev/md0p4 1224704 1632255  407552  199M Linux filesystem
/dev/md0p5 1632256 2037759  405504  198M Linux filesystem
```
5.4 Создаем на этих партициях ФС
```
for i in $(seq 1 5); do sudo mkfs.ext4 /dev/md0p$i; done
```
```
mke2fs 1.46.5 (30-Dec-2021)
Creating filesystem with 50688 4k blocks and 50688 inodes
Filesystem UUID: 27bb2937-c4e0-4c1e-be1e-6f570b04cfc4
Superblock backups stored on blocks:
        32768

Allocating group tables: done
Writing inode tables: done
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done

mke2fs 1.46.5 (30-Dec-2021)
Creating filesystem with 50944 4k blocks and 50944 inodes
Filesystem UUID: d4a307b1-ad49-4a2b-9b07-cbb33959b65e
Superblock backups stored on blocks:
        32768

Allocating group tables: done
Writing inode tables: done
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done

mke2fs 1.46.5 (30-Dec-2021)
Creating filesystem with 51200 4k blocks and 51200 inodes
Filesystem UUID: 24c1cbc3-2a15-4441-9e6f-93de5825517f
Superblock backups stored on blocks:
        32768

Allocating group tables: done
Writing inode tables: done
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done

mke2fs 1.46.5 (30-Dec-2021)
Creating filesystem with 50944 4k blocks and 50944 inodes
Filesystem UUID: 9a7225c4-d6b3-419c-8d26-cebe2aeb406f
Superblock backups stored on blocks:
        32768

Allocating group tables: done
Writing inode tables: done
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done

mke2fs 1.46.5 (30-Dec-2021)
Creating filesystem with 50688 4k blocks and 50688 inodes
Filesystem UUID: c9af51ac-e88c-4068-9689-0938015a5445
Superblock backups stored on blocks:
        32768

Allocating group tables: done
Writing inode tables: done
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done
```
5.5 Монтируем их по каталогам
```
sudo mkdir -p /raid/part{1,2,3,4,5}
sudo for i in $(seq 1 5); do sudo mount /dev/md0p$i /raid/part$i; done
```
6. На основе пунктов 2-5 формируем файл [create_raid.sh](create_raid.sh) для исполнения в Vagrantfile
```
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
```
7. mdadm — полезные команды
```
cat /proc/mdstat - cостояние массива
mdadm --detail /dev/md0 - подробный статус выбранного массива
mdadm --detail --scan --verbose - список массивов
mdadm --assemble --scan - сборка существующего массива
umount /dev/md0         - удаление массива
mdadm --stop /dev/md0
```

