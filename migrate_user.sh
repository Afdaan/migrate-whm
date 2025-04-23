# this script is used to migrate user data from one WHM to another
#!/bin/bash

# Konfigurasi
DST_WHM_IP="IP"               # IP server tujuan
SSH_PORT=22                 # Port SSH server tujuan
DST_USER="root"             # User untuk server tujuan
DST_PASS="Passowrd"              # Password untuk server tujuan
BACKUP_DIR="/backup"        # Direktori penyimpanan backup di server sumber
MIGRATE_USER="user"    # Ganti dengan username yang ingin dimigrasikan

# Pastikan sshpass terinstal
if ! command -v sshpass &>/dev/null; then
  echo "❌ sshpass tidak ditemukan! Instal terlebih dahulu dengan:"
  echo "   apt install sshpass -y   # Untuk Debian/Ubuntu"
  echo "   yum install sshpass -y   # Untuk CentOS/RHEL"
  exit 1
fi

# Pastikan direktori backup ada
mkdir -p "$BACKUP_DIR"

# Backup akun menggunakan /scripts/pkgacct dengan --skipmail
BACKUP_FILE="$BACKUP_DIR/cpmove-${MIGRATE_USER}.tar.gz"

echo "🔹 Memproses akun: $MIGRATE_USER"

# Cek apakah backup sudah ada
if [[ -f "$BACKUP_FILE" ]]; then
  echo "✅ Backup sudah ada untuk $MIGRATE_USER, melewati proses backup."
else
  echo "📦 Membuat backup akun $MIGRATE_USER menggunakan /scripts/pkgacct --skipmail..."
  /scripts/pkgacct --skipbwdata --skipmail "$MIGRATE_USER" "$BACKUP_DIR" || {
    echo "❌ Gagal membuat backup untuk $MIGRATE_USER"
    exit 1
  }
fi

# Pastikan file backup ada sebelum lanjut
if [[ ! -f "$BACKUP_FILE" ]]; then
  echo "❌ File backup tidak ditemukan untuk $MIGRATE_USER! Proses migrasi dihentikan."
  exit 1
fi

# Cek apakah file sudah ada di server tujuan
if sshpass -p "$DST_PASS" ssh -p "$SSH_PORT" "$DST_USER@$DST_WHM_IP" "[ -f $BACKUP_DIR/cpmove-${MIGRATE_USER}.tar.gz ]"; then
  echo "✅ File backup sudah ada di server tujuan untuk $MIGRATE_USER, melewati proses transfer."
else
  # Transfer file backup ke server tujuan
  echo "🚀 Mentransfer backup ke server tujuan..."
  sshpass -p "$DST_PASS" rsync -avz -e "ssh -p $SSH_PORT" "$BACKUP_FILE" "$DST_USER@$DST_WHM_IP:$BACKUP_DIR/" || {
    echo "❌ Gagal mentransfer backup untuk $MIGRATE_USER"
    exit 1
  }
fi

# Cek apakah akun sudah direstore di server tujuan
if sshpass -p "$DST_PASS" ssh -p "$SSH_PORT" "$DST_USER@$DST_WHM_IP" "whmapi1 listaccts | grep -w $MIGRATE_USER"; then
  echo "✅ Akun $MIGRATE_USER sudah ada di server tujuan, melewati proses restore."
else
  # Restore akun di server tujuan dengan nama file lengkap
  echo "🔄 Merestorasi akun di server tujuan..."
  sshpass -p "$DST_PASS" ssh -p $SSH_PORT "$DST_USER@$DST_WHM_IP" "/scripts/restorepkg $BACKUP_DIR/cpmove-${MIGRATE_USER}.tar.gz" || {
    echo "❌ Gagal me-restore akun untuk $MIGRATE_USER"
    exit 1
  }
fi

echo "✅ Akun $MIGRATE_USER selesai dimigrasikan (tanpa data email, tetapi tetap menyertakan konfigurasi email)."
echo "🎉 Migrasi selesai."