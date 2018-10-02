#!/bin/sh
set -e

DOCKER_HOST="$(getent hosts host.docker.internal | cut -d' ' -f1)"
if [ ! $DOCKER_HOST ]; then
  DOCKER_HOST=$(ip -4 route show default | cut -d' ' -f3)
fi

FORWARDING_PORTS=${PORTS:-'0:65535'}
echo "Docker Host: $DOCKER_HOST"
echo "Forwarding Ports: $FORWARDING_PORTS"

iptables -t nat -I PREROUTING -p tcp --match multiport --dports "$FORWARDING_PORTS" -j DNAT --to-destination $DOCKER_HOST
iptables -t nat -I POSTROUTING -j MASQUERADE

# Ah, ha, ha, ha, stayin' alive...
trap "exit 0;" TERM INT; while true; do sleep 1d; done & wait
