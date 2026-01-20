#!/bin/sh
set -e

echo "=== Starting Service Checker ==="

# Fix permissions
chmod -R 600 /config/ssh

# Run the server
exec python3 /etc/service-checker/server.py start -c /config/config.yml
