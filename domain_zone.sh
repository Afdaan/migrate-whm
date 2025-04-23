#!/bin/bash

# Konfigurasi
DEST_HOST="IP"       # Ganti IP server tujuan
DEST_USER="root"
SSH_PASS="Password"
SSH_PORT="22"
ZONE_PATH="/var/named"

# File log
SUCCESS_LOG="/root/dns_migrate_success.log"
FAILED_LOG="/root/dns_migrate_failed.log"

# Clear log sebelumnya
> "$SUCCESS_LOG"
> "$FAILED_LOG"

# Install sshpass jika belum
if ! command -v sshpass &>/dev/null; then
    echo "🛠️ Menginstal sshpass..."
    yum install -y sshpass || apt install -y sshpass
fi

# Mulai migrasi
for ZONE_FILE in $ZONE_PATH/*.db; do
    DOMAIN=$(basename "$ZONE_FILE" .db)
    echo "🔍 Mengecek zone: $DOMAIN"

    # Cek apakah file sudah ada di tujuan
    sshpass -p "$SSH_PASS" ssh -p "$SSH_PORT" "$DEST_USER@$DEST_HOST" \
        "test -f /var/named/$DOMAIN.db"
    
    if [[ $? -eq 0 ]]; then
        echo "⚠️  [$DOMAIN] Sudah ada di tujuan. Lewatkan." | tee -a "$FAILED_LOG"
        continue
    fi

    # Kirim file zone
    sshpass -p "$SSH_PASS" rsync -avz -e "ssh -p $SSH_PORT" "$ZONE_FILE" "$DEST_USER@$DEST_HOST:/var/named/"
    if [[ $? -ne 0 ]]; then
        echo "❌ [$DOMAIN] Gagal mengirim file zone." | tee -a "$FAILED_LOG"
        continue
    fi

    # Tambahkan konfigurasi di server tujuan
    sshpass -p "$SSH_PASS" ssh -p "$SSH_PORT" "$DEST_USER@$DEST_HOST" "bash -s" <<EOF
if ! grep -q "$DOMAIN" /etc/named.conf; then
cat <<ZONE >> /etc/named.conf

zone "$DOMAIN" {
    type master;
    file "/var/named/$DOMAIN.db";
};
ZONE
fi
chown named:named /var/named/$DOMAIN.db
EOF

    if [[ $? -eq 0 ]]; then
        echo "✅ [$DOMAIN] Berhasil dimigrasi dan dikonfigurasi." | tee -a "$SUCCESS_LOG"
    else
        echo "❌ [$DOMAIN] Gagal konfigurasi zone di server tujuan." | tee -a "$FAILED_LOG"
    fi

    echo ""
done

# Restart named di server tujuan
sshpass -p "$SSH_PASS" ssh -p "$SSH_PORT" "$DEST_USER@$DEST_HOST" "systemctl restart named"
echo "🔄 DNS server (named) di-restart di server tujuan."

echo "📄 Log sukses: $SUCCESS_LOG"
echo "📄 Log gagal: $FAILED_LOG"
