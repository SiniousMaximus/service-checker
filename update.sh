#!/bin/sh

INSTALL_DIR=/etc/service-checker

git pull
git fetch --tags
git checkout $$(git describe --tags $$(git rev-list --tags --max-count=1))

cp server.py $INSTALL_DIR/server.py