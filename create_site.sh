#!/bin/bash

docker compose --project-name opssync1 exec backend \
  bench new-site --mariadb-user-host-login-scope=% --db-root-password Wassim1986 --install-app erpnext --admin-password Wassim1986 aquaworldservicing.opssync.pro
  #!/bin/bash

docker compose --project-name opssync1 exec backend \
  bench new-site aquaworldservicing.opssync.pro \
  --mariadb-user-host-login-scope=% \
  --db-root-password Wassim1986 \
  --admin-password Wassim1986 \
  --install-app erpnext \
  --install-app hrms \
  --install-app raven

docker compose --project-name opssync1 exec backend bench --site aquaworldservicing.opssync.pro enable-scheduler
docker compose --project-name opssync1 exec backend bench --site aquaworldservicing.opssync.pro set-config server_script_enabled true


