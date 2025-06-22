# Dynamic Web (Динамический сайт)

## Задача:
Развернуть стенд nginx + ~~php-fpm (wordpress)~~ + python (django) + js(node.js) с деплоем через docker-compose.

## Выполнение:
1. Развернем стенд, используя [Vagrantfile](Vagrantfile):
```
vagrant up
```
<details>
  <summary>Результат выполнения команды</summary>

```
user@user-P43E:~/Документы/dynamicweb$ vagrant up
==> vagrant: A new version of Vagrant is available: 2.4.7 (installed version: 2.4.6)!
==> vagrant: To upgrade visit: https://www.vagrantup.com/downloads.html

Bringing machine 'DynamicWeb' up with 'virtualbox' provider...
==> DynamicWeb: Box 'bento/ubuntu-20.04' could not be found. Attempting to find and install...
    DynamicWeb: Box Provider: virtualbox
    DynamicWeb: Box Version: >= 0
==> DynamicWeb: Loading metadata for box 'bento/ubuntu-20.04'
    DynamicWeb: URL: https://vagrantcloud.com/api/v2/vagrant/bento/ubuntu-20.04
==> DynamicWeb: Adding box 'bento/ubuntu-20.04' (v202407.23.0) for provider: virtualbox (amd64)
    DynamicWeb: Downloading: https://vagrantcloud.com/bento/boxes/ubuntu-20.04/versions/202407.23.0/providers/virtualbox/amd64/vagrant.box
==> DynamicWeb: Successfully added box 'bento/ubuntu-20.04' (v202407.23.0) for 'virtualbox (amd64)'!
==> DynamicWeb: Importing base box 'bento/ubuntu-20.04'...
==> DynamicWeb: Matching MAC address for NAT networking...
==> DynamicWeb: Checking if box 'bento/ubuntu-20.04' version '202407.23.0' is up to date...
==> DynamicWeb: Setting the name of the VM: dynamicweb_DynamicWeb_1750607299696_26213
Vagrant is currently configured to create VirtualBox synced folders with
the `SharedFoldersEnableSymlinksCreate` option enabled. If the Vagrant
guest is not trusted, you may want to disable this option. For more
information on this option, please refer to the VirtualBox manual:

  https://www.virtualbox.org/manual/ch04.html#sharedfolders

This option can be disabled globally with an environment variable:

  VAGRANT_DISABLE_VBOXSYMLINKCREATE=1

or on a per folder basis within the Vagrantfile:

  config.vm.synced_folder '/host/path', '/guest/path', SharedFoldersEnableSymlinksCreate: false
==> DynamicWeb: Clearing any previously set network interfaces...
==> DynamicWeb: Preparing network interfaces based on configuration...
    DynamicWeb: Adapter 1: nat
==> DynamicWeb: Forwarding ports...
    DynamicWeb: 8081 (guest) => 8081 (host) (adapter 1)
    DynamicWeb: 8082 (guest) => 8082 (host) (adapter 1)
    DynamicWeb: 8083 (guest) => 8083 (host) (adapter 1)
    DynamicWeb: 22 (guest) => 2222 (host) (adapter 1)
==> DynamicWeb: Running 'pre-boot' VM customizations...
==> DynamicWeb: Booting VM...
==> DynamicWeb: Waiting for machine to boot. This may take a few minutes...
    DynamicWeb: SSH address: 127.0.0.1:2222
    DynamicWeb: SSH username: vagrant
    DynamicWeb: SSH auth method: private key
    DynamicWeb: 
    DynamicWeb: Vagrant insecure key detected. Vagrant will automatically replace
    DynamicWeb: this with a newly generated keypair for better security.
    DynamicWeb: 
    DynamicWeb: Inserting generated public key within guest...
    DynamicWeb: Removing insecure key from the guest if it's present...
    DynamicWeb: Key inserted! Disconnecting and reconnecting using new SSH key...
==> DynamicWeb: Machine booted and ready!
==> DynamicWeb: Checking for guest additions in VM...
==> DynamicWeb: Setting hostname...
==> DynamicWeb: Mounting shared folders...
    DynamicWeb: /home/user/Документы/dynamicweb => /vagrant
==> DynamicWeb: Running provisioner: ansible...
    DynamicWeb: Running ansible-playbook...

PLAY [DynamicWeb] **************************************************************

TASK [Install docker packages] *************************************************
[WARNING]: Platform linux on host DynamicWeb is using the discovered Python
interpreter at /usr/bin/python3.8, but future installation of another Python
interpreter could change the meaning of that path. See
https://docs.ansible.com/ansible-
core/2.18/reference_appendices/interpreter_discovery.html for more information.
changed: [DynamicWeb]

TASK [Add Docker's official GPG key] *******************************************
changed: [DynamicWeb]

TASK [Verify that we have the key with the fingerprint] ************************
ok: [DynamicWeb]

TASK [Set up the stable repository] ********************************************
changed: [DynamicWeb]

TASK [Update apt cache] ********************************************************
ok: [DynamicWeb]

TASK [Install docker-ce] *******************************************************
changed: [DynamicWeb]

TASK [Add vagrant user to docker group] ****************************************
changed: [DynamicWeb]

TASK [Install docker-compose] **************************************************
changed: [DynamicWeb]

TASK [Copy project to remote host] *********************************************
changed: [DynamicWeb]

TASK [Reset SSH connection] ****************************************************

TASK [Run Docker Compose] ******************************************************
changed: [DynamicWeb]

PLAY RECAP *********************************************************************
DynamicWeb                 : ok=10   changed=8    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```
</details>

