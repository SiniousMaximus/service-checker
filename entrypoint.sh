#!/bin/sh
set -e

echo "=== Starting Service Checker ==="

# Copy config files
cp /config/config.yml /home/checker/config.yml
cp -r /config/.ssh /home/checker/.ssh

# Fix permissions
chown -R checker:checker /home/checker
chmod 700 /home/checker/.ssh
chmod 600 /home/checker/.ssh/* 2>/dev/null || true

# Run the server
exec su -s /bin/sh checker -c "python3 /home/checker/server.py start -p 8000"