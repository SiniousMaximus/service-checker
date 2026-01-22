.PHONY: help install clean update

help:
	@echo "Available commands:"
	@echo "  make install  - Create virtual enviournment and install dependencies"
	@echo "  make update   - Pulls the lates release and updates dependencies"
	@echo "  make clean    - Remove the vinrual enviournment"

install:
	python3 -m venv sc-env
	./sc-env/bin/pip install --upgrade pip
	./sc-env/bin/pip install -r requirements.txt
	chmod +x install.sh
	./install.sh
	@echo "Installation was succesfull. Please start the service-checker service"

uninstall:
	chmod +x uninstall.sh
	./uninstall.sh

update:
	chmod +x update.sh
	./update.sh