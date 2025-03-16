# hw13_SELinux

## Задача:
1. Запустить nginx на нестандартном порту 3-мя разными способами:
- переключатели setsebool;
- добавление нестандартного порта в имеющийся тип;
- формирование и установка модуля SELinux.

2. Обеспечить работоспособность приложения при включенном selinux.
- развернуть приложенный стенд https://github.com/mbfx/otus-linux-adm/tree/master/selinux_dns_problems;
- выяснить причину неработоспособности механизма обновления зоны;
- предложить решение (или решения) для данной проблемы;
- выбрать одно из решений для реализации, предварительно обосновав выбор;
- реализовать выбранное решение и продемонстрировать его работоспособность.

## Выполнение:
1. Запустить nginx на нестандартном порту 3-мя разными способами:  
Разворачиваем виртуальную машину из предоставленного [Vagrantfile](Vagrantfile) с установленным nginx, который работает на порту TCP 4881. Порт TCP 4881 уже проброшен до хоста. SELinux включен.
```
vagrant up
```

Во время развёртывания стенда попытка запустить nginx завершится с ошибкой:
```
selinux: Job for nginx.service failed because the control process exited with error code.
    selinux: See "systemctl status nginx.service" and "journalctl -xeu nginx.service" for details.
    selinux: × nginx.service - The nginx HTTP and reverse proxy server
    selinux:      Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; preset: disabled)
    selinux:      Active: failed (Result: exit-code) since Sun 2025-03-16 08:10:01 UTC; 38ms ago
    selinux:     Process: 6661 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
    selinux:     Process: 6662 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=1/FAILURE)
    selinux:         CPU: 53ms
    selinux:
    selinux: Mar 16 08:10:01 selinux systemd[1]: Starting The nginx HTTP and reverse proxy server...
    selinux: Mar 16 08:10:01 selinux nginx[6662]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
    selinux: Mar 16 08:10:01 selinux nginx[6662]: nginx: [emerg] bind() to 0.0.0.0:4881 failed (13: Permission denied)
    selinux: Mar 16 08:10:01 selinux nginx[6662]: nginx: configuration file /etc/nginx/nginx.conf test failed
    selinux: Mar 16 08:10:01 selinux systemd[1]: nginx.service: Control process exited, code=exited, status=1/FAILURE
    selinux: Mar 16 08:10:01 selinux systemd[1]: nginx.service: Failed with result 'exit-code'.
    selinux: Mar 16 08:10:01 selinux systemd[1]: Failed to start The nginx HTTP and reverse proxy server.
```
Данная ошибка появляется из-за того, что SELinux блокирует работу nginx на нестандартном порту.  
Заходим на сервер: `vagrant ssh`    
Дальнейшие действия выполняются от пользователя root. Переходим в root пользователя: `sudo -i`  

Для начала проверим, что в ОС отключен файервол: `systemctl status firewalld`
```
[root@selinux ~]# systemctl status firewalld
○ firewalld.service - firewalld - dynamic firewall daemon
     Loaded: loaded (/usr/lib/systemd/system/firewalld.service; disabled; preset: enabled)
     Active: inactive (dead)
       Docs: man:firewalld(1)
```
Также проверим, что конфигурация nginx настроена без ошибок: `nginx -t`
```
[root@selinux ~]# nginx -t
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```
Далее проверим режим работы SELinux: `getenforce`
```
[root@selinux ~]# getenforce
Enforcing
```

- Способ № 1. Разрешим в SELinux работу nginx на порту TCP 4881 c помощью переключателей setsebool
Находим в логах (/var/log/audit/audit.log) информацию о блокировании порта:
```
cat /var/log/audit/audit.log | grep 4881
```
```
[root@selinux ~]# cat /var/log/audit/audit.log | grep 4881
type=AVC msg=audit(1742112601.245:707): avc:  denied  { name_bind } for  pid=6662 comm="nginx" src=4881 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0
```
Копируем время, в которое был записан этот лог, и, с помощью утилиты audit2why смотрим 	
 ```
grep 1742112601.245:707 /var/log/audit/audit.log | audit2why
```

