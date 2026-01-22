#!/bin/sh

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

if [ "$INIT" = "systemd" ]; then
    systemctl stop service-checker.service
    systemctl disable service-checker.service
    rm -f /etc/systemd/system/service-checker.service
    systemctl daemon-reload
    rm -rf /etc/service-checker
else
    rc-service service-checker stop
    rc-update del service-checker
    rm -f /etc/init.d/service-checker
    rm -rf /etc/service-checker
fi

rm -rf sc-env