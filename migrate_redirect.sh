# this script is used to redirect domain from one WHM to another
#!/bin/bash

# Set mode real-run (langsung eksekusi nyata)
MODE="real-run"

# Server tujuan
SERVER_TUJUAN="root@IP"
PASSWORD="Password"  # Ganti dengan password server baru
DIR_TUJUAN="/home/user/public_html/"

# Direktori log
LOG_FILE="/var/log/migrate_domains.log"

# Function untuk menulis log
log() {
    echo "$(date "+%Y-%m-%d %H:%M:%S") - $1" >> $LOG_FILE
}

# Function untuk park domain dan set redirect
park_and_redirect() {
    local domain=$1
    local redirect_url=$2
    
    # Park domain dan set redirect di server baru
    uapi --user=user DomainPark park_domain=$domain
    uapi --user=user Redirects add_redirect=1 domain=$domain destination=$redirect_url

    log "Domain $domain parked and redirect set to $redirect_url"
}

# Function untuk mengecek apakah domain sudah ada redirect di cPanel
check_redirect() {
    local domain=$1
    redirects=$(uapi --user=user Redirects list_redirects)
    
    if [[ "$redirects" == *"$domain"* ]]; then
        log "Redirect found for domain $domain"
        return 0
    else
        log "No redirect found for domain $domain"
        return 1
    fi
}

# Function untuk rsync file ke server baru dengan password
rsync_files() {
    local domain=$1

    # Direktori public_html sesuai dengan user cPanel
    local src_dir="/home/$USER/public_html/$domain/"
    local dest_dir="$SERVER_TUJUAN:$DIR_TUJUAN$domain/"

    # Rsync file ke server baru menggunakan sshpass untuk password
    sshpass -p "$PASSWORD" rsync -az $src_dir $dest_dir
    if [ $? -eq 0 ]; then
        log "Files from $src_dir successfully rsynced to $dest_dir"
    else
        log "Failed to rsync files for $domain"
    fi
}

# Function untuk handle progress bar
progress_bar() {
    local count=$1  # Menyimpan jumlah progress
    echo -n "[Progress]: "
    while (( count > 0 )); do
        echo -n "#"
        sleep 1
        (( count-- ))  # Decrement count dengan benar
    done
    echo ""
}

# Function untuk menjalankan AutoSSL pada domain
run_autossl() {
    local domain=$1
    
    # Jalankan AutoSSL check menggunakan uapi
    uapi --user=user SSL::run_autossl_check
    log "AutoSSL initiated for domain $domain"
}

# Loop untuk semua user cPanel di /home/[username]/public_html/
for user_dir in /home/*/; do
    if [ -d "$user_dir/public_html" ]; then
        for domain in $(ls "$user_dir/public_html"); do
            # Pastikan hanya memproses folder domain yang valid
            if [ -d "$user_dir/public_html/$domain" ] && [[ ! "$domain" =~ ^# ]]; then
                # Cek apakah domain sudah di-redirect melalui cPanel API
                if check_redirect $domain; then
                    redirect_url="http://example.com"  # Ganti dengan URL tujuan sebenarnya

                    # Park domain dan set redirect
                    park_and_redirect $domain $redirect_url

                    # Cek apakah public_html kosong atau hanya berisi redirect
                    if [ ! -d "$user_dir/public_html/$domain" ] || [ "$(ls -A $user_dir/public_html/$domain)" ]; then
                        # Rsync file ke server baru (jika ada file)
                        rsync_files $domain
                    else
                        # Kalau cuma redirect, buat folder kosong di server baru
                        log "Domain $domain has only redirect, creating empty public_html folder."
                    fi

                    # Jalankan AutoSSL
                    run_autossl $domain
                else
                    log "Skipping domain $domain - No redirect"
                fi
            else
                log "Skipping non-domain folder: $domain"
            fi

            # Tampilkan progress bar
            progress_bar 10
        done
    fi
done

# Summary
echo "Migration completed. Check $LOG_FILE for details."
