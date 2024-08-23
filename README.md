Script for migrate all User on WHM/Cpanel to another WHM/Cpanel server. Using `sshpass` for not using password during running the script and using `rsync` for transfer backup file User instead of `scp` because more stable

# How to run this script

### Install `sshpass`

install `sshpass` first because the script is using `sshpass` or it can be error during running.

**Ubuntu/Debian**

```bash
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

## Create file.sh

create `migrate.sh` using your text editor example.

**Using VIM**

```bash
vim migrate.sh

```

**Using NANO**

```bash
nano migrate.sh
```
