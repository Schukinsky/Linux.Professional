# NFS. Работа с NFS

## Задача:
** Развернуть сервер с NFS и подключить на клиенте сетевую директорию:
- vagrant up должен поднимать 2 настроенных виртуальных машины (сервер NFS и клиента) без дополнительных ручных действий;
- на сервере NFS должна быть подготовлена и экспортирована директория; 
- в экспортированной директории должна быть поддиректория с именем upload с правами на запись в неё; 
- экспортированная директория должна автоматически монтироваться на клиенте при старте виртуальной машины (systemd, autofs или fstab — любым способом);
- монтирование и работа NFS на клиенте должна быть организована с использованием NFSv3.

### Ход выполнения работы:
1. Настраиваем сервер NFS 
Заходим на сервер:
```
vagrant ssh nfss
````
Установим сервер NFS от имени пользователя имеющего повышенные привилегии:
```
apt install nfs-kernel-server
````
Настройки сервера находятся в файле `/etc/nfs.conf`

<details>
<summary>Настройки сервера по умолчанию</summary>

#
# This is a general configuration for the
# NFS daemons and tools
#
[general]
pipefs-directory=/run/rpc_pipefs
#
[exports]
# rootdir=/export
#
[exportfs]
# debug=0
#
[gssd]
# verbosity=0
# rpc-verbosity=0
# use-memcache=0
# use-machine-creds=1
# use-gss-proxy=0
# avoid-dns=1
# limit-to-legacy-enctypes=0
# context-timeout=0
# rpc-timeout=5
# keytab-file=/etc/krb5.keytab
# cred-cache-directory=
# preferred-realm=
#
[lockd]
# port=0
# udp-port=0
#
[mountd]
# debug=0
manage-gids=y
# descriptors=0
# port=0
# threads=1
# reverse-lookup=n
# state-directory-path=/var/lib/nfs
# ha-callout=
#
[nfsdcld]
# debug=0
# storagedir=/var/lib/nfs/nfsdcld
#
[nfsdcltrack]
# debug=0
# storagedir=/var/lib/nfs/nfsdcltrack
#
[nfsd]
# debug=0
# threads=8
# host=
# port=0
# grace-time=90
# lease-time=90
# udp=n
# tcp=y
# vers2=n
# vers3=y
# vers4=y
# vers4.0=y
# vers4.1=y
# vers4.2=y
# rdma=n
# rdma-port=20049
#
[statd]
# debug=0
# port=0
# outgoing-port=0
# name=
# state-directory-path=/var/lib/nfs/statd
# ha-callout=
# no-notify=0
#
[sm-notify]
# debug=0
# force=0
# retry-time=900
# outgoing-port=
# outgoing-addr=
# lift-grace=y
#
[svcgssd]
# principal=

</details>

Проверяем наличие слушающих портов 2049/udp, 2049/tcp, 111/udp, 111/tcp (не все они будут использоваться далее,  но их наличие сигнализирует о том, что необходимые сервисы готовы принимать внешние подключения):
```
ss -tnplu
ss -tnplu | grep -E '2049|111'
```

<details>
<summary>Результат выполнения команды</summary>

udp   UNCONN 0      0               0.0.0.0:111        0.0.0.0:*    users:(("rpcbind",pid=2410,fd=5),("systemd",pid=1,fd=129))
udp   UNCONN 0      0                  [::]:111           [::]:*    users:(("rpcbind",pid=2410,fd=7),("systemd",pid=1,fd=131))
tcp   LISTEN 0      64              0.0.0.0:2049       0.0.0.0:*
tcp   LISTEN 0      4096            0.0.0.0:111        0.0.0.0:*    users:(("rpcbind",pid=2410,fd=4),("systemd",pid=1,fd=128))
tcp   LISTEN 0      64                 [::]:2049          [::]:*
tcp   LISTEN 0      4096               [::]:111           [::]:*    users:(("rpcbind",pid=2410,fd=6),("systemd",pid=1,fd=130))

</details>

Создаём и настраиваем директорию, которая будет экспортирована в будущем 
```

chown -R nobody:nogroup /srv/share
chmod 0777 /srv/share/upload
```
Cоздаём в файле /etc/exports структуру, которая позволит экспортировать ранее созданную директорию:
```
cat << EOF > /etc/exports 
/srv/share 192.168.50.11/32(rw,sync,root_squash)
EOF
```
Проверяем файл `/etc/exports`
```
cat /etc/exports
```
`/srv/share 192.168.50.11/32(rw,sync,root_squash)`
Экспортируем ранее созданную директорию:
```
exportfs -r
```

<details>
<summary>Результат выполнения команды</summary>

root@nfss:~# exportfs -r
exportfs: /etc/exports [1]: Neither 'subtree_check' or 'no_subtree_check' specified for export "192.168.50.11/32:/srv/share".
  Assuming default behaviour ('no_subtree_check').
  NOTE: this default has changed since nfs-utils version 1.0.x

</details>

Это предупреждение указывает на то, что NFS будет использовать поведение по умолчанию, которое в данном случае — no_subtree_check. Это означает, что NFS не будет проверять доступ к подкаталогам экспортируемого каталога.

Проверяем экспортированную директорию следующей командой
```
exportfs -s
```

<details>
<summary>Результат выполнения команды</summary>

exportfs -s
/srv/share  192.168.50.11/32(sync,wdelay,hide,no_subtree_check,sec=sys,rw,secure,root_squash,no_all_squash)

</details>