```
[root@selinux ~]# grep 1742112601.245:707 /var/log/audit/audit.log | audit2why
type=AVC msg=audit(1742112601.245:707): avc:  denied  { name_bind } for  pid=6662 comm="nginx" src=4881 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0

        Was caused by:
        The boolean nis_enabled was set incorrectly. 
        Description:
        Allow nis to enabled        

        Allow access by executing:  
        # setsebool -P nis_enabled 1
```
Утилита audit2why покажет почему трафик блокируется. Исходя из вывода утилиты, мы видим, что нам нужно поменять параметр nis_enabled. 
Включим параметр nis_enabled и перезапустим nginx: `setsebool -P nis_enabled on`
```
[root@selinux ~]# systemctl status nginx
● nginx.service - The nginx HTTP and reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; preset: disabled)
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; preset: disabled)
     Active: active (running) since Sun 2025-03-16 08:45:05 UTC; 14s ago
    Process: 6783 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
    Process: 6784 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)
    Process: 6785 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)
   Main PID: 6787 (nginx)
      Tasks: 3 (limit: 11997)
     Memory: 2.9M
        CPU: 110ms
     CGroup: /system.slice/nginx.service
             ├─6787 "nginx: master process /usr/sbin/nginx"
             ├─6788 "nginx: worker process"
             └─6789 "nginx: worker process"

Mar 16 08:45:04 selinux systemd[1]: Starting The nginx HTTP and reverse proxy server...
Mar 16 08:45:04 selinux nginx[6784]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
Mar 16 08:45:04 selinux nginx[6784]: nginx: configuration file /etc/nginx/nginx.conf test is successful
Mar 16 08:45:05 selinux systemd[1]: Started The nginx HTTP and reverse proxy server.
```
Заходим в  браузер на хосте и переходим по адресу http://127.0.0.1:4881  
[screen01](screen01.PNG)

Проверить статус параметра можно с помощью команды: `getsebool -a | grep nis_enabled`
```
[root@selinux ~]# getsebool -a | grep nis_enabled
nis_enabled --> on
```
Вернём запрет работы nginx на порту 4881 обратно. Для этого отключим nis_enabled: `setsebool -P nis_enabled off`
После отключения nis_enabled служба nginx снова не запустится.

- Способ 2.  Разрешим в SELinux работу nginx на порту TCP 4881 c помощью добавления нестандартного порта в имеющийся тип:
Поиск имеющегося типа, для http трафика: `semanage port -l | grep http`
```
[root@selinux ~]# semanage port -l | grep http
http_cache_port_t              tcp      8080, 8118, 8123, 10001-10010
http_cache_port_t              udp      3130
http_port_t                    tcp      80, 81, 443, 488, 8008, 8009, 8443, 9000
pegasus_http_port_t            tcp      5988
pegasus_https_port_t           tcp      5989
```
Добавим порт в тип http_port_t: `semanage port -a -t http_port_t -p tcp 4881`
```
[root@selinux ~]# semanage port -a -t http_port_t -p tcp 4881
[root@selinux ~]# semanage port -l | grep  http_port_t
http_port_t                    tcp      4881, 80, 81, 443, 488, 8008, 8009, 8443, 9000
pegasus_http_port_t            tcp      5988
```
Теперь перезапускаем службу nginx и проверим её работу: `systemctl restart nginx`
```
[root@selinux ~]# systemctl restart nginx
[root@selinux ~]# systemctl status nginx
● nginx.service - The nginx HTTP and reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; preset: disabled)
     Active: active (running) since Sun 2025-03-16 08:54:37 UTC; 16s ago
    Process: 6814 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
    Process: 6816 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)
    Process: 6817 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)
   Main PID: 6818 (nginx)
      Tasks: 3 (limit: 11997)
     Memory: 2.9M
        CPU: 79ms
     CGroup: /system.slice/nginx.service
             ├─6818 "nginx: master process /usr/sbin/nginx"
             ├─6819 "nginx: worker process"
             └─6820 "nginx: worker process"

Mar 16 08:54:37 selinux systemd[1]: Starting The nginx HTTP and reverse proxy server...
Mar 16 08:54:37 selinux nginx[6816]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
```
Также можно проверить работу nginx из браузера. Заходим в любой браузер на хосте и переходим по адресу http://127.0.0.1:4881

