#!/bin/bash
set -e  # ⛑️ Exit on any error

# 👉 Accept site name as input
SITE_NAME="$1"
if [ -z "$SITE_NAME" ]; then
  echo "❌ Usage: $0 <site_name>"
  exit 1
fi

# 🔧 Runtime config
OLD_SITE_NAME="$SITE_NAME"
DB_NAME=$(echo "$SITE_NAME" | cut -d'.' -f1)
DB_PASSWORD="Wassim1986"
DOCKER_CONTAINER="opssync-backend-1"
DATABASE_CONTAINER="mariadb-database"

# 📂 Backup paths
BACKUP_ROOT="/home/wassim/Documents/Local_Services/OpsSync/OpsSync_Backup"
MIGRATE_DIR="/home/wassim/Documents/Local_Services/opssync_docker/MigrationDataBase"
SITE_FOLDER="${BACKUP_ROOT}/${SITE_NAME}"

# 🔍 Find latest backup archive
LATEST_BACKUP=$(ls -1t "$SITE_FOLDER"/*-full-backup.tar.gz | head -n 1)
if [ -z "$LATEST_BACKUP" ]; then
  echo "❌ No full backup archive found for $SITE_NAME"
  exit 1
fi

# 🧠 Clean and convert names
ORIGINAL_NAME=$(basename "$LATEST_BACKUP")
RENAMED_NAME=$(echo "$ORIGINAL_NAME" | sed 's/\./_/g' | sed 's/_tar_gz/.tar.gz/')
BASE_NAME=$(basename "$RENAMED_NAME" -full-backup.tar.gz)
RENAMED_PATH="$MIGRATE_DIR/$RENAMED_NAME"

echo "🗃️  Using backup set: $BASE_NAME"
echo "📥 Copying and renaming backup into: $RENAMED_PATH"

# 🚛 Copy & rename
cp "$LATEST_BACKUP" "$RENAMED_PATH"

# 📦 Extract archive
tar -xzf "$RENAMED_PATH" -C "$MIGRATE_DIR"

# 🗂️ Define file paths
DB_BACKUP="$MIGRATE_DIR/${BASE_NAME}-database.sql.gz"
PUBLIC_BACKUP="$MIGRATE_DIR/${BASE_NAME}-files.tgz"
PRIVATE_BACKUP="$MIGRATE_DIR/${BASE_NAME}-private-files.tgz"
CONFIG_BACKUP="$MIGRATE_DIR/${BASE_NAME}-site_config_backup.json"
DB_SQL="$MIGRATE_DIR/${BASE_NAME}-database.sql"

echo "🚀 Starting database and file restoration for: $SITE_NAME"

# 🧵 Decompress SQL
echo "📦 Decompressing SQL backup..."
gunzip -c -f "$DB_BACKUP" > "$DB_SQL"

# 🚛 Copy SQL to DB container
echo "📤 Copying SQL to DB container..."
docker cp "$DB_SQL" "$DATABASE_CONTAINER:/tmp/database.sql"

# 💣 Drop and recreate database
echo "🧨 Dropping and recreating DB: $DB_NAME..."
docker exec -i "$DATABASE_CONTAINER" mysql -u root -p"$DB_PASSWORD" \
  -e "DROP DATABASE IF EXISTS \`$DB_NAME\`; CREATE DATABASE \`$DB_NAME\`;"

# 💾 Import SQL
echo "💾 Importing SQL dump..."
docker exec -i "$DATABASE_CONTAINER" sh -c "mysql -u root -p$DB_PASSWORD $DB_NAME < /tmp/database.sql"

# 🔐 Inject encryption_key if missing (safe host-side handling)
echo "🔐 Ensuring encryption_key is present in site config..."

ENCRYPTION_KEY=$(jq -r '.encryption_key // empty' "$CONFIG_BACKUP")

if [ -n "$ENCRYPTION_KEY" ]; then
  echo "🔑 encryption_key found in backup. Proceeding to inject only if missing..."

  TEMP_CONFIG_PATH="/tmp/site_config_${SITE_NAME}.json"

  # Step 1: Copy site_config.json from container to host
  docker cp "$DOCKER_CONTAINER:/home/frappe/frappe-bench/sites/$SITE_NAME/site_config.json" "$TEMP_CONFIG_PATH"

  # Step 2: Check if encryption_key already exists
  if jq -e '.encryption_key' "$TEMP_CONFIG_PATH" > /dev/null; then
    echo "✅ encryption_key already exists in site_config.json. Skipping injection."
  else
    echo "✍️  Injecting encryption_key into site_config.json..."
    jq --arg key "$ENCRYPTION_KEY" '. + {encryption_key: $key}' "$TEMP_CONFIG_PATH" > "${TEMP_CONFIG_PATH}.tmp" && mv "${TEMP_CONFIG_PATH}.tmp" "$TEMP_CONFIG_PATH"

    # Step 3: Copy it back into the container
    docker cp "$TEMP_CONFIG_PATH" "$DOCKER_CONTAINER:/home/frappe/frappe-bench/sites/$SITE_NAME/site_config.json"
    echo "✅ encryption_key successfully injected."
  fi

  # Step 4: Clean up
#   rm -f "$TEMP_CONFIG_PATH"
else
  echo "⚠️  No encryption_key found in $CONFIG_BACKUP. Skipping injection."
fi

# 🛠 Migrate
echo "⚙️ Running bench migrate..."
docker exec -i "$DOCKER_CONTAINER" bash -c "cd /home/frappe/frappe-bench && bench --site $SITE_NAME migrate"

# 📂 Restore files
echo "📁 Copying private and public files..."
docker cp "$PRIVATE_BACKUP" "$DOCKER_CONTAINER:/tmp/private-files.tar"
docker cp "$PUBLIC_BACKUP" "$DOCKER_CONTAINER:/tmp/public-files.tar"

echo "📦 Extracting private files..."
docker exec -u frappe -w /home/frappe/frappe-bench/ "$DOCKER_CONTAINER" tar --transform="s|$OLD_SITE_NAME|$SITE_NAME|" -xvf /tmp/private-files.tar -C /home/frappe/frappe-bench/sites/

echo "📦 Extracting public files..."
docker exec -u frappe -w /home/frappe/frappe-bench/ "$DOCKER_CONTAINER" tar --transform="s|$OLD_SITE_NAME|$SITE_NAME|" -xvf /tmp/public-files.tar -C /home/frappe/frappe-bench/sites/

# 🧹 Clean up
echo "🧹 Cleaning up temporary files..."
docker exec -u frappe "$DOCKER_CONTAINER" rm -f /tmp/private-files.tar /tmp/public-files.tar
docker exec -i "$DATABASE_CONTAINER" rm -f /tmp/database.sql
rm -f "$RENAMED_PATH"

echo "✅ Migration completed successfully for site: $SITE_NAME"
