#!/bin/sh
# Use unofficial strict mode of Bash: http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
c=$'\n\t'

# since alpine version 3.19.0 iptables-nft is used by default (https://wiki.alpinelinux.org/wiki/Release_Notes_for_Alpine_3.19.0),  
# however this causes compatibility issues for hosts with older kernels (e.g. Windows > https://github.com/microsoft/WSL/issues/6044), 
# therefore we still use iptables-legacy
alias iptables=iptables-legacy

# --- Ensure container network capabilities ----------------------------------

if ! capsh --has-p='cap_net_admin' --has-p='cap_net_raw' &>/dev/null
then
  echo "[ERROR] docker-host container needs Linux capabilities NET_ADMIN and NET_RAW"
  echo "  e.g 'docker run --cap-add=NET_ADMIN --cap-add=NET_RAW ...'"
  exit 1
fi


# --- Determine docker host address ------------------------------------------

function _resolve_host {
  ip=$(getent ahostsv4 "$1" | head -n1 | cut -d' ' -f1)
  echo "$ip"
}

# Check if the docker host env var is set
if [ "${DOCKER_HOST:-}" ]
then
  docker_host_source="DOCKER_HOST=$DOCKER_HOST"
  docker_host_ip="$(_resolve_host "$DOCKER_HOST")"

  if [ ! "$docker_host_ip" ]
  then
    echo "[ERROR] could not resolve $DOCKER_HOST (DOCKER_HOST) "
    exit 1
  fi
else
  # Check if we can resolve some special hostnames
  # docker - host.docker.internal
  # podman - host.containers.internal
  DOCKER_HOSTNAMES=$'host.docker.internal\thost.containers.internal'
  docker_host_ip=""

  for docker_hostname in $DOCKER_HOSTNAMES
  do
    docker_host_source="$docker_hostname"
    docker_host_ip="$(_resolve_host "$docker_hostname")"
    if [ "$docker_host_ip" ]
    then
      break
    fi
  done

  # If none hostname resolves, then we try using the default gateway address
  if [ ! "$docker_host_ip" ]; then
    docker_host_source="default gateway"
    docker_host_ip="$(ip -4 route show default | cut -d' ' -f3 | head -n1)"
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

# nft add table nat
# nft add chain nat prerouting  { type nat hook prerouting  priority -100 \; }
# nft add chain nat postrouting { type nat hook postrouting priority  100 \; }

echo "Forwarding ports: ${PORTS// /, }"
for forwarding_port in $PORTS
do
  docker_container_port="${forwarding_port%%:*}"
  docker_host_port="${forwarding_port#*:}"
  
  # nft add rule nat prerouting tcp \
  #   dport "${docker_container_port}" \
  #   dnat to "$docker_host_ip:$docker_host_port"
  iptables --table nat --insert PREROUTING \
    --protocol tcp --destination-port "${docker_container_port/-/:}" \
    --jump DNAT --to-destination "$docker_host_ip:$docker_host_port"   

  # nft add rule nat prerouting udp \
  #   dport "${docker_container_port}" \
  #   dnat to "$docker_host_ip:$docker_host_port"
  iptables --table nat --insert PREROUTING \
    --protocol udp --destination-port "${docker_container_port/-/:}" \
    --jump DNAT --to-destination "$docker_host_ip:$docker_host_port"
done

# nft add rule nat postrouting masquerade
iptables --table nat --insert POSTROUTING --jump MASQUERADE


# --- Drop root access and "Ah, ha, ha, ha, stayin' alive" ---------------------

# utilize trap to handle docker stop (SIGTERM) and manual interrupt (SIGINT)
exec su nobody -s /bin/sh -c 'trap : TERM INT; sleep infinity & wait'
