# this script used to migrate mail 1 domain to another
#!/bin/bash

# 🔧 Variabel Konfigurasi
OLDUSER="user"           # User lama di WHM lama
NEWUSER="user"           # User cPanel di WHM baru
DOMAIN="destination_domain"                # Domain yang mau dipindah
DEST_HOST="IP"        # IP WHM baru
DEST_USER="root"                  # SSH user server baru
SSH_PORT="22"                     # SSH port server baru
SSH_PASS="Password"       # Password root server baru

# 📦 Path
OLD_MAIL_PATH="/home/$OLDUSER/mail/$DOMAIN"
OLD_ETC_PATH="/home/$OLDUSER/etc/$DOMAIN"
NEW_MAIL_PATH="/home/$NEWUSER/mail/$DOMAIN"
NEW_ETC_PATH="/home/$NEWUSER/etc/$DOMAIN"

# 🛡️ Backup dulu (optional, biar aman)
echo "🔄 Membackup folder lama..."
tar czf /root/${DOMAIN}_mail_backup.tar.gz "$OLD_MAIL_PATH" "$OLD_ETC_PATH"

# 🚀 Transfer folder mail
echo "🚚 Transfer MAIL folder..."
sshpass -p "$SSH_PASS" rsync -avz -e "ssh -p $SSH_PORT" "$OLD_MAIL_PATH/" "$DEST_USER@$DEST_HOST:$NEW_MAIL_PATH/"

# 🚚 Transfer folder etc (user/pass email)
echo "🚚 Transfer ETC folder..."
sshpass -p "$SSH_PASS" rsync -avz -e "ssh -p $SSH_PORT" "$OLD_ETC_PATH/" "$DEST_USER@$DEST_HOST:$NEW_ETC_PATH/"

# 🛠️ Set owner biar cPanel bisa baca
echo "🛠️ Set permission di server baru..."
sshpass -p "$SSH_PASS" ssh -p "$SSH_PORT" "$DEST_USER@$DEST_HOST" <<EOF
chown -R $NEWUSER:$NEWUSER /home/$NEWUSER/mail/$DOMAIN
chown -R $NEWUSER:$NEWUSER /home/$NEWUSER/etc/$DOMAIN
/scripts/restartsrv_exim
/scripts/restartsrv_dovecot
EOF

echo "✅ Selesai migrasi email untuk domain $DOMAIN!"