2. Проверка:
- http://localhost:8081/  

![screen01](screen01.PNG)  

- http://localhost:8081/
![screen02](screen02.PNG)

- http://localhost:8083/  

![screen03](screen03.PNG) 

При проверке работоспособности Wordpress возникла ошибка установки соединения с базой данных. Поверяем статус контейнеров:  
```
vagrant@DynamicWeb:~/project$ sudo docker-compose ps
  Name                 Command                   State                                                                      Ports
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
app         gunicorn --workers=2 --bin ...   Up
database    docker-entrypoint.sh --def ...   Restarting
nginx       nginx -g daemon off;             Up               80/tcp, 0.0.0.0:8081->8081/tcp,:::8081->8081/tcp, 0.0.0.0:8082->8082/tcp,:::8082->8082/tcp,
                                                              0.0.0.0:8083->8083/tcp,:::8083->8083/tcp
node        docker-entrypoint.sh node  ...   Up
wordpress   docker-entrypoint.sh php-fpm     Up (unhealthy)   9000/tcp
```
Видим, что database в Restarting. Смотрим логи:  

```
vagrant@DynamicWeb:~/project$ docker-compose logs database
Attaching to database
database     | 2025-06-22 18:27:42+00:00 [Note] [Entrypoint]: Entrypoint script for MySQL Server 8.0.42-1.el9 started.
database     | 2025-06-22 18:27:42+00:00 [Note] [Entrypoint]: Switching to dedicated user 'mysql'
database     | 2025-06-22 18:27:42+00:00 [Note] [Entrypoint]: Entrypoint script for MySQL Server 8.0.42-1.el9 started.
database     | 2025-06-22 18:27:43+00:00 [Note] [Entrypoint]: Initializing database files
database     | 2025-06-22T18:27:43.060538Z 0 [Warning] [MY-011068] [Server] The syntax '--skip-host-cache' is deprecated and will be removed in a future release. Please use SET GLOBAL host_cache_size=0 instead.
database     | 2025-06-22T18:27:43.060674Z 0 [Warning] [MY-010918] [Server] 'default_authentication_plugin' is deprecated and will be removed in a future release. Please use authentication_policy instead.
database     | 2025-06-22T18:27:43.060698Z 0 [System] [MY-013169] [Server] /usr/sbin/mysqld (mysqld 8.0.42) initializing of server in progress as process 80
database     | 2025-06-22T18:27:43.062846Z 0 [ERROR] [MY-010457] [Server] --initialize specified but the data directory has files in it. Aborting.
database     | 2025-06-22T18:27:43.062856Z 0 [ERROR] [MY-013236] [Server] The designated data directory /var/lib/mysql/ is unusable. You can remove all files that the server added to it.     
database     | 2025-06-22T18:27:43.079654Z 0 [ERROR] [MY-010119] [Server] Aborting
database     | 2025-06-22T18:27:43.079827Z 0 [System] [MY-010910] [Server] /usr/sbin/mysqld: Shutdown complete (mysqld 8.0.42)  MySQL Community Server - GPL.
database     | 2025-06-22 18:27:44+00:00 [Note] [Entrypoint]: Entrypoint script for MySQL Server 8.0.42-1.el9 started.
database     | 2025-06-22 18:27:44+00:00 [Note] [Entrypoint]: Switching to dedicated user 'mysql'
database     | 2025-06-22 18:27:44+00:00 [Note] [Entrypoint]: Entrypoint script for MySQL Server 8.0.42-1.el9 started.
database     | 2025-06-22 18:27:44+00:00 [Note] [Entrypoint]: Initializing database files
database     | 2025-06-22T18:27:44.833197Z 0 [Warning] [MY-011068] [Server] The syntax '--skip-host-cache' is deprecated and will be removed in a future release. Please use SET GLOBAL host_cache_size=0 instead.
database     | 2025-06-22T18:27:44.833425Z 0 [Warning] [MY-010918] [Server] 'default_authentication_plugin' is deprecated and will be removed in a future release. Please use authentication_policy instead.
database     | 2025-06-22T18:27:44.833468Z 0 [System] [MY-013169] [Server] /usr/sbin/mysqld (mysqld 8.0.42) initializing of server in progress as process 79
database     | 2025-06-22T18:27:44.837784Z 0 [ERROR] [MY-010457] [Server] --initialize specified but the data directory has files in it. Aborting.
database     | 2025-06-22T18:27:44.837799Z 0 [ERROR] [MY-013236] [Server] The designated data directory /var/lib/mysql/ is unusable. You can remove all files that the server added to it.     
database     | 2025-06-22T18:27:44.838901Z 0 [ERROR] [MY-010119] [Server] Aborting
database     | 2025-06-22T18:27:44.839204Z 0 [System] [MY-010910] [Server] /usr/sbin/mysqld: Shutdown complete (mysqld 8.0.42)  MySQL Community Server - GPL.
database     | 2025-06-22 18:27:45+00:00 [Note] [Entrypoint]: Entrypoint script for MySQL Server 8.0.42-1.el9 started.
database     | 2025-06-22 18:27:45+00:00 [Note] [Entrypoint]: Switching to dedicated user 'mysql'
database     | 2025-06-22 18:27:46+00:00 [Note] [Entrypoint]: Entrypoint script for MySQL Server 8.0.42-1.el9 started.
database     | 2025-06-22 18:27:46+00:00 [Note] [Entrypoint]: Initializing database files
database     | 2025-06-22T18:27:46.487335Z 0 [Warning] [MY-011068] [Server] The syntax '--skip-host-cache' is deprecated and will be removed in a future release. Please use SET GLOBAL host_cache_size=0 instead.
database     | 2025-06-22T18:27:46.487583Z 0 [Warning] [MY-010918] [Server] 'default_authentication_plugin' is deprecated and will be removed in a future release. Please use authentication_policy instead.
database     | 2025-06-22T18:27:46.487630Z 0 [System] [MY-013169] [Server] /usr/sbin/mysqld (mysqld 8.0.42) initializing of server in progress as process 79
database     | 2025-06-22T18:27:46.491903Z 0 [ERROR] [MY-010457] [Server] --initialize specified but the data directory has files in it. Aborting.
database     | 2025-06-22T18:27:46.491949Z 0 [ERROR] [MY-013236] [Server] The designated data directory /var/lib/mysql/ is unusable. You can remove all files that the server added to it.     
database     | 2025-06-22T18:27:46.492794Z 0 [ERROR] [MY-010119] [Server] Aborting
```
Самостоятельно устранить ошибку не удалось (((