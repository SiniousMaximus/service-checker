#!/bin/sh

WORK_DIR="/etc/service-checker"
SSH_DIR="/root/.ssh"

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

check() {
    PKG="$1"

    if command -v "$PKG" >/dev/null 2>&1; then
        printf "Package %s was detected\n" "$PKG"
        return 0
    fi

    printf "Package %s was not found. Please install it manually\n" "$PKG"
    return 1
}

# Get the server files and create and start the server service
installer() {
    mkdir -p "$WORK_DIR"

	echo "Downloading server files..."
    curl -fL -o "$WORK_DIR/config.yml" \
        https://raw.githubusercontent.com/SiniousMaximus/service-checker/main/config/config.yml \
        || exit 1

    curl -fL -o "$WORK_DIR/server.py" \
        https://raw.githubusercontent.com/SiniousMaximus/service-checker/main/server.py \
        || exit 1

	echo ""
    if [ "$INIT" = "systemd" ]; then
        cat <<EOF > /etc/systemd/system/service-checker.service
[Unit]
Description=Service Checker
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$WORK_DIR
ExecStart=/usr/bin/python3 $WORK_DIR/server.py start
ExecStop=/usr/bin/python3 $WORK_DIR/server.py stop
ExecReload=/usr/bin/python3 $WORK_DIR/server.py restart
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
		systemctl daemon-reload
		systemctl enable --now service-checker
	
    else
    	cat <<EOF > /etc/init.d/service-checker
#!/sbin/openrc-run

name="service-checker"
description="Service Checker"

WORK_DIR="$WORK_DIR"
command="/usr/bin/python3"
command_args="\$WORK_DIR/server.py start"
command_background="yes"
directory="\$WORK_DIR"
pidfile="\$WORK_DIR/server.pid"

depend() {
    need net
}

stop() {
    ebegin "Stopping \$name"
    "\$command" "\$WORK_DIR/server.py" stop
    eend \$?
}

restart() {
    ebegin "Restarting \$name"
    "\$command" "\$WORK_DIR/server.py" restart
    eend \$?
}

status() {
    "\$command" "\$WORK_DIR/server.py" status
}
EOF

		chmod +x /etc/init.d/service-checker
		rc-update add service-checker default
		rc-service service-checker start
	fi
}

main() {
    detect_init
    check curl || exit 1
    check python3 || exit 1
    check ssh || exit 1
    installer
}

main
