## Настройка рабочего места. Обновление ядра
1. Устанавливаем Ubuntu 22.04.4 LTS на виртуальную машину Oracle VM VirtualBox
2. После установки в терминале проверяем версию операционной системы:
```bash
lsb_release -a
```
```bash
No LSB modules are available.
Distributor ID: Ubuntu
Description:    Ubuntu 22.04.4 LTS
Release:        22.04
Codename:       jammy
```
3. Проверяем версию ядра операционной системы:
```bash
uname -r
```

```bash
5.15.0-94-generic
```
4. Обновляем систему
```bash
sudo apt update
sudo apt upgrade
```
5. После обновления проверяем версию операционной системы и ядра
```bash
lsb_release -a
```
```bash
No LSB modules are available.
Distributor ID: Ubuntu
Description:    Ubuntu 22.04.5 LTS
Release:        22.04
Codename:       jammy
```

```bash
uname -r
```

```bash
5.15.0-130-generic
```
6. Добавляем PPA (Personal Package Archive) для установки инструмента Mainline.
```bash
sudo add-apt-repository ppa:cappelikan/ppa
```
7. Обновляем списки пакетов и установили mainline
```bash
sudo apt update
sudo apt install mainline
```
8. Проверяем доступные версии ядра и устанавливаем последню версию.
```bash
mainline check
sudo mainline install-latest
```
9. Перезагружаем операционную систему
```bash
reboot
```
10. Проверяем версию ядра операционной системы:
```bash
uname -r
```

```bash
6.12.3-061203-generic
```