Удалить нестандартный порт из имеющегося типа можно с помощью команды: `semanage port -d -t http_port_t -p tcp 4881`
```
[root@selinux ~]# semanage port -d -t http_port_t -p tcp 4881
[root@selinux ~]# semanage port -l | grep  http_port_t
http_port_t                    tcp      80, 81, 443, 488, 8008, 8009, 8443, 9000
pegasus_http_port_t            tcp      5988
```
- Способ 3. Разрешим в SELinux работу nginx на порту TCP 4881 c помощью формирования и установки модуля SELinux:
Попробуем снова запустить Nginx: `systemctl start nginx`
```
[root@selinux ~]# systemctl start nginx
Job for nginx.service failed because the control process exited with error code.
See "systemctl status nginx.service" and "journalctl -xeu nginx.service" for details.
```
Nginx не запустится, так как SELinux продолжает его блокировать. Посмотрим логи SELinux, которые относятся к Nginx: 
```
[root@selinux ~]# grep nginx /var/log/audit/audit.log
type=ADD_GROUP msg=audit(1742112541.821:601): pid=2868 uid=0 auid=1000 ses=3 subj=unconfined_u:unconfined_r:groupadd_t:s0-s0:c0.c1023 msg='op=add-group id=991 exe="/usr/sbin/groupadd" hostname=? addr=? terminal=? res=success'UID="root" AUID="vagrant" ID="nginx"
type=GRP_MGMT msg=audit(1742112541.825:602): pid=2868 uid=0 auid=1000 ses=3 subj=unconfined_u:unconfined_r:groupadd_t:s0-s0:c0.c1023 msg='op=add-shadow-group id=991 exe="/usr/sbin/groupadd" hostname=? addr=? terminal=? res=success'UID="root" AUID="vagrant" ID="nginx"
type=ADD_USER msg=audit(1742112541.897:603): pid=2875 uid=0 auid=1000 ses=3 subj=unconfined_u:unconfined_r:useradd_t:s0-s0:c0.c1023 msg='op=add-user acct="nginx" exe="/usr/sbin/useradd" hostname=? addr=? terminal=? res=success'UID="root" AUID="vagrant"
type=SOFTWARE_UPDATE msg=audit(1742112542.614:625): pid=2847 uid=0 auid=1000 ses=3 subj=unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023 msg='op=install sw="nginx-filesystem-2:1.20.1-20.el9.alma.1.noarch" sw_type=rpm key_enforce=0 gpg_res=1 root_dir="/" comm="yum" exe="/usr/bin/python3.9" hostname=? addr=? terminal=? res=success'UID="root" AUID="vagrant"
type=SOFTWARE_UPDATE msg=audit(1742112542.614:626): pid=2847 uid=0 auid=1000 ses=3 subj=unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023 msg='op=install sw="nginx-core-2:1.20.1-20.el9.alma.1.x86_64" sw_type=rpm key_enforce=0 gpg_res=1 root_dir="/" comm="yum" exe="/usr/bin/python3.9" hostname=? addr=? terminal=? res=success'UID="root" AUID="vagrant"
type=SOFTWARE_UPDATE msg=audit(1742112542.616:628): pid=2847 uid=0 auid=1000 ses=3 subj=unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023 msg='op=install sw="nginx-2:1.20.1-20.el9.alma.1.x86_64" sw_type=rpm key_enforce=0 gpg_res=1 root_dir="/" comm="yum" exe="/usr/bin/python3.9" hostname=? addr=? terminal=? res=success'UID="root" AUID="vagrant"
type=AVC msg=audit(1742112601.245:707): avc:  denied  { name_bind } for  pid=6662 comm="nginx" src=4881 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0
type=SYSCALL msg=audit(1742112601.245:707): arch=c000003e syscall=49 success=no exit=-13 a0=6 a1=555f742496b0 a2=10 a3=7ffe77449660 items=0 ppid=1 pid=6662 auid=4294967295 uid=0 gid=0 euid=0 suid=0 
fsuid=0 egid=0 sgid=0 fsgid=0 tty=(none) ses=4294967295 comm="nginx" exe="/usr/sbin/nginx" subj=system_u:system_r:httpd_t:s0 key=(null)ARCH=x86_64 SYSCALL=bind AUID="unset" UID="root" GID="root" EU
ID="root" SUID="root" FSUID="root" EGID="root" SGID="root" FSGID="root"
type=SERVICE_START msg=audit(1742112601.251:708): pid=1 uid=0 auid=4294967295 ses=4294967295 subj=system_u:system_r:init_t:s0 msg='unit=nginx comm="systemd" exe="/usr/lib/systemd/systemd" hostname=? addr=? terminal=? res=failed'UID="root" AUID="unset"
type=SERVICE_START msg=audit(1742114705.008:769): pid=1 uid=0 auid=4294967295 ses=4294967295 subj=system_u:system_r:init_t:s0 msg='unit=nginx comm="systemd" exe="/usr/lib/systemd/systemd" hostname=? addr=? terminal=? res=success'UID="root" AUID="unset"
type=SERVICE_STOP msg=audit(1742115277.843:774): pid=1 uid=0 auid=4294967295 ses=4294967295 subj=system_u:system_r:init_t:s0 msg='unit=nginx comm="systemd" exe="/usr/lib/systemd/systemd" hostname=? 
addr=? terminal=? res=success'UID="root" AUID="unset"
type=SERVICE_START msg=audit(1742115277.959:775): pid=1 uid=0 auid=4294967295 ses=4294967295 subj=system_u:system_r:init_t:s0 msg='unit=nginx comm="systemd" exe="/usr/lib/systemd/systemd" hostname=? addr=? terminal=? res=success'UID="root" AUID="unset"
type=SERVICE_STOP msg=audit(1742115525.407:778): pid=1 uid=0 auid=4294967295 ses=4294967295 subj=system_u:system_r:init_t:s0 msg='unit=nginx comm="systemd" exe="/usr/lib/systemd/systemd" hostname=? 
addr=? terminal=? res=success'UID="root" AUID="unset"
type=AVC msg=audit(1742115525.453:779): avc:  denied  { name_bind } for  pid=6837 comm="nginx" src=4881 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0
type=SYSCALL msg=audit(1742115525.453:779): arch=c000003e syscall=49 success=no exit=-13 a0=6 a1=55fb28fda6b0 a2=10 a3=7ffcfb384320 items=0 ppid=1 pid=6837 auid=4294967295 uid=0 gid=0 euid=0 suid=0 
fsuid=0 egid=0 sgid=0 fsgid=0 tty=(none) ses=4294967295 comm="nginx" exe="/usr/sbin/nginx" subj=system_u:system_r:httpd_t:s0 key=(null)ARCH=x86_64 SYSCALL=bind AUID="unset" UID="root" GID="root" EU
ID="root" SUID="root" FSUID="root" EGID="root" SGID="root" FSGID="root"
type=SERVICE_START msg=audit(1742115525.456:780): pid=1 uid=0 auid=4294967295 ses=4294967295 subj=system_u:system_r:init_t:s0 msg='unit=nginx comm="systemd" exe="/usr/lib/systemd/systemd" hostname=? addr=? terminal=? res=failed'UID="root" AUID="unset"
type=AVC msg=audit(1742115547.129:785): avc:  denied  { name_bind } for  pid=6856 comm="nginx" src=4881 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0
type=SYSCALL msg=audit(1742115547.129:785): arch=c000003e syscall=49 success=no exit=-13 a0=6 a1=5603ab6306b0 a2=10 a3=7fffa7dfd9d0 items=0 ppid=1 pid=6856 auid=4294967295 uid=0 gid=0 euid=0 suid=0 
fsuid=0 egid=0 sgid=0 fsgid=0 tty=(none) ses=4294967295 comm="nginx" exe="/usr/sbin/nginx" subj=system_u:system_r:httpd_t:s0 key=(null)ARCH=x86_64 SYSCALL=bind AUID="unset" UID="root" GID="root" EU
ID="root" SUID="root" FSUID="root" EGID="root" SGID="root" FSGID="root"
type=SERVICE_START msg=audit(1742115547.137:786): pid=1 uid=0 auid=4294967295 ses=4294967295 subj=system_u:system_r:init_t:s0 msg='unit=nginx comm="systemd" exe="/usr/lib/systemd/systemd" hostname=? addr=? terminal=? res=failed'UID="root" AUID="unset"
```

