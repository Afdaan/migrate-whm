#!/bin/bash

# Variabel
source_whm_ip="123.XXX"                    # IP server sumber
destination_whm_ip="123.XXX"              # IP server tujuan
ssh_port=22                                   # Port SSH yang digunakan
source_whm_user="Username"                          # Username untuk server sumber
source_whm_pass="Password"               # Password untuk server sumber
destination_whm_user="username"                     # Username untuk server tujuan
destination_whm_pass="Password"     # Password untuk server tujuan

# Ambil daftar semua pengguna dari server sumber
users=$(sshpass -p "${source_whm_pass}" ssh -p ${ssh_port} ${source_whm_user}@${source_whm_ip} "ls /var/cpanel/users")

# Loop untuk setiap pengguna dan lakukan backup, transfer, dan restore
for user in $users; do
    echo "Memigrasikan akun: $user"

    #  Backup akun menggunakan pkgacct
    sshpass -p "${source_whm_pass}" ssh -p ${ssh_port} ${source_whm_user}@${source_whm_ip} "/scripts/pkgacct $user" || { echo "Gagal membuat backup untuk $user"; exit 1; }

    # Transfer file backup ke server tujuan menggunakan rsync
    sshpass -p "${source_whm_pass}" rsync -avz -e "ssh -p ${ssh_port}" ${source_whm_user}@${source_whm_ip}:/home/cpmove-${user}.tar.gz /tmp/ || { echo "Gagal mentransfer file backup untuk $user"; exit 1; }
    sshpass -p "${destination_whm_pass}" rsync -avz -e "ssh -p ${ssh_port}" /tmp/cpmove-${user}.tar.gz ${destination_whm_user}@${destination_whm_ip}:/home || { echo "Gagal mentransfer file backup ke server tujuan untuk $user"; exit 1; }

    # Restore akun di server tujuan
    sshpass -p "${destination_whm_pass}" ssh -p ${ssh_port} ${destination_whm_user}@${destination_whm_ip} "/scripts/restorepkg /home/cpmove-${user}.tar.gz" || { echo "Gagal me-restore akun untuk $user"; exit 1; }
    
    echo "Akun $user selesai dimigrasikan."
done

echo "Semua akun selesai dimigrasikan."
