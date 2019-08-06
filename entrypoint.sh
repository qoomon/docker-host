#!/bin/sh
set -e

# determine docker host
if [ $DOCKER_HOST ]; then
  echo "Docker Host: $DOCKER_HOST"
else
  DOCKER_HOST="$(getent hosts host.docker.internal | cut -d' ' -f1)"
  if [ $DOCKER_HOST ]; then
    echo "Docker Host: $DOCKER_HOST (host.docker.internal)"
  else
    DOCKER_HOST=$(ip -4 route show default | cut -d' ' -f3)
    echo "Docker Host: $DOCKER_HOST (default gateway)"
  fi
fi

FORWARDING_PORTS=${PORTS:-'0:65535'}
echo "Forwarding ports: $FORWARDING_PORTS"

# setup forwarding rules
for forwarding_port in $(echo "$FORWARDING_PORTS" | tr ";" " ")
do
  iptables --table nat --insert PREROUTING \
    --protocol tcp \
    --dport "$forwarding_port" \
    --jump DNAT --to-destination $DOCKER_HOST
  iptables --table nat --insert PREROUTING \
    --protocol udp \
    --dport "$forwarding_port" \
    --jump DNAT --to-destination $DOCKER_HOST
done
iptables -t nat -I POSTROUTING -j MASQUERADE

# exit on ctrl+c
trap "exit 0;" TERM INT

# Ah, ha, ha, ha, stayin' alive...
while true; do :; done &
kill -STOP $!
wait $!

