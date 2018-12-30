#!/bin/sh
set -e

DOCKER_HOST="$(getent hosts host.docker.internal | cut -d' ' -f1)"
if [ $DOCKER_HOST ]; then
  echo "Docker Host: $DOCKER_HOST (host.docker.internal)"
else
  DOCKER_HOST=$(ip -4 route show default | cut -d' ' -f3)
  echo "Docker Host: $DOCKER_HOST (default gateway)"
fi

FORWARDING_PORTS=${PORTS:-'0:65535'}

iptables -t nat -I PREROUTING -p tcp --match multiport --dports "$FORWARDING_PORTS" -j DNAT --to-destination $DOCKER_HOST
iptables -t nat -I POSTROUTING -j MASQUERADE

trap "exit 0;" TERM INT

# Ah, ha, ha, ha, stayin' alive...
while true; do :; done &
kill -STOP $!
wait $!

