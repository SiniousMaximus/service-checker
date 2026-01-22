#!/bin/sh

WORK_DIR=$(pwd)
INSTALL_DIR=/etc/service-checker
mkdir -p $INSTALL_DIR

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
        printf "The %s binary was detected\n" "$PKG"
        return 0
    fi

    printf "The %s binary was not found. Please install it manually\n" "$PKG"
    return 1
}

# Get the server files and create and start the server service
installer() {
    mkdir -p "$WORK_DIR"

    cp server.py $INSTALL_DIR/server.py
    cp -r config/ $INSTALL_DIR

	echo ""
    if [ "$INIT" = "systemd" ]; then
        cat <<EOF > /etc/systemd/system/service-checker.service
[Unit]
Description=Service Checker
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$WORK_DIR/sc-env/bin/python3 $INSTALL_DIR/server.py start
ExecStop=$WORK_DIR/sc-env/bin/python3 $INSTALL_DIR/server.py stop
ExecReload=$WORK_DIR/sc-env/bin/python3 $INSTALL_DIR/server.py restart
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
		systemctl daemon-reload
	
    else
    	cat <<EOF > /etc/init.d/service-checker
#!/sbin/openrc-run

name="service-checker"
description="Service Checker"

WORK_DIR="$INSTALL_DIR"
command="\$WORK_DIR/sc-env/bin/python3"
command_args="\$INSTALL_DIR/server.py start"
command_background="yes"
directory="\$INSTALL_DIR"
pidfile="\$INSTALL_DIR/server.pid"

depend() {
    need net
}

stop() {
    ebegin "Stopping \$name"
    "\$command" "\$INSTALL_DIR/server.py" stop
    eend \$?
}

restart() {
    ebegin "Restarting \$name"
    "\$command" "\$INSTALL_DIR/server.py" restart
    eend \$?
}
EOF

		chmod +x /etc/init.d/service-checker
	fi
}

main() {
    detect_init
    check python3 || exit 1
    check ssh || exit 1
    installer
}

main
