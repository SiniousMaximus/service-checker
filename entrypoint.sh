#!/bin/sh
set -e

echo "=== Starting Service Checker ==="

# Copy config files
cp /config/config.yml /etc/service-checker/config.yml
cp -r /config/.ssh /root/.ssh

# Fix permissions
chmod 700 /root/.ssh
chmod 600 /root/.ssh/* 2>/dev/null || true

# Run the server
exec python3 /etc/service-checker/server.py start