Воспользуемся утилитой audit2allow для того, чтобы на основе логов SELinux сделать модуль, разрешающий работу nginx на нестандартном порту: 
`grep nginx /var/log/audit/audit.log | audit2allow -M nginx`

```
[root@selinux ~]# grep nginx /var/log/audit/audit.log | audit2allow -M nginx
******************** IMPORTANT ***********************
To make this policy package active, execute:

semodule -i nginx.pp
```
Audit2allow сформировал модуль, и сообщил нам команду, с помощью которой можно применить данный модуль: `semodule -i nginx.pp`
```
[root@selinux ~]# semodule -i nginx.pp
[root@selinux ~]# systemctl start nginx
[root@selinux ~]# systemctl status nginx
● nginx.service - The nginx HTTP and reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; preset: disabled)
     Active: active (running) since Sun 2025-03-16 09:08:06 UTC; 21s ago
    Process: 6902 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
    Process: 6903 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)
    Process: 6904 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)
   Main PID: 6905 (nginx)
      Tasks: 3 (limit: 11997)
     Memory: 2.9M
        CPU: 51ms
     CGroup: /system.slice/nginx.service
             ├─6905 "nginx: master process /usr/sbin/nginx"
             ├─6906 "nginx: worker process"
             └─6907 "nginx: worker process"

Mar 16 09:08:06 selinux systemd[1]: Starting The nginx HTTP and reverse proxy server...
Mar 16 09:08:06 selinux nginx[6903]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
Mar 16 09:08:06 selinux nginx[6903]: nginx: configuration file /etc/nginx/nginx.conf test is successful
Mar 16 09:08:06 selinux systemd[1]: Started The nginx HTTP and reverse proxy server.
```
После добавления модуля nginx запустился без ошибок. При использовании модуля изменения сохранятся после перезагрузки.  
Также можно проверить работу nginx из браузера. Заходим в любой браузер на хосте и переходим по адресу http://127.0.0.1:4881 
Просмотр всех установленных модулей: `semodule -l`
Для удаления модуля воспользуемся командой: `semodule -r nginx`
```
[root@selinux ~]# semodule -r nginx
libsemanage.semanage_direct_remove_key: Removing last nginx module (no other nginx module exists at another priority).
```
2. Обеспечить работоспособность приложения при включенном selinux:
Для выполнения данного задания используем виртуальную машину на Ubuntu, с установленными пакетами Ansible, Git, Vagrant, VirtualBox ([Vagrantfile](ansible_host/Vagrantfile))
Выполним клонирование репозитория:
git clone https://github.com/Nickmob/vagrant_selinux_dns_problems.git
```
vagrant@ubuntu-bionic:~$ git clone https://github.com/Nickmob/vagrant_selinux_dns_problems.git
Cloning into 'vagrant_selinux_dns_problems'...
remote: Enumerating objects: 32, done.
remote: Counting objects: 100% (32/32), done.
remote: Compressing objects: 100% (21/21), done.
remote: Total 32 (delta 9), reused 29 (delta 9), pack-reused 0 (from 0)
Unpacking objects: 100% (32/32), done.
```
Перейдём в каталог со стендом: `cd vagrant_selinux_dns_problems`
Развернём 2 ВМ с помощью vagrant: `vagrant up`
После того, как стенд развернется, проверим ВМ с помощью команды: `vagrant status`
```
vagrant@ubuntu-bionic:~/vagrant_selinux_dns_problems$ vagrant status
Current machine states:

ns01                      running (virtualbox)
client                    running (virtualbox)

This environment represents multiple VMs. The VMs are all listed
above with their current state. For more information about a specific
VM, run `vagrant status NAME`.
```
Подключимся к клиенту: `vagrant ssh client`
Попробуем внести изменения в зону: `nsupdate -k /etc/named.zonetransfer.key`
```
[vagrant@client ~]$ nsupdate -k /etc/named.zonetransfer.key
> server 192.168.50.10
> zone ddns.lab
> update add www.ddns.lab. 60 A 192.168.50.15
> send
update failed: SERVFAIL
> quit
```
Изменения внести не получилось. Давайте посмотрим логи SELinux, чтобы понять в чём может быть проблема.
Для этого воспользуемся утилитой audit2why: 	
[vagrant@client ~]$ sudo -i
[root@client ~]# cat /var/log/audit/audit.log | audit2why

