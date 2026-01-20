# Service Checker for uptime kuma

This project is mainly for those of use who have most of their services as proxmox LXCs, and want to integrate uptime kuma better with these services.

Uptime kuma is a great service, but for my personal use case missed a feature, the ability to run commands on remote hosts via ssh and determine the service status from the responce. So I made a small python script that asts as a web server with an api for uptime kuma (or other similar services) to check the status of services.

## Requirements

You can either get Service Checker with docker, or run it bare metal (or in a Proxmox LXC, but you get what I mean). Bare metal requires python3, python3-yaml, python3-requests, and openssh.

Only Systemd and OpenRC init systems are currently supported on the remote hosts. The hosts must be accessible with an ssh key for a user with the permissions to check the status of services.

The server requires access to a config file and a directory with the private ssh keys used to connect to the remotes. The config must be in yaml with the following structure (service1 should be replaced with the actuall service name on the remote host):

```yaml
service1: 
  hostname: # Optional. Could be the LXC ID or whatever works for you, or nothing at all
  service_type: # Required. Either "systemd" or "openrc"
  user: # Required. The user that the server tries to ssh into in the remote host
  ip: # Required. Ip address of the remote host
  port: # Optional, defaults to 22
  ssh_key: # Required. Path to a private ssh key used in the ssh connection.
```

## Installation:

### Docker:

You can use the following docker-compose.yml:

```yaml
services:
  service-checker:
    container_name: service-checker
    image: siniousmaximus/service-checker:latest
    ports:
      - "8000:8000"
    restart: unless-stopped
    volumes:
      - ./config:/config
```

To work properly, the container expects a "/config" directory, including a file called "config.yml" and a directory called "ssh". The ssh directory must contain the private ssh keys used by the server, which the container expects them to be in the "/config/ssh" directory. You can cutomize the compose file to your liking as shown in this example, but on the docker side the /config folder must contain the mentioned two entities.

```yaml
services:
  service-checker:
    container_name: service-checker
    image: siniousmaximus/service-checker:latest
    ports:
      - "8000:8000"
    restart: unless-stopped
    volumes:
      - /path/to/config/file:/config/config.yml
      - /path/to/ssh/key:/config/ssh/<ssh_key_name>:ro
```

### Bare metal

See the requirments section.

You can use the provided install.sh script to automate the installation of Service Checker on your linux device with the following command: `curl -fsSL https://raw.githubusercontent.com/SiniousMaximus/service-checker/refs/heads/main/install.sh | sh`.

The script downloads server.py and an example config.yml into /etc/service-checker, creates a Systemd or OpenRC service called service-checker, and enable and starts it. The script must be ran as root, so do that or make sure you have sudo installed. Since this script expects to create a service file, your system must have Systemd or OpenRC installed to use it. Non Systemd or OpenRC systems might work with the server, but none has been tested so far.

The install script checks for the presence of curl, python3, and openssh, but not python3-yaml and python3-requests, as their names are different across many distros. Make sure you have all of them installed. To my knowledge, the package naming scheme is "python3-yaml" in debian based and "python-yaml" in arch based ditros, and "py3-yaml" in alpine. Same for python3-requests.

The following commands can be used with server.py:

- start: Starts the process in the foreground
- stop: Stops the webserver.
- retstart: Restarts the webserver (Use -d if you want the new process to run in the background)
- status: Shows the status of the webserver.
- version: Shows the current version of teh script
- update: Updates the script to the latest release

The follwoing flags are useable with server.py:

- -d / --daemon: Combined with start, starts the process in the background
- -p / --port [PORT]: Change the port the webserver listens on. Default port is 8000
- -c / --config [PATH TO CONFIG FILE]: Use a custom path pointing to a config file, defaults to /etc/service-checker/config.yml

The server responds to http GET requests on `http://0.0.0.0:8000/` and `http://0.0.0.0:8000/api/service/<service-name>`. The former retuns a simple health check for the server, and the later checks the status of the specified service on a remote host, and returns a json responce like the following example: `{"service_name": "caddy", "success": true, "hostname": "caddy", "service_type": "systemd", "status": "up"}`

## Uptime Kuma intergarion

In the dashboard, add a new monitor with the type "HTTP(S)-Json Query". The URL should be `http://<service-checker-ip>:8000/api/service/<service-name>` to check the status of service-name, which should be defined in the config file. The json query expression should be "$.status", and the keyword should be equal to "up" (== up).

## Updating

For your own sake, backup what you have in case of any breaking change after an update. If you are using the docker image, simply use `docker pull siniousmaximus/server-checker:latest` to get the latest image. Otherwise, you can use `./server.py update` to update and replace the script with the latest release. If using a Systemd or OpenRC service to run the script, you should manually restart the service after an update to make it use the new script. Or you can use the update.sh script. It requirs you to give it the path to the server script, and then performs the update and restarts a service called service-checker.

## Security

Obviously giving a tool you downloaded from the internet unlimited ssh access to your services is not the best thing to do. To reduce the risks, you can make sure the script calls to a non privlliged user on the remote host, and even go as far as to modify the `~/.ssh/authorized_keys` file on the host to minimize the damages it can do. You just need to make sure the user has access to the following commands:

```
command="/usr/bin/systemctl is-active <SERVICE NAME>",no-agent-forwarding,no-port-forwarding,no-pty <THE PUBLIC KEY CONTENTS>
```
```
command="/sbin/rc-service <SERVICE NAME> status",no-agent-forwarding,no-port-forwarding,no-pty <THE PUBLIC KEY CONTENTS>
```

This makes it so, no matter what command you send over ssh using this key, it is changed to the specified command in the authorized_keys file.

# License

PGLv3
