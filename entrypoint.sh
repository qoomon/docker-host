#!/bin/sh
set -e # exit on error

function checkpcaps {
  local process_caps="$(getpcaps $$),"
  for required_cap in "$@"
  do 
    echo "$process_caps" | grep -q "${required_cap}," || return 1
  done
}

function resolveHost { 
  getent ahostsv4 "$1" | head -n1 | cut -d' ' -f1
}

# ensure network capabilities
if ! checkpcaps 'cap_net_admin' 'cap_net_raw'
then
  echo "[ERROR] docker-host container needs Linux capabilities NET_ADMIN and NET_RAW"
  echo "  e.g 'docker run --cap-add=NET_ADMIN --cap-add=NET_RAW ...'"
  exit 1
fi

# determine docker host ip
if [ "$DOCKER_HOST" ]
then
  docker_host_ip="$(resolveHost "$DOCKER_HOST")"
  if [ "$docker_host_ip" != "$DOCKER_HOST" ]
  then
    echo "Docker Host: ${docker_host_ip:-'n/a'} ($DOCKER_HOST)"
  else
    echo "Docker Host: ${docker_host_ip:-'n/a'}"
  fi
else
  DOCKER_HOST='host.docker.internal'
  docker_host_ip="$(resolveHost "$DOCKER_HOST")"
  if [ "$docker_host_ip" ]
  then
    echo "Docker Host: $docker_host_ip ($DOCKER_HOST)"
  else
    docker_host_ip=$(ip -4 route show default | cut -d' ' -f3)
    if [ "$docker_host_ip" ]
    then
      echo "Docker Host: $docker_host_ip (default gateway)"
    fi
  fi
fi

# exit if docker host ip could not be determined
if [ ! "$docker_host_ip" ]
then
  echo "[ERROR] docker-host container could not determine docker host ip"
  exit 1
fi


# setup port forwarding
FORWARDING_PORTS="$(echo ${PORTS:-'0:65535'} | sed 's/[ ,;][ ,;]*/ /g')"
echo "Forwarding ports: ${FORWARDING_PORTS// /,}"
iptables -t nat -I POSTROUTING -j MASQUERADE
for forwarding_port in ${FORWARDING_PORTS}
do
  iptables --table nat --insert PREROUTING \
    --protocol tcp \
    --dport "$forwarding_port" \
    --jump DNAT --to-destination "$docker_host_ip"
  iptables --table nat --insert PREROUTING \
    --protocol udp \
    --dport "$forwarding_port" \
    --jump DNAT --to-destination "$docker_host_ip"
done


# exit on `ctrl + c`
trap "exit 0;" TERM INT

# Ah, ha, ha, ha, stayin' alive...
while true; do :; done &
kill -STOP $!
wait $!