```
[root@client ~]# cat /var/log/audit/audit.log | audit2why
```
Тут мы видим, что на клиенте отсутствуют ошибки. 
Не закрывая сессию на клиенте, подключимся к серверу ns01 и проверим логи SELinux:
`vagrant ssh ns01 `
 sudo -i 
[root@ns01 ~]# 
[root@ns01 ~]# 
[root@ns01 ~]# cat /var/log/audit/audit.log | audit2why
```
vagrant@ubuntu-bionic:~/vagrant_selinux_dns_problems$ vagrant ssh ns01
Last login: Sun Mar 16 11:07:18 2025 from 10.0.2.2
[vagrant@ns01 ~]$ sudo -i 
[root@ns01 ~]# cat /var/log/audit/audit.log | audit2why
type=AVC msg=audit(1742123690.356:1873): avc:  denied  { write } for  pid=7883 comm="isc-net-0000" name="dynamic" dev="sda4" ino=34068224 scontext=system_u:system_r:named_t:s0 tcontext=unconfined_u:object_r:named_conf_t:s0 tclass=dir permissive=0

        Was caused by:
                Missing type enforcement (TE) allow rule.

                You can use audit2allow to generate a loadable module to allow this access.
```
В логах мы видим, что ошибка в контексте безопасности. Целевой контекст named_conf_t.
Для сравнения посмотрим существующую зону (localhost) и её контекст:
```
[root@ns01 ~]# ls -alZ /var/named/named.localhost
-rw-r-----. 1 root named system_u:object_r:named_zone_t:s0 152 Feb 19 16:04 /var/named/named.localhost
```

