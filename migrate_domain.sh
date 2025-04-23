# this script is used to migrate domain from one WHM to another WHM
#!/bin/bash

# Konfigurasi
DST_WHM_IP="IP"         # IP server tujuan
SSH_PORT=22                          # Port SSH server tujuan
DST_USER="User_cPanel"                  # User tujuan di server WHM
DST_PASS="Password"             # Password SSH root di server tujuan
BACKUP_DIR="/root/domainlist"        # Tempat nyimpen daftar domain lokal

SUCCESS_LOG="/root/domain-migrated.log"
FAILED_LOG="/root/domain-failed.log"

# Cek sshpass
if ! command -v sshpass &>/dev/null; then
  echo "❌ sshpass belum terinstall."
  exit 1
fi

mkdir -p "$BACKUP_DIR"
> "$SUCCESS_LOG"
> "$FAILED_LOG"

echo "🔍 Mulai scanning domain dari /home..."

for USER in /home/*; do
  [ -d "$USER" ] || continue
  for DIR in "$USER"/public_html/* "$USER"/domains/*; do
    [ -d "$DIR" ] || continue
    DOMAIN=$(basename "$DIR")

    # Validasi format domain
    if [[ "$DOMAIN" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]] && [ "$(ls -A "$DIR" 2>/dev/null)" ]; then
      echo "🌐 Menemukan domain: $DOMAIN"

      # Sync konten domain
      DEST_DIR="/home/$DST_USER/public_html/$DOMAIN"
      echo "🚀 Syncing konten domain $DOMAIN ke $DEST_DIR ..."
      sshpass -p "$DST_PASS" ssh -p $SSH_PORT -o StrictHostKeyChecking=no root@$DST_WHM_IP "mkdir -p $DEST_DIR"
      rsync -avz -e "sshpass -p $DST_PASS ssh -p $SSH_PORT -o StrictHostKeyChecking=no" "$DIR/" root@$DST_WHM_IP:"$DEST_DIR/" &>/dev/null

      if [ $? -eq 0 ]; then
        echo "$DOMAIN" >> "$SUCCESS_LOG"
        echo "✅ Berhasil sync: $DOMAIN"
      else
        echo "$DOMAIN" >> "$FAILED_LOG"
        echo "❌ Gagal sync: $DOMAIN"
      fi
    fi
  done
done

echo ""
echo "🎉 Proses sync selesai!"
echo "📁 Domain berhasil: $SUCCESS_LOG"
echo "📁 Domain gagal:    $FAILED_LOG"
