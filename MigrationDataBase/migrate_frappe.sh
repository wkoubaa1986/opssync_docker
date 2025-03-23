#!/bin/bash

# Set Variables
OLD_SITE_NAME="aquaworldservicing.frappe.cloud"
SITE_NAME="aquaworldservicing.opssync.pro"  # Change if your site has a different name
DB_NAME="_f4e3c6415dd0cb74"
DB_PASSWORD=Wassim1986
DOCKER_CONTAINER="opssync1-backend-1"
DATABASE_CONTAINER="mariadb-database"
# Backup file names (from the screenshot)
DB_BACKUP=/home/wassim/gitops/MigrationDataBase/20250302_100820-aquaworldservicing_frappe_cloud-database.sql.gz
PUBLIC_BACKUP=/home/wassim/gitops/MigrationDataBase/20250302_113016-aquaworldservicing_frappe_cloud-files.tar
PRIVATE_BACKUP=/home/wassim/gitops/MigrationDataBase/20250302_113016-aquaworldservicing_frappe_cloud-private-files.tar
CONFIG_BACKUP=/home/wassim/gitops/MigrationDataBase/20250302_113016-aquaworldservicing_frappe_cloud-site_config_backup.json
DECRYPTED_FILE="/home/wassim/gitops/MigrationDataBase/database.sql.gz"

# echo "🚀 Starting Migration Process..."

# if grep -q '"encryption_key"' "$CONFIG_BACKUP"; then
#     ENCRYPTION_KEY=$(jq -r '.encryption_key' "$CONFIG_BACKUP")
# else
#     ENCRYPTION_KEY=""
# fi

# # # Step 2: Decrypt Backup Files
# # echo "🔐 Decrypting backups..."
# # openssl enc -d -aes-256-cbc -md md5 -in "$DB_BACKUP" -out "$DECRYPTED_FILE" -k "$ENCRYPTION_KEY"

# DB_SQL="/home/wassim/gitops/MigrationDataBase/database.sql"
# gunzip -c -f $DB_BACKUP > $DB_SQL
# docker cp $DB_SQL $DOCKER_CONTAINER:/tmp/database.sql
# docker exec -it "$DOCKER_CONTAINER" bench --site "$SITE_NAME"  restore /tmp/database.sql

# # docker cp /path/to/database.sql "$DOCKER_CONTAINER":/home/frappe/frappe-bench/database.sql

# echo "⏳ Waiting for database restore to finish..."
# sleep 5
# bench --site aquaworldservicing.opssync.pro migrate
# echo "🔄 Restoring database..."
# # docker exec -i $DATABASE_CONTAINER mysql -u root -pWassim1986 -e "DROP DATABASE IF EXISTS ${DB_NAME}; CREATE DATABASE ${DB_NAME};"

# # docker exec -it $DATABASE_CONTAINER bash mysql -u root -pWassim1986
# # docker exec -i  $DATABASE_CONTAINER mysql -u root -pWassim1986 $DB_NAME < /tmp/database.sql


# echo "⚙️ Running migrations..."
# docker exec -i $DOCKER_CONTAINER bash -c "cd /home/frappe/frappe-bench && bench migrate"


# Step 4: Copy Backup Files into Docker Container
echo "📂 Copying files into the container..."
# docker cp $DB_SQL $DATABASE_CONTAINER:/tmp/database.sql
docker cp $PRIVATE_BACKUP $DOCKER_CONTAINER:/tmp/private-files.tar
docker cp $PUBLIC_BACKUP $DOCKER_CONTAINER:/tmp/public-files.tar

# Extract private files to the correct location
echo "⚙️ Extracting private files ..."
docker exec -u frappe -w /home/frappe/frappe-bench/ $DOCKER_CONTAINER tar --transform="s|$OLD_SITE_NAME|$SITE_NAME|" -xvf /tmp/private-files.tar -C /home/frappe/frappe-bench/sites/

# Extract public files to the correct location
echo "⚙️ Extracting public files ..."
docker exec -u frappe -w /home/frappe/frappe-bench/ $DOCKER_CONTAINER tar --transform="s|$OLD_SITE_NAME|$SITE_NAME|" -xvf /tmp/public-files.tar -C /home/frappe/frappe-bench/sites/

# Cleanup: Remove backup files from the container
docker exec -u frappe $DOCKER_CONTAINER rm /tmp/private-files.tar /tmp/public-files.tar /tmp/database.sql

exit 0