У наших конфигов в /etc/named вместо типа named_zone_t используется тип named_conf_t.
Проверим данную проблему в каталоге /etc/named:
```
[root@ns01 ~]# ls -laZ /etc/named
total 28
drw-rwx---.  3 root named system_u:object_r:named_conf_t:s0      121 Mar 16 11:07 .
drwxr-xr-x. 85 root root  system_u:object_r:etc_t:s0            8192 Mar 16 11:07 ..
drw-rwx---.  2 root named unconfined_u:object_r:named_conf_t:s0   56 Mar 16 11:07 dynamic
-rw-rw----.  1 root named system_u:object_r:named_conf_t:s0      784 Mar 16 11:07 named.50.168.192.rev
-rw-rw----.  1 root named system_u:object_r:named_conf_t:s0      610 Mar 16 11:07 named.dns.lab
-rw-rw----.  1 root named system_u:object_r:named_conf_t:s0      609 Mar 16 11:07 named.dns.lab.view1
-rw-rw----.  1 root named system_u:object_r:named_conf_t:s0      657 Mar 16 11:07 named.newdns.lab
```

Тут мы также видим, что контекст безопасности неправильный. Проблема заключается в том, что конфигурационные файлы лежат в другом каталоге. Посмотреть в каком каталоге должны лежать файлы, чтобы на них распространялись правильные политики SELinux можно с помощью команды: sudo semanage fcontext -l | grep named

