# Service Checker for uptime kuma

This project is mainly for those of use who have most of their services as proxmox LXCs, and want to integrate uptime kuma better with these services.

Uptime kuma is a great service, but for my personal use case missed a feature, the ability to run commands on remote hosts via ssh and determine the service status from the responce. So I made a small python script that asts as a web server with an api for uptime kuma (or other similar services) to check the status of services.

## Requirements

You can either get Service Checker with docker, or run it bare metal (or in a Proxmox LXC, but you get what I mean). Bare metal requires python3 and openssh.

Only remote services running with Systemd, OpenRC, or inside docker are supported currently. Both checking the container status or health (if it has a healthcheck) is supported. The server must be able to connect to a user with the privelage to do the healthchecks, via ssh with a private key.

The server requires access to a config file and a directory with the private ssh keys used to connect to the remotes. The config must be in yaml with the following structure (service1 should be replaced with the actuall service name on the remote host):

```yaml
service1: 
  hostname: # Optional. Could be the LXC ID or whatever works for you, or nothing at all
  service_type: # Required. Either "systemd", "openrc", "docker-status", or "docker-health"
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
    healthcheck:
      interval: 30s
      timeout: 1s
      retries: 3
      test: ["CMD", "curl", "http://localhost:8000/"]
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
    healthcheck:
      interval: 30s
      timeout: 1s
      retries: 3
      test: ["CMD", "curl", "http://localhost:8000/"]
```

### Bare metal

See the requirments section.

Clone the repo and run `make install`:

```sh
git clone https://github.com/SiniousMaximus/service-checker
cd service-checker
make install
```

This script stores the config files in `/etc/service-checker/config/config.yml`. Optionally, you can also store the private ssh keys used with Service Checker in `/etc/service-checker/config/ssh/`, but that is not mandatory. After adding your desired services to the config file, start the service-checker service and enable it at boot. For Systemd systems run `sudo systemctl enable --now service-checker` and for OpenRC systems run `sudo rc-update add service-checker default && sudo rc-service service-checker start`.

You can also update or uninstall Service Checker, similarly by running `make update` or `make uninstall` inside the repo. Be advised that uninstalling with this method removes every change made by the installation script, including removing the `/etc/service-checker` directory and the python virtual enviournment.

NOTE: `make install` is broken on OpenRC systems because I symply can't wrap my head around making an OpenRC service. It will be fixed eventually in later releases.

## Uptime Kuma intergarion

In the dashboard, add a new monitor with the type "HTTP(S)-Json Query". The URL should be `http://<service-checker-ip>:8000/api/service/<service-name>` to check the status of service-name, which should be defined in the config file. The json query expression should be "$.status", and the keyword should be equal to "up" (== up).

## Security

Obviously giving a tool you downloaded from the internet unlimited ssh access to your services is not the best thing to do. To reduce the risks, you can make sure the script calls to a non privlliged user on the remote host, and even go as far as to modify the `~/.ssh/authorized_keys` file on the host to minimize the damages it can do. You just need to make sure the user has access to one of the following commands, based on the service type:

Systemd: `systemctl is-active service_name`

OpenRC: `rc-service service_name status`

Normal Docker: `docker inspect --formatt={{.State.Status}} service_name`

Docker with health check: `docker inspect --formatt={{.State.Health.Status}} service_name`

An examle ~/.ssh/authorized_keys entry:

```
command="/usr/bin/systemctl is-active <SERVICE NAME>",no-agent-forwarding,no-port-forwarding,no-pty <THE PUBLIC KEY CONTENTS>
```

This makes it so, no matter what command you send over ssh using this key, it is changed to the specified command in the authorized_keys file.

# License

PGLv3
