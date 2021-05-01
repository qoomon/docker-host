#!/bin/sh
set -e # exit on error

# --- Setup --------------------------------------------------------------------
# run setup as root, finally drop root access 
if [ "$(whoami)" = 'root' ]
then
  
  # --- Ensure container network capabilities ----------------------------------
  
  function checkpcaps {
    local process_caps="$(getpcaps $$),"
    for required_cap in "$@"
    do
      echo "$process_caps" | grep -q "$required_cap," || return 1
    done
  }
  
  if ! checkpcaps 'cap_net_admin' 'cap_net_raw'
  then
    echo "[ERROR] docker-host container needs Linux capabilities NET_ADMIN and NET_RAW"
    echo "  e.g 'docker run --cap-add=NET_ADMIN --cap-add=NET_RAW ...'"
    exit 1
  fi
  
  
  # --- Determine host ip address ----------------------------------------------
  
  function resolveHost { 
    getent ahostsv4 "$1" | head -n1 | cut -d' ' -f1
  }
  
  if [ "$DOCKER_HOST" ]
  then
    docker_host_source="DOCKER_HOST=$DOCKER_HOST"
    docker_host_ip="$(resolveHost "$DOCKER_HOST")"
    
    if [ ! "$docker_host_ip" ]
    then
      echo "[ERROR] could not resolve DOCKER_HOST=$DOCKER_HOST"
      exit 1
    fi
  else
    DOCKER_HOST='host.docker.internal'
    docker_host_source="$DOCKER_HOST"
    docker_host_ip="$(resolveHost "$DOCKER_HOST")"
    
    if [ ! "$docker_host_ip" ]
    then
      docker_host_source='default gateway'
      docker_host_ip="$(ip -4 route show default | cut -d' ' -f3)"
    fi
    
    if [ ! "$docker_host_ip" ]
    then
      echo "[ERROR] could not determine docker host ip"
      exit 1
    fi
  fi
  
  echo "Docker Host: $docker_host_ip ($docker_host_source)"
  
  
  # --- Configure iptables to forward all ports to docker host -----------------
  
  PORTS="$(echo "${PORTS:-"1-65535"}" | sed 's/[ ,][ ,]*/ /g')"
  
  echo "Forwarding ports: ${PORTS// /, }"
  for forwarding_port in $PORTS
  do
    docker_container_port="${forwarding_port%%:*}"
    docker_host_port="${forwarding_port#*:}"
    
    iptables --table nat --insert PREROUTING --protocol tcp \
      --destination-port "${docker_container_port/-/:}" \
      --jump DNAT --to-destination "$docker_host_ip:$docker_host_port"
    
    iptables --table nat --insert PREROUTING --protocol udp \
      --destination-port "${docker_container_port/-/:}" \
      --jump DNAT --to-destination "$docker_host_ip:$docker_host_port"
  done
  
  iptables --table nat --inser POSTROUTING --jump MASQUERADE
  
  
  # --- Drop root access -------------------------------------------------------
  exec su -s /bin/sh nobody "$0" -- "$@"
fi


# --- Ah, ha, ha, ha, stayin' alive... -----------------------------------------
while true; do sleep infinity; done