```
[root@ns01 ~]# sudo semanage fcontext -l | grep named
/dev/gpmdata                                       named pipe         system_u:object_r:gpmctl_t:s0
/dev/initctl                                       named pipe         system_u:object_r:initctl_t:s0
/dev/xconsole                                      named pipe         system_u:object_r:xconsole_device_t:s0
/dev/xen/tapctrl.*                                 named pipe         system_u:object_r:xenctl_t:s0
/etc/named(/.*)?                                   all files          system_u:object_r:named_conf_t:s0
/etc/named\.caching-nameserver\.conf               regular file       system_u:object_r:named_conf_t:s0
/etc/named\.conf                                   regular file       system_u:object_r:named_conf_t:s0
/etc/named\.rfc1912.zones                          regular file       system_u:object_r:named_conf_t:s0
/etc/named\.root\.hints                            regular file       system_u:object_r:named_conf_t:s0
/etc/rc\.d/init\.d/named                           regular file       system_u:object_r:named_initrc_exec_t:s0
/etc/rc\.d/init\.d/named-sdb                       regular file       system_u:object_r:named_initrc_exec_t:s0
/etc/rc\.d/init\.d/unbound                         regular file       system_u:object_r:named_initrc_exec_t:s0
/etc/rndc.*                                        regular file       system_u:object_r:named_conf_t:s0
/etc/unbound(/.*)?                                 all files          system_u:object_r:named_conf_t:s0
/usr/lib/systemd/system/named-sdb.*                regular file       system_u:object_r:named_unit_file_t:s0
/usr/lib/systemd/system/named.*                    regular file       system_u:object_r:named_unit_file_t:s0
/usr/lib/systemd/system/unbound.*                  regular file       system_u:object_r:named_unit_file_t:s0
/usr/lib/systemd/systemd-hostnamed                 regular file       system_u:object_r:systemd_hostnamed_exec_t:s0
/usr/sbin/lwresd                                   regular file       system_u:object_r:named_exec_t:s0
/usr/sbin/named                                    regular file       system_u:object_r:named_exec_t:s0
/usr/sbin/named-checkconf                          regular file       system_u:object_r:named_checkconf_exec_t:s0
/usr/sbin/named-pkcs11                             regular file       system_u:object_r:named_exec_t:s0
/usr/sbin/named-sdb                                regular file       system_u:object_r:named_exec_t:s0
/usr/sbin/unbound                                  regular file       system_u:object_r:named_exec_t:s0
/usr/sbin/unbound-anchor                           regular file       system_u:object_r:named_exec_t:s0
/usr/sbin/unbound-checkconf                        regular file       system_u:object_r:named_exec_t:s0
/usr/sbin/unbound-control                          regular file       system_u:object_r:named_exec_t:s0
/usr/share/munin/plugins/named                     regular file       system_u:object_r:services_munin_plugin_exec_t:s0
/var/lib/softhsm(/.*)?                             all files          system_u:object_r:named_cache_t:s0
/var/lib/unbound(/.*)?                             all files          system_u:object_r:named_cache_t:s0
/var/log/named.*                                   regular file       system_u:object_r:named_log_t:s0
/var/named(/.*)?                                   all files          system_u:object_r:named_zone_t:s0
/var/named/chroot(/.*)?                            all files          system_u:object_r:named_conf_t:s0
/var/named/chroot/dev                              directory          system_u:object_r:device_t:s0
/var/named/chroot/dev/log                          socket             system_u:object_r:devlog_t:s0
/var/named/chroot/dev/null                         character device   system_u:object_r:null_device_t:s0
/var/named/chroot/dev/random                       character device   system_u:object_r:random_device_t:s0
/var/named/chroot/dev/urandom                      character device   system_u:object_r:urandom_device_t:s0
/var/named/chroot/dev/zero                         character device   system_u:object_r:zero_device_t:s0
/var/named/chroot/etc(/.*)?                        all files          system_u:object_r:etc_t:s0
/var/named/chroot/etc/localtime                    regular file       system_u:object_r:locale_t:s0
/var/named/chroot/etc/named\.caching-nameserver\.conf regular file       system_u:object_r:named_conf_t:s0
/var/named/chroot/etc/named\.conf                  regular file       system_u:object_r:named_conf_t:s0
/var/named/chroot/etc/named\.rfc1912.zones         regular file       system_u:object_r:named_conf_t:s0
/var/named/chroot/etc/named\.root\.hints           regular file       system_u:object_r:named_conf_t:s0
/var/named/chroot/etc/pki(/.*)?                    all files          system_u:object_r:cert_t:s0
/var/named/chroot/etc/rndc\.key                    regular file       system_u:object_r:dnssec_t:s0
/var/named/chroot/lib(/.*)?                        all files          system_u:object_r:lib_t:s0
/var/named/chroot/proc(/.*)?                       all files          <<None>>
/var/named/chroot/run/named.*                      all files          system_u:object_r:named_var_run_t:s0
/var/named/chroot/usr/lib(/.*)?                    all files          system_u:object_r:lib_t:s0
/var/named/chroot/var/log                          directory          system_u:object_r:var_log_t:s0
/var/named/chroot/var/log/named.*                  regular file       system_u:object_r:named_log_t:s0
/var/named/chroot/var/named(/.*)?                  all files          system_u:object_r:named_zone_t:s0
/var/named/chroot/var/named/data(/.*)?             all files          system_u:object_r:named_cache_t:s0
/var/named/chroot/var/named/dynamic(/.*)?          all files          system_u:object_r:named_cache_t:s0
/var/named/chroot/var/named/named\.ca              regular file       system_u:object_r:named_conf_t:s0
/var/named/chroot/var/named/slaves(/.*)?           all files          system_u:object_r:named_cache_t:s0
/var/named/chroot/var/run/dbus(/.*)?               all files          system_u:object_r:system_dbusd_var_run_t:s0
/var/named/chroot/var/run/named.*                  all files          system_u:object_r:named_var_run_t:s0
/var/named/chroot/var/tmp(/.*)?                    all files          system_u:object_r:named_cache_t:s0
/var/named/chroot_sdb/dev                          directory          system_u:object_r:device_t:s0
/var/named/chroot_sdb/dev/null                     character device   system_u:object_r:null_device_t:s0
/var/named/chroot_sdb/dev/random                   character device   system_u:object_r:random_device_t:s0
/var/named/chroot_sdb/dev/urandom                  character device   system_u:object_r:urandom_device_t:s0
/var/named/chroot_sdb/dev/zero                     character device   system_u:object_r:zero_device_t:s0
/var/named/data(/.*)?                              all files          system_u:object_r:named_cache_t:s0
/var/named/dynamic(/.*)?                           all files          system_u:object_r:named_cache_t:s0
/var/named/named\.ca                               regular file       system_u:object_r:named_conf_t:s0
/var/named/slaves(/.*)?                            all files          system_u:object_r:named_cache_t:s0
/var/run/bind(/.*)?                                all files          system_u:object_r:named_var_run_t:s0
/var/run/ecblp0                                    named pipe         system_u:object_r:cupsd_var_run_t:s0
/var/run/initctl                                   named pipe         system_u:object_r:initctl_t:s0
/var/run/named(/.*)?                               all files          system_u:object_r:named_var_run_t:s0
/var/run/ndc                                       socket             system_u:object_r:named_var_run_t:s0
/var/run/systemd/initctl/fifo                      named pipe         system_u:object_r:initctl_t:s0
/var/run/unbound(/.*)?                             all files          system_u:object_r:named_var_run_t:s0
/var/named/chroot/usr/lib64 = /usr/lib
/var/named/chroot/lib64 = /usr/lib
/var/named/chroot/var = /var
```

