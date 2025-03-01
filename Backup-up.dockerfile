# Use OpsSync base image (Debian-based)
FROM ghcr.io/wkoubaa1986/opssync:1.0.0

# Switch to root user for setup
USER root

# ✅ Install cron and bash using apt-get (for Debian-based images)
RUN apt-get update --fix-missing && \
    apt-get install -y cron bash && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Ensure 'frappe' user exists
RUN id -u frappe &>/dev/null || useradd -ms /bin/bash frappe

# Copy backup scripts
COPY backup-and-schedule.sh /usr/local/bin/backup-and-schedule.sh
COPY backup-job.sh /usr/local/bin/backup-job.sh

# Ensure scripts use proper Unix line endings
RUN sed -i -e 's/\r$//' /usr/local/bin/backup-and-schedule.sh /usr/local/bin/backup-job.sh

# Make scripts executable
RUN chmod +x /usr/local/bin/backup-and-schedule.sh /usr/local/bin/backup-job.sh

# ✅ Start cron using `cron -f`
USER root
CMD ["bash", "-c", "/usr/local/bin/backup-and-schedule.sh"]
