
# docker-host
Docker image to forward all traffic to the docker host 
* uses dns entry `host.docker.internal` if available
* or default gateway as docker host

[![Build Status](https://travis-ci.org/qoomon/docker-host.svg?branch=master)](https://travis-ci.org/qoomon/docker-host)
[![Docker Stars](https://img.shields.io/docker/pulls/qoomon/docker-host.svg)](https://hub.docker.com/r/qoomon/docker-host/)

## Docker Example - Link
```sh
docker run --name 'dockerhost' \
  --cap-add=NET_ADMIN --cap-add=NET_RAW \
  --restart on-failure \
  qoomon/docker-host
```
```sh
docker run --name dummy \
  --link 'dockerhost' 
  appropriate/curl 'http://dockerhost'
```

## Docker Example - Network
```sh
network_name="Network-$RANDOM"
docker network create "$network_name"
docker run --name "${network_name}-dockerhost" \
  --cap-add=NET_ADMIN --cap-add=NET_RAW \
  --restart on-failure \
  --net=${network_name} --network-alias 'dockerhost' \
  qoomon/docker-host
```
```sh
docker run --name dummy \
  --net=${network_name} \
  appropriate/curl 'http://dockerhost'
```

# Docker Compose Example
```yaml
version: '2'

services:
    dockerhost:
        image: qoomon/docker-host
        cap_add: [ 'NET_ADMIN', 'NET_RAW' ]
        mem_limit: 4M
        restart: on-failure
    dummy:
        depends_on: [ dockerhost ]
        image: appropriate/curl
        command: ["http://dockerhost"]
```
