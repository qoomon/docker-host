#!/bin/sh
set -e # exit on error

if [ "$(whoami)" = nobody ]
then
  sleep infinity
  exit 1
fi

# --- Ensure container network capabilities ----------------------------------

if ! capsh --has-p='cap_net_admin' --has-p='cap_net_raw' &>/dev/null
then
  echo "[ERROR] docker-host container needs Linux capabilities NET_ADMIN and NET_RAW"
  echo "  e.g 'docker run --cap-add=NET_ADMIN --cap-add=NET_RAW ...'"
  exit 1
fi


# --- Determine docker host address ------------------------------------------

function _resolve_host { 
  getent ahostsv4 "$1" | head -n1 | cut -d' ' -f1
}

if [ "$DOCKER_HOST" ]
then
  docker_host_source="DOCKER_HOST=$DOCKER_HOST"
  docker_host_ip="$(_resolve_host "$DOCKER_HOST")"

  if [ ! "$docker_host_ip" ]
  then
    echo "[ERROR] could not resolve $DOCKER_HOST (DOCKER_HOST) "
    exit 1
  fi
else
  DOCKER_HOST='host.docker.internal'
  docker_host_source="$DOCKER_HOST"
  docker_host_ip="$(_resolve_host "$DOCKER_HOST")"

  if [ ! "$docker_host_ip" ]
  then
    DOCKER_HOST="$(ip -4 route show default | cut -d' ' -f3)"
    docker_host_source="default gateway"
    docker_host_ip="$DOCKER_HOST"
  fi

  if [ ! "$docker_host_ip" ]
  then
    echo "[ERROR] could not determine docker host ip"
    exit 1
  fi
fi

echo "Docker Host: $docker_host_ip ($docker_host_source)"


# --- Configure iptables port forwarding -------------------------------------

PORTS="${PORTS:-"1-65535"}"
PORTS="$(echo ${PORTS//,/ })"

echo "Forwarding ports: ${PORTS// /, }"
for forwarding_port in $PORTS
do
  docker_container_port="${forwarding_port%%:*}"
  docker_host_port="${forwarding_port#*:}"

  iptables --table nat --insert PREROUTING \
    --protocol tcp --destination-port "${docker_container_port/-/:}" \
    --jump DNAT --to-destination "$docker_host_ip:$docker_host_port"

  iptables --table nat --insert PREROUTING \
    --protocol udp --destination-port "${docker_container_port/-/:}" \
    --jump DNAT --to-destination "$docker_host_ip:$docker_host_port"
done

iptables --table nat --insert POSTROUTING --jump MASQUERADE


# --- Drop root access -------------------------------------------------------

exec su nobody -s "$0"