2. Настраиваем клиент NFS
Заходим на сервер клиент NFS
```
vagrant ssh nfsc 
```
Установим пакет с NFS-клиентом от имени пользователя имеющего повышенные привилегии:
```
sudo apt install nfs-common
```
Добавляем в /etc/fstab строку 
```
echo "192.168.50.10:/srv/share/ /mnt nfs vers=3,noauto,x-systemd.automount 0 0" >> /etc/fstab
```
Выполняем команды:
```bash
systemctl daemon-reload  #команда используется для перезагрузки конфигурации systemd. Она необходима, когда вы вносите изменения в файлы конфигурации служб или создаете новые юниты (unit files). 
systemctl restart remote-fs.target #команда перезапускает цель remote-fs.target, которая отвечает за монтирование удаленных файловых систем, таких как NFS.
``` 
Заходим в директорию /mnt/ и проверяем успешность монтирования:
```
mount | grep mnt
```

<details>
<summary>Результат выполнения команды</summary>

nsfs on /run/snapd/ns/lxd.mnt type nsfs (rw)
systemd-1 on /mnt type autofs (rw,relatime,fd=51,pgrp=1,timeout=0,minproto=5,maxproto=5,direct,pipe_ino=27646)

</details>

3. Проверка работоспособности
Заходим на сервер. 
Заходим в каталог /srv/share/upload
```
cd /srv/share/upload
```
Создаём тестовый файл 
```
touch check_file
```

Заходим на клиент.
Заходим в каталог /mnt/upload
```
cd /mnt/upload
```
Проверяем наличие ранее созданного файла
```
ls -l
```
<details>
<summary>Результат выполнения команды</summary>

root@nfsc:/mnt/upload# ls -l
total 0
-rw-r--r-- 1 root root 0 Feb  8 10:34 check_file

</details>

Создаём тестовый файл 
```
touch client_file
```
Проверяем, что файл успешно создан.
```
ls -l
```
<details>
<summary>Результат выполнения команды</summary>

root@nfsc:/mnt/upload# ls -l
total 0
-rw-r--r-- 1 root   root    0 Feb  8 10:34 check_file
-rw-r--r-- 1 nobody nogroup 0 Feb  8 10:37 client_file

</details>

Предварительно проверяем клиент: 
перезагружаем клиент
```
sudo reboot
```
заходим на клиент
```
vagrant ssh nfsc 
```
Проверяем наличие ранее созданных файлов
```
ls -l /mnt/upload
```
<details>
<summary>Результат выполнения команды</summary>

vagrant@nfss:~$ ls -l /mnt/upload
total 0
-rw-r--r-- 1 root   root    0 Feb  8 10:34 check_file
-rw-r--r-- 1 nobody nogroup 0 Feb  8 10:37 client_file

</details>

Проверяем сервер: 
перезагружаем сервер
```
sudo reboot
```
заходим на сервер
```
vagrant ssh nfss
````
проверяем наличие файлов в каталоге `/srv/share/upload/`
```
ls -l /srv/share/upload/
```
<details>
<summary>Результат выполнения команды</summary>

vagrant@nfss:~$ ls -l /srv/share/upload/
total 0
-rw-r--r-- 1 root   root    0 Feb  8 10:34 check_file
-rw-r--r-- 1 nobody nogroup 0 Feb  8 10:37 client_file

</details>

проверяем экспорты `exportfs -s`
```
sudo exportfs -s
```

<details>
<summary>Результат выполнения команды</summary>

exportfs -s
/srv/share  192.168.50.11/32(sync,wdelay,hide,no_subtree_check,sec=sys,rw,secure,root_squash,no_all_squash)

</details>

проверяем работу RPC 
```
showmount -a 192.168.50.10.
```
<details>
<summary>Результат выполнения команды</summary>

vagrant@nfss:~$ showmount -a 192.168.50.10
All mount points on 192.168.50.10:
192.168.50.11:/srv/share

</details>


Проверяем клиент: 
перезагружаем клиент
```
sudo reboot
```
заходим на клиент
```
vagrant ssh nfsc 
```
проверяем работу RPC 
```
showmount -a 192.168.50.10
```
<details>
<summary>Результат выполнения команды</summary>

vagrant@nfsc:~$ showmount -a 192.168.50.10
All mount points on 192.168.50.10:
192.168.50.11:/srv/share

</details>

проверяем статус монтирования 
```
mount | grep mnt
```
<details>
<summary>Результат выполнения команды</summary>

vagrant@nfsc:~$ mount | grep mnt
systemd-1 on /mnt type autofs (rw,relatime,fd=61,pgrp=1,timeout=0,minproto=5,maxproto=5,direct,pipe_ino=15711)
192.168.50.10:/srv/share/ on /mnt type nfs (rw,relatime,vers=3,rsize=131072,wsize=131072,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,mountaddr=192.168.50.10,mountvers=3,mountport=39568,mountproto=udp,local_lock=none,addr=192.168.50.10)
nsfs on /run/snapd/ns/lxd.mnt type nsfs (rw)

</details>
заходим в каталог /mnt/upload;
проверяем наличие ранее созданных файлов
```
ls -l /mnt/upload
```
<details>
<summary>Результат выполнения команды</summary>

vagrant@nfsc:~$ ls -l /mnt/upload
total 0
-rw-r--r-- 1 root   root    0 Feb  8 10:34 check_file
-rw-r--r-- 1 nobody nogroup 0 Feb  8 10:37 client_file

</details>
создаём тестовый файл touch final_check
```
touch /mnt/upload/final_check
```
проверяем, что файл успешно создан.
```
ls -l /mnt/upload
```
<details>
<summary>Результат выполнения команды</summary>

vagrant@nfsc:~$ ls -l /mnt/upload
total 0
-rw-r--r-- 1 root    root    0 Feb  8 10:34 check_file
-rw-r--r-- 1 nobody  nogroup 0 Feb  8 10:37 client_file
-rw-rw-r-- 1 vagrant vagrant 0 Feb  8 11:04 final_check

</details>
