#!/bin/sh
set -e

function cap_support {
  capsh --print | grep "Current:" | cut -d' ' -f3 | grep -q "$1"
}

# ensure network capabilities
if ! cap_support 'cap_net_admin' || ! cap_support 'cap_net_raw'; then
  echo "[ERROR] docker-host container needs Linux capabilities NET_ADMIN and NET_RAW"
  echo "  e.g 'docker run --cap-add=NET_ADMIN --cap-add=NET_RAW ...'"
  exit 1
fi

if [ -n "$DOCKER_HOST" ]; then
  docker_host_ipv4="$(getent ahostsv4 "$DOCKER_HOST" | head -n1 | cut -d' ' -f1)"
  if [ "$docker_host_ipv4" != "$DOCKER_HOST" ]; then
    echo "Docker Host: ${docker_host_ipv4:-'n/a'} ($DOCKER_HOST)"
  else
    echo "Docker Host: ${docker_host_ipv4:-'n/a'}"
  fi
else
  DOCKER_HOST='host.docker.internal'
  docker_host_ipv4="$(getent ahostsv4 "$DOCKER_HOST" | head -n1 | cut -d' ' -f1)"
  if [ -n "$docker_host_ipv4" ]; then
    echo "Docker Host: $docker_host_ipv4 ($DOCKER_HOST)"
  else
    docker_host_ipv4=$(ip -4 route show default | cut -d' ' -f3)
    echo "Docker Host: ${docker_host_ipv4:-'n/a'} (default gateway)"
  fi
fi

# exit if docker host ip could not be determined
if [ -z "$docker_host_ipv4" ]; then
  exit 1
fi

FORWARDING_PORTS=${PORTS:-'0:65535'}
echo "Forwarding ports: $FORWARDING_PORTS"

# setup forwarding rules
iptables -t nat -I POSTROUTING -j MASQUERADE
for forwarding_port in $(echo "$FORWARDING_PORTS" | tr ";" " ")
do
  iptables --table nat --insert PREROUTING \
    --protocol tcp \
    --dport "$forwarding_port" \
    --jump DNAT --to-destination "$docker_host_ipv4"
  iptables --table nat --insert PREROUTING \
    --protocol udp \
    --dport "$forwarding_port" \
    --jump DNAT --to-destination "$docker_host_ipv4"
done

# exit on ctrl+c
trap "exit 0;" TERM INT

# Ah, ha, ha, ha, stayin' alive...
while true; do :; done &
kill -STOP $!
wait $!
