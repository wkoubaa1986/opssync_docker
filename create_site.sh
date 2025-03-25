#!/bin/bash

# Usage:
# ./create_site.sh <project_name> <site_name> <db_root_password> <admin_password> <app1> <app2> ...

PROJECT_NAME="$1"
SITE_NAME="$2"
DB_ROOT_PASSWORD="$3"
ADMIN_PASSWORD="$4"
APPS_TO_INSTALL="${@:5}"  # All remaining arguments from position 5 onward

if [ $# -lt 5 ]; then
  echo "Usage: $0 <project_name> <site_name> <db_root_password> <admin_password> <app1> [app2] [app3]..."
  exit 1
fi

# Install site with the first app (needed for bench new-site)
FIRST_APP=$(echo "$APPS_TO_INSTALL" | awk '{print $1}')
OTHER_APPS=$(echo "$APPS_TO_INSTALL" | cut -d' ' -f2-)

docker compose --project-name "$PROJECT_NAME" exec backend \
  bench new-site "$SITE_NAME" \
  --mariadb-user-host-login-scope=% \
  --db-root-password "$DB_ROOT_PASSWORD" \
  --admin-password "$ADMIN_PASSWORD" \
  --install-app "$FIRST_APP"

# Install remaining apps (if any)
for APP in $OTHER_APPS; do
  docker compose --project-name "$PROJECT_NAME" exec backend \
    bench --site "$SITE_NAME" install-app "$APP"
done

# Enable scheduler and set config
docker compose --project-name "$PROJECT_NAME" exec backend \
  bench --site "$SITE_NAME" enable-scheduler

docker compose --project-name "$PROJECT_NAME" exec backend \
  bench --site "$SITE_NAME" set-config server_script_enabled true