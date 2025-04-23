# this script is used to migrate DNS zone files from one server to another
#!/bin/bash

# ====== Konfigurasi ======
DEST_HOST="IP"       # IP server tujuan (contoh: 192.168.1.1)
DEST_USER="root"     # User SSH di server tujuan (biasanya root)
SSH_PASS="Password"  # Password SSH untuk user di server tujuan
SSH_PORT="22"        # Port SSH server tujuan (default: 22)
ZONE_PATH="/var/named" # Path direktori file zone di server asal
OLD_IP="ip"          # IP lama yang akan diganti (contoh: 192.168.1.100)
NEW_IP="ip"          # IP baru yang akan menggantikan IP lama (contoh: 192.168.1.200)
DOMAIN_LIST="/root/domains.txt" # File yang berisi daftar domain untuk dimigrasi
SUCCESS_LOG="/root/spf_migrate_success.log" # File log untuk domain yang berhasil
FAILED_LOG="/root/spf_migrate_failed.log"   # File log untuk domain yang gagal
# ==========================

# Clear log sebelumnya
> "$SUCCESS_LOG"
> "$FAILED_LOG"

# Install sshpass kalau belum ada
if ! command -v sshpass &>/dev/null; then
    echo "🛠️ Menginstal sshpass..."
    yum install -y sshpass || apt install -y sshpass
fi

# Fungsi replace khusus SPF record
fix_spf_record() {
    local file="$1"
    # Cari semua baris SPF
    while IFS= read -r line; do
        if [[ "$line" == *"v=spf1"* ]]; then
            # Hanya ganti bagian ip4:... ke IP baru
            fixed=$(echo "$line" | sed -E "s/ip4:[0-9\.]+/ip4:${NEW_IP}/g")
            # Replace line di file
            sed -i "s|$line|$fixed|" "$file"
        fi
    done < "$file"
}

# Fungsi migrasi domain
migrate_domain() {
    local DOMAIN=$1
    local ZONE_FILE="$ZONE_PATH/${DOMAIN}.db"
    
    echo "🔍 Memproses zone: $DOMAIN"

    if [[ ! -f "$ZONE_FILE" ]]; then
        echo "❌ [$DOMAIN] Zone file tidak ditemukan." | tee -a "$FAILED_LOG"
        return
    fi

    # Copy ke temp file
    TMP_FILE="/tmp/${DOMAIN}.db"
    cp "$ZONE_FILE" "$TMP_FILE"

    # Ganti semua A record IP
    sed -i "s/$OLD_IP/$NEW_IP/g" "$TMP_FILE"

    # Khusus untuk SPF record
    fix_spf_record "$TMP_FILE"

    # Kirim file zone (overwrite)
    sshpass -p "$SSH_PASS" rsync -avz --delete -e "ssh -p $SSH_PORT" "$TMP_FILE" "$DEST_USER@$DEST_HOST:/var/named/${DOMAIN}.db"
    if [[ $? -ne 0 ]]; then
        echo "❌ [$DOMAIN] Gagal mengirim file zone." | tee -a "$FAILED_LOG"
        rm -f "$TMP_FILE"
        return
    fi

    # Pastikan konfigurasi zone ada di named.conf (kalau belum ada)
    sshpass -p "$SSH_PASS" ssh -p "$SSH_PORT" "$DEST_USER@$DEST_HOST" "bash -s" <<EOF
if ! grep -q "zone \"$DOMAIN\"" /etc/named.conf; then
    cp /etc/named.conf /etc/named.conf.bak_$(date +%F_%T)
    echo "// Zone added for $DOMAIN" >> /etc/named.conf
    cat <<ZONE >> /etc/named.conf

zone "$DOMAIN" {
    type master;
    file "/var/named/$DOMAIN.db";
};
ZONE
fi
chown named:named /var/named/$DOMAIN.db
chmod 640 /var/named/$DOMAIN.db
EOF

    if [[ $? -eq 0 ]]; then
        echo "✅ [$DOMAIN] Berhasil diupload dan dikonfigurasi." | tee -a "$SUCCESS_LOG"
    else
        echo "❌ [$DOMAIN] Gagal konfigurasi zone di server tujuan." | tee -a "$FAILED_LOG"
    fi

    rm -f "$TMP_FILE"
}

# ==============================
# Mulai migrasi hanya dari domain list
# ==============================

if [[ ! -f "$DOMAIN_LIST" ]]; then
    echo "❌ Domain list $DOMAIN_LIST tidak ditemukan!"
    exit 1
fi

echo "📜 Migrasi domain dari list $DOMAIN_LIST"
while read -r DOMAIN; do
    [[ -z "$DOMAIN" ]] && continue  # Skip baris kosong
    migrate_domain "$DOMAIN"
done < "$DOMAIN_LIST"

# Restart named di server tujuan
sshpass -p "$SSH_PASS" ssh -p "$SSH_PORT" "$DEST_USER@$DEST_HOST" "systemctl restart named"
echo "🔄 DNS server (named) di-restart di server tujuan."

echo "📄 Log sukses: $SUCCESS_LOG"
echo "📄 Log gagal: $FAILED_LOG"
