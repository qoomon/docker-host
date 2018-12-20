
# docker-host
Docker image to forward all traffic to the docker host 
* uses dns entry `host.docker.internal` if available
* or default gateway as docker host

[![Build Status](https://travis-ci.org/qoomon/docker-host.svg?branch=master)](https://travis-ci.org/qoomon/docker-host)
[![Docker Stars](https://img.shields.io/docker/pulls/qoomon/docker-host.svg)](https://hub.docker.com/r/qoomon/docker-host/)

# Docker Run Example
```docker run -it --restart on-failure --name 'dockerhost' --cap-add=NET_ADMIN --cap-add=NET_RAW qoomon/docker-host```

```docker run -it --rm --name dummy --link 'dockerhost' bash ping 'dockerhost'```

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
        image: bash
        command: ["ping" , "dockerhost"]
```
