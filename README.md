
# docker-host

[![GitHub release](https://img.shields.io/github/release/qoomon/docker-host.svg)](https://hub.docker.com/r/qoomon/docker-host/)
[![Docker Stars](https://img.shields.io/docker/pulls/qoomon/docker-host.svg)](https://hub.docker.com/r/qoomon/docker-host/)
[![Build Workflow](https://github.com/qoomon/docker-host/workflows/Build/badge.svg)](https://github.com/qoomon/docker-host/actions?query=workflow%3ABuild)

Docker Image Tags:
* `latest`
* `2`
* `2.x.x`

Docker image to forward **TCP** and **UDP** traffic to the docker host. 

This container will determine docker host address in the following order
* Use ip from environment variable `DOCKER_HOST` if set
  * This allows you to use this image to forward traffic to arbitrary destinations, not only the docker host.
* Try to resolve `host.docker.internal` (`getent ahostsv4 host.docker.internal`)
* Defaults to default gateway (`ip -4 route show default`)

By default all ports (`0:65535`) are forwarded to docker host you can override ports by setting environment variable `PORTS` to a comma separated list of ports and/or port ranges e.g `443,80,8000:9000`

#### ⚠️ On **Linux systems** 

* You have to bind your host applications to `0.0.0.0` or `bridge` network gateway in addition to `127.0.0.1`. 

  Use following docker command to get the bridge network gateway IP address 

  `docker network inspect bridge --format='{{( index .IPAM.Config 0).Gateway}}'`

* You might need to configure your firewall of the host system to allow the docker-host container to communicate with the host on your relevant port, see [#21](https://github.com/qoomon/docker-host/issues/21#issuecomment-497831038).

---

# Examples
These examples will send messages from docker container to docker host with `netcat`

### Preparation
Start `netcat` server **TCP** on port `2323` to receive and display messages
```sh
nc -p 2323 -lk
```
Start `netcat` server **UDP** on port `5353` to receive and display messages
```sh
nc -p 5353 -lk -u
```   

## Docker Link
Run the dockerhost container.
```sh
docker run --rm \
  --name 'docker-host' \
  --cap-add=NET_ADMIN --cap-add=NET_RAW \
  --restart on-failure \
  -d qoomon/docker-host
```
Run your application container and link the dockerhost container.
The dockerhost will be reachable through the domain/link `dockerhost` of the dockerhost container
#### This example will let you send messages to **TCP** `netcat` server on docker host.
```sh
docker run --rm \
  --link 'docker-host' \
  -it alpine nc 'docker-host' 2323 -v
```
#### This example will let you send messages to **UDP** `netcat` server on docker host.
```sh
docker run --rm \
  --link 'docker-host' \
  -it alpine nc 'docker-host' 5353 -u -v
```

## Docker Network
Create the dockerhost network.
```sh
network_name="Network-$RANDOM"
docker network create "$network_name"
```
Run the dockerhost container within the dockerhost network.
```sh
docker run --name "${network_name}-docker-host" \
  --cap-add=NET_ADMIN --cap-add=NET_RAW \
  --restart on-failure \
  --net=${network_name} --network-alias 'docker-host' \
  qoomon/docker-host
```
Run your application container within the dockerhost network.
The dockerhost will be reachable through the domain/link `docker-host` of the dockerhost container
#### This example will let you send messages to **TCP** `netcat` server on docker host.
```sh
docker run --rm \
  --link 'docker-host' \
  -it alpine nc 'docker-host' 2323 -v
```
#### This example will let you send messages to **UDP** `netcat` server on docker host.
```sh
docker run --rm \
  --link 'docker-host' \
  -it alpine nc 'docker-host' 5353 -u -v
```

## Docker Compose
```yaml
version: '2'

services:
    docker-host:
        image: qoomon/docker-host
        cap_add: [ 'NET_ADMIN', 'NET_RAW' ]
        mem_limit: 8M
        restart: on-failure
    tcp_message_emitter:
        depends_on: [ docker-host ]
        image: alpine
        command: [ "sh", "-c", "while :; do date; sleep 1; done | nc 'docker-host' 2323 -v"]
    udp_message_emitter:
        depends_on: [ docker-host ]
        image: alpine
        command: [ "sh", "-c", "while :; do date; sleep 1; done | nc 'docker-host' 5353 -u -v"]
```

---
# External References
* https://medium.com/@sam_ngu/connecting-to-docker-host-mysql-from-docker-container-linux-ubuntu-766e526542fd
