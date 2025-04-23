#!/bin/bash

# Konfigurasi
DST_WHM_IP="IP" # IP server tujuan
SSH_PORT=22                  # Port SSH server tujuan
DST_USER="root"              # User untuk server tujuan
DST_PASS="Password"   # Password untuk server tujuan
BACKUP_DIR="/backup"         # Direktori penyimpanan backup di server sumber

# Pastikan sshpass terinstal
if ! command -v sshpass &>/dev/null; then
  echo "❌ sshpass tidak ditemukan! Instal terlebih dahulu dengan:"
  echo "   apt install sshpass -y   # Untuk Debian/Ubuntu"
  echo "   yum install sshpass -y   # Untuk CentOS/RHEL"
  exit 1
fi

# Pastikan direktori backup ada
mkdir -p "$BACKUP_DIR"

# Ambil daftar akun dari server sumber
echo "🔹 Mengambil daftar akun dari server sumber..."
USERS=$(ls /var/cpanel/users)

# Loop untuk backup, transfer, dan restore akun
for USER in $USERS; do
  BACKUP_FILE="$BACKUP_DIR/cpmove-${USER}.tar.gz"

  echo "🔹 Memproses akun: $USER"

  # Cek apakah backup sudah ada
  if [[ -f "$BACKUP_FILE" ]]; then
    echo "✅ Backup sudah ada untuk $USER, melewati proses backup."
  else
    # Backup akun menggunakan /scripts/pkgacct dengan --skipmail
    echo "📦 Membuat backup akun $USER menggunakan /scripts/pkgacct --skipmail..."
    /scripts/pkgacct --skipbwdata --skipmail "$USER" "$BACKUP_DIR" || {
      echo "❌ Gagal membuat backup untuk $USER"
      continue
    }
  fi

  # Pastikan file backup ada sebelum lanjut
  if [[ ! -f "$BACKUP_FILE" ]]; then
    echo "❌ File backup tidak ditemukan untuk $USER! Melewati proses migrasi."
    continue
  fi

  # Cek apakah file sudah ada di server tujuan
  if sshpass -p "$DST_PASS" ssh -p "$SSH_PORT" "$DST_USER@$DST_WHM_IP" "[ -f $BACKUP_DIR/cpmove-${USER}.tar.gz ]"; then
    echo "✅ File backup sudah ada di server tujuan untuk $USER, melewati proses transfer."
  else
    # Transfer file backup ke server tujuan
    echo "🚀 Mentransfer backup ke server tujuan..."
    sshpass -p "$DST_PASS" rsync -avz -e "ssh -p $SSH_PORT" "$BACKUP_FILE" "$DST_USER@$DST_WHM_IP:$BACKUP_DIR/" || {
      echo "❌ Gagal mentransfer backup untuk $USER"
      continue
    }
  fi

  # Cek apakah akun sudah direstore di server tujuan
  if sshpass -p "$DST_PASS" ssh -p "$SSH_PORT" "$DST_USER@$DST_WHM_IP" "whmapi1 listaccts | grep -w $USER"; then
    echo "✅ Akun $USER sudah ada di server tujuan, melewati proses restore."
  else
    # Restore akun di server tujuan dengan nama file lengkap
    echo "🔄 Merestorasi akun di server tujuan..."
    sshpass -p "$DST_PASS" ssh -p $SSH_PORT "$DST_USER@$DST_WHM_IP" "/scripts/restorepkg $BACKUP_DIR/cpmove-${USER}.tar.gz" || {
      echo "❌ Gagal me-restore akun untuk $USER"
      continue
    }
  fi

  echo "✅ Akun $USER selesai dimigrasikan (tanpa data email, tetapi tetap menyertakan konfigurasi email)."
done

echo "🎉 Semua akun selesai dimigrasikan."