Изменим тип контекста безопасности для каталога /etc/named: `sudo chcon -R -t named_zone_t /etc/named`
```
[root@ns01 ~]# sudo chcon -R -t named_zone_t /etc/named
[root@ns01 ~]# ls -laZ /etc/named
total 28
drw-rwx---.  3 root named system_u:object_r:named_zone_t:s0      121 Mar 16 11:07 .
drwxr-xr-x. 85 root root  system_u:object_r:etc_t:s0            8192 Mar 16 11:07 ..
drw-rwx---.  2 root named unconfined_u:object_r:named_zone_t:s0   56 Mar 16 11:07 dynamic
-rw-rw----.  1 root named system_u:object_r:named_zone_t:s0      784 Mar 16 11:07 named.50.168.192.rev
-rw-rw----.  1 root named system_u:object_r:named_zone_t:s0      610 Mar 16 11:07 named.dns.lab
-rw-rw----.  1 root named system_u:object_r:named_zone_t:s0      609 Mar 16 11:07 named.dns.lab.view1
-rw-rw----.  1 root named system_u:object_r:named_zone_t:s0      657 Mar 16 11:07 named.newdns.lab
```

Попробуем снова внести изменения с клиента: 
```
[root@client ~]# nsupdate -k /etc/named.zonetransfer.key
> server 192.168.50.10
> zone ddns.lab
> update add www.ddns.lab. 60 A 192.168.50.15
> send
> quit
```
[screen02](screen02.PNG)

```
[root@client ~]# dig www.ddns.lab

; <<>> DiG 9.16.23-RH <<>> www.ddns.lab
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 13844
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: 9fe91a98c22b75f10100000067d6b7781af389541f0b5f7d (good)
;; QUESTION SECTION:
;www.ddns.lab.                  IN      A

;; ANSWER SECTION:
www.ddns.lab.           60      IN      A       192.168.50.15

;; Query time: 3 msec
;; SERVER: 192.168.50.10#53(192.168.50.10)
;; WHEN: Sun Mar 16 11:35:20 UTC 2025
;; MSG SIZE  rcvd: 85
```
Видим, что изменения применились
Важно, что мы не добавили новые правила в политику для назначения этого контекста в каталоге. Значит, что при перемаркировке файлов контекст вернётся на тот, который прописан в файле политики.
Для того, чтобы вернуть правила обратно, можно ввести команду: `restorecon -v -R /etc/named`

