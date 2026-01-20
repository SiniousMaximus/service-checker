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

if [ -z "$1" ]; then
    echo "Usage: $0 /path/to/server.py"
    exit 1
fi
SCRIPT=$1

python3 $SCRIPT update
status=$?

if [ "$status" = 2 ]; then
    echo "Update was performed, restarting service..."
    if [ "$INIT" = "systemd" ]; then
        systemctl restart service-checker
    else
        rc-service service-checker restart
    fi
    echo "Service restart succesful"
else
    echo "Already updated"
fi
