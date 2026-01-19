#!/bin/sh

WORK_DIR="/etc/service-checker"

# Rerun as root if not already
if [ "$(id -u)" -ne 0 ]; then
    echo "Script requires root privileges. Re-running with sudo..."
    exec sudo "$0" "$@"
fi

detect_init() {
    if [ -d /run/systemd/system ]; then
        echo "Init system Systemd detected"
        INIT="systemd"
        return 0
    fi

    if command -v rc-service >/dev/null 2>&1; then
        echo "Init system OpenRC detected"
        INIT="openrc"
        return 0
    fi

    echo "Unknown or unsupported init system"
    exit 1
}

# Getting the latest server.py 
echo "Getting the latest server.py script..."
curl -fL -o "$WORK_DIR/server.py" \
    https://raw.githubusercontent.com/SiniousMaximus/service-checker/main/server.py \
    || exit 1

echo "Restarting the service-checker service"
if [ $INIT = "systemd" ]; then
	systemctl restart service-checker.service
else
	rc-service service-checker restart
fi
