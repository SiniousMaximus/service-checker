# Service Checker for uptime kuma

This project is mainly for those of use who have most of their services as proxmox LXCs, and want to integrate uptime kuma better with these services.

Uptime kuma is a great service, but for my personal use case missed a feature, the ability to run commands on remote hosts via ssh and determine the service status from the responce. So I made a small python script that asts as a web server with an api for uptime kuma (or other similar services).

## Requirements

You can either get service-checker with docker, or run it bare metal. Bare metal requires python3, python3-yaml, and openssh.

Only systemd and openrc are currently supported on the remote hosts. The hosts must be accessible with an ssh key for a user with the permissions to check the status of services.

## Installation:

### Docker:

Use the following docker-compose.yml:

```yaml
services:
  service-checker:
    container_name: service-checker
    image: siniousmaximus/service-checker:v0.1.0
    ports:
      - "8000:8000"
    restart: unless-stopped
    volumes:
      - ./config:/config
```

Create a new directory called config in the same place. This directory shoul include a file called config.yml and a directory called .ssh. config.yml includes services you want to check in the following format:

```yaml
service1:
  hostname: host1
  service: systemd
service2:
  hostname: host2
  service: openrc
```

The .ssh directory is the a typical openssh user configuration for the Service Checker host. At a minimum, it must contain a config file and a private ssh key. The config file should follow openssh's format, and contain the hostnames in the config.yml. An example:

```
Host host1
	User root
	Port 22 # Default port
	IdentityFile ~/.ssh/key1
Host host2
	User admin
	Port 23
	IdentityFile ~/.ssh/key2
```

### Bare metal

You need the config.yaml file and .ssh directory mentioned at the Docker section. The script expects config.yml to be in the same directory as the script itself, and .ssh must be in the script runner's home directory. By default, the script listens on 0.0.0.0:8000. 

The following commands can be used with the script server.py:

- start: Starts the process in the foreground
- stop: Stops the webserver.
- retstart: Restarts the webserver
- status: Show the status of the webserver.

The follwoing flags are useable with server.py:

- -d / --daemon: Combined with start, starts the process in the background
- -p / --port [PORT]: Change the port the webserver listens on.

The server responds to GET http requests on `http://0.0.0.0:8000/` and `http://0.0.0.0:8000/api/service/<service-name>`. The former retuns a plain http responce if the server is up, and the later checks the status of the specified service on the remote host, and returns a json responce like the following example: `{"success": true, "service_name": "dnsmasq", "status": "up", "hostname": "alpine-vm", "service": "openrc"}`

## Uptime Kuma intergarion

In the dashboard, add a new monitor with the type "HTTP(S)-Json Query". The URL should be `http://<service-checker-ip>:8000/api/service/<service-name>` to check the status of service-name, which should be defined in the config.yml file. The json query expression should be "$.status", and the keyword should be equal to "up" (== up).
