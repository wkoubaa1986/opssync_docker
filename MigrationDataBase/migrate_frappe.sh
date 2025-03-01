#!/bin/bash

# Set Variables
SITE_NAME="aquaworldservicing"  # Change if your site has a different name
DB_NAME="_af98b2a5396924c8"
DB_PASSWORD="tMBRgWEcFpkPdhiv"
DOCKER_CONTAINER="erp_multi_tenancy-backend-1"
# Backup file names (from the screenshot)
DB_BACKUP="20250216_080014-aquaworldservicing_frappe_cloud-database.sql.gz"
FILES_BACKUP="20250216_080014-aquaworldservicing_frappe_cloud-files.tar"
PRIVATE_BACKUP="20250216_080014-aquaworldservicing_frappe_cloud-private-files.tar"
CONFIG_BACKUP="20250216_080014-aquaworldservicing_frappe_cloud-site_config_backup.json"


echo "🚀 Starting Migration Process..."

# Step 1: Extract Encryption Key from Backup Config
echo "🔍 Extracting encryption key..."
ENCRYPTION_KEY=$(jq -r '.encryption_key' $CONFIG_BACKUP)

if [[ -z "$ENCRYPTION_KEY" || "$ENCRYPTION_KEY" == "null" ]]; then
    echo "❌ Failed to extract encryption key from $CONFIG_BACKUP"
    exit 1
fi
echo "🔑 Encryption Key Found: $ENCRYPTION_KEY"

# Step 2: Decrypt Backup Files
echo "🔐 Decrypting backups..."
openssl enc -d -aes-256-cbc -md md5 -in $DB_BACKUP -out database.sql.gz -k "$ENCRYPTION_KEY"
openssl enc -d -aes-256-cbc -md md5 -in $PRIVATE_BACKUP -out private-files.tar -k "$ENCRYPTION_KEY"
openssl enc -d -aes-256-cbc -md md5 -in $PUBLIC_BACKUP -out public-files.tar -k "$ENCRYPTION_KEY"

# Step 3: Stop ERPNext (Optional)
echo "🛑 Stopping ERPNext services..."
docker stop $DOCKER_CONTAINER

echo "🔄 Extracting database backup..."
gunzip -f $DB_BACKUP

# Get extracted database filename
DB_SQL="${DB_BACKUP%.gz}"  # Removes .gz from the filename

# Step 3: Copy Backup Files into Docker Container
echo "📂 Copying files into the container..."
docker cp $DB_SQL $DOCKER_CONTAINER:/home/frappe/database.sql
docker cp $PRIVATE_BACKUP $DOCKER_CONTAINER:/home/frappe/private-files.tar
docker cp $FILES_BACKUP $DOCKER_CONTAINER:/home/frappe/public-files.tar

echo "🚀 Starting ERPNext container..."
docker start $DOCKER_CONTAINER

# Step 4: Restore Database
echo "🔄 Restoring database..."
docker exec -i $DOCKER_CONTAINER bench --site $SITE_NAME db-restore --force /home/frappe/database.sql

# Step 5: Restore Private and Public Files
echo "📂 Extracting and restoring private & public files..."
docker exec -it $DOCKER_CONTAINER tar -xvf /home/frappe/private-files.tar -C /home/frappe/frappe-bench/sites/$SITE_NAME/private/
docker exec -it $DOCKER_CONTAINER tar -xvf /home/frappe/public-files.tar -C /home/frappe/frappe-bench/sites/$SITE_NAME/public/

# Step 7: Update site_config.json
echo "🛠 Updating site_config.json..."
docker exec -it $DOCKER_CONTAINER bash -c "cat > /home/frappe/frappe-bench/sites/$SITE_NAME/site_config.json <<EOF
{
 \"db_name\": \"$DB_NAME\",
 \"db_password\": \"$DB_PASSWORD\",
 \"db_type\": \"mariadb\"
}
EOF"

# Step 8: Run Migrations
echo "⚙️ Running migrations..."
docker exec -it $DOCKER_CONTAINER bench --site $SITE_NAME migrate

# Step 9: Restart ERPNext Services
echo "🔄 Restarting ERPNext..."
docker exec -it $DOCKER_CONTAINER bench restart

# Step 10: Cleanup Backup Files
echo "🗑 Cleaning up backup files..."
rm database.sql.gz private-files.tar public-files.tar

# Step 11: Verify Migration
echo "✅ Migration complete! Access your site at:"
echo "🌍 http://localhost:8082 (or your configured domain)"

exit 0
