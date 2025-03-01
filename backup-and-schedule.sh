#!/bin/bash
set -e  # Exit on first error

# Check if the backup job script exists before running
if [ ! -f "/usr/local/bin/backup-job.sh" ]; then
  echo "Error: backup-job.sh not found in /usr/local/bin/. Exiting."
  exit 1
fi

# If manual backup is enabled, run the backup job immediately.
if [ "$MANUAL_BACKUP" = "true" ]; then
  echo "Manual backup enabled. Running backup job now..."
  /usr/local/bin/backup-job.sh
fi

# Use the provided cron schedule or default to every 6 hours
SCHEDULE="${BACKUP_CRON_SCHEDULE:-0 */6 * * *}"
echo "Cron schedule set to: ${SCHEDULE}"

# Ensure cron log file exists
mkdir -p /var/log
touch /var/log/cron.log

# Remove existing backup-job.sh cron job (to avoid duplicates)
crontab -l 2>/dev/null | grep -v "backup-job.sh" | crontab -

# ✅ FIX: Add cron job **directly without `su`** (since the container runs as `frappe`)
(
  crontab -l 2>/dev/null
  echo "${SCHEDULE} /usr/local/bin/backup-job.sh >> /var/log/cron.log 2>&1"
) | crontab -

echo "Cron job set successfully."

# ✅ FIX: Start `cron -f` for Debian (instead of `crond`)
exec cron -f
