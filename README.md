Script for migrate all User on WHM/Cpanel to another WHM/Cpanel server. Using `sshpass` for not using password during running the script

# How to run this script

### Install `sshpass`

install `sshpass` first because the script is using `sshpass` or it can be error.

**Ubuntu/Debian**

````bash
sudo apt install sshpass
```

**CentOS, RHEL, And Fedora**

```bash
sudo yum install sshpass
```

**Arch Linux And Manjaro**
```bash
sudo pacman -S sshpass
```

**OpenSUSE**
```bash
sudo emerge net-misc/sshpass
```



### Create file.sh

create script sh using ur text editor example.

**Using VIM**

```bash
vim migrate.sh

````

**Using NANO**

```bash
nano migrate.sh
```
