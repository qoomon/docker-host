
# docker-host

[![Build Status](https://travis-ci.com/qoomon/docker-host.svg?branch=master)](https://travis-ci.com/qoomon/docker-host)

[![GitHub release](https://img.shields.io/github/release/qoomon/docker-host.svg)](https://hub.docker.com/r/qoomon/docker-host/)

[![Docker Stars](https://img.shields.io/docker/pulls/qoomon/docker-host.svg)](https://hub.docker.com/r/qoomon/docker-host/)

Docker image to forward **TCP** and **UDP** traffic to the docker host 
* uses dns entry `host.docker.internal` if available
* or default gateway as docker host

You can manually override the destination IP address by setting the environment variable `DOCKER_HOST`.
This allows you to use this image to forward traffic to arbitrary destinations, not only the docker host.

⚠️ On **Linux systems** you have to bind your host applications to `bridge` network gateway in addition to localhost(127.0.0.1), if you want to reach them through docker-host container. Use following docker command to get the bridge network gateway IP address 

`docker network inspect bridge --format='{{( index .IPAM.Config 0).Gateway}}'`

Also be sure to configure your firewall of the host system to allow the `dockerhost` container to communicate with the host on your relevant port. [Example](https://github.com/qoomon/docker-host/issues/21#issuecomment-497831038)

# Example
This example will send messages from docker container to docker host with `netcat`

### Prerequisite
Start `netcat` server **TCP** on port `2323` to receive and display messages
```sh
nc 127.0.0.1 8080 -lk
```
Start `netcat` server **UDP** on port `5353` to receive and display messages
```sh
nc 127.0.0.1 5353 -lk -u -w0
```   

## Docker Link
Run the dockerhost container.
```sh
docker run --name 'dockerhost' \
  --cap-add=NET_ADMIN --cap-add=NET_RAW \
  --restart on-failure \
  -d qoomon/docker-host
```
Run your application container and link the dockerhost container.
The dockerhost will be reachable through the domain/link `dockerhost` of the dockerhost container
#### This example will let you send messages to **TCP** `netcat` server on docker host.
```sh
docker run --rm \
  --link 'dockerhost' \
  -it alpine nc 'dockerhost' 2323 -v
```
#### This example will let you send messages to **UDP** `netcat` server on docker host.
```sh
docker run --rm \
  --link 'dockerhost' \
  -it alpine nc 'dockerhost' 5353 -u -v
```

## Docker Network
Create the dockerhost network.
```sh
network_name="Network-$RANDOM"
docker network create "$network_name"
```
Run the dockerhost container within the dockerhost network.
```sh
docker run --name "${network_name}-dockerhost" \
  --cap-add=NET_ADMIN --cap-add=NET_RAW \
  --restart on-failure \
  --net=${network_name} --network-alias 'dockerhost' \
  qoomon/docker-host
```
Run your application container within the dockerhost network.
The dockerhost will be reachable through the domain/link `dockerhost` of the dockerhost container
#### This example will let you send messages to **TCP** `netcat` server on docker host.
```sh
docker run --rm \
  --link 'dockerhost' \
  -it alpine nc 'dockerhost' 2323 -v
```
#### This example will let you send messages to **UDP** `netcat` server on docker host.
```sh
docker run --rm \
  --link 'dockerhost' \
  -it alpine nc 'dockerhost' 5353 -u -v
```

## Docker Compose
```yaml
version: '2'

services:
    dockerhost:
        image: qoomon/docker-host
        cap_add: [ 'NET_ADMIN', 'NET_RAW' ]
        mem_limit: 8M
        restart: on-failure
    tcp_message_emitter:
        depends_on: [ dockerhost ]
        image: alpine
        command: [ "sh", "-c", "while :; do date; sleep 1; done | nc 'dockerhost' 2323 -v"]
    udp_message_emitter:
        depends_on: [ dockerhost ]
        image: alpine
        command: [ "sh", "-c", "while :; do date; sleep 1; done | nc 'dockerhost' 5353 -u -v"]
```
