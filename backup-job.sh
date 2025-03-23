#!/bin/bash
set -e
set -o pipefail

# Navigate to Bench Directory
cd /home/frappe/frappe-bench/ || exit 1

# Get only valid site directories (excluding unwanted files)
sites=$(ls -1 sites | grep -Ev "assets|apps.json|apps.txt|common_site_config.json")

# Debug: Print the sites
echo "Found valid sites: $sites"

# Ensure top-level external-backup permissions for all sites
chmod -R 777 /external-backup
chown -R frappe:frappe /external-backup

# Loop through each site and create a site-specific backup folder
for site in $sites; do
    echo "🔹 Backing up site: $site"

    backup_dir="/external-backup/$site"
    mkdir -p "$backup_dir"
    # Set correct permissions
    chmod -R 770 "$backup_dir"  # Restrict to owner/group (read/write/execute)
    chown -R frappe:frappe "$backup_dir"

    # Perform the backup
    su - frappe -c "cd /home/frappe/frappe-bench && bench --site '$site' backup --with-files --compress --backup-path '$backup_dir'"

    # Identify timestamps that DO NOT have a full-backup.tar.gz
    timestamps=$(ls "$backup_dir" | grep "$site" | awk -F'-' '{print $1}' | sort -u)

    for timestamp in $timestamps; do
        # Check if a full backup file already exists
        full_backup_file="$backup_dir/${timestamp}-${site}-full-backup.tar.gz"
        if [ ! -f "$full_backup_file" ]; then
            files_to_compress=$(ls "$backup_dir" | grep "^$timestamp-$site" | grep -v "full-backup.tar.gz" | awk '{print $0}')
            
            if [ ! -z "$files_to_compress" ]; then
                # ✅ Compress only missing full backups
                (cd "$backup_dir" && tar -czf "${timestamp}-${site}-full-backup.tar.gz" $files_to_compress)

                # ✅ Remove individual backup files after compression
                for file in $files_to_compress; do
                    rm -f "$backup_dir/$file"
                done

                echo "✅ Compressed missing files with timestamp $timestamp into ${timestamp}-${site}-full-backup.tar.gz"
            fi
        fi
    done

    # Clean up old backups: Keep only the latest 30 compressed backups
    echo "🧹 Cleaning up old backups for $site..."
    find "$backup_dir" -type f -name "*.tar.gz" -printf "%T@ %p\n" | sort -nr | tail -n +31 | cut -d' ' -f2- | xargs rm -f || true
    echo "🗑️  Kept last 30 backups for $site, deleted older ones."
done

echo "🎉 All site backups completed successfully!"

