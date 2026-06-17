#!/bin/sh
# Use unofficial strict mode of Bash: http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail

# since alpine version 3.19.0 iptables-nft is used by default (https://wiki.alpinelinux.org/wiki/Release_Notes_for_Alpine_3.19.0),
# however this causes compatibility issues for hosts with older kernels (e.g. Windows > https://github.com/microsoft/WSL/issues/6044),
# therefore we still use iptables-legacy
alias iptables=iptables-legacy
if iptables-nft -L -n > /dev/null 2>&1
then
    alias iptables=iptables-nft
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
    ip=$(getent ahostsv4 "$1" | head -n1 | cut -d' ' -f1)
    echo "$ip"
}

function _check_ping {
    ping -c 1 -W 1 "$1" > /dev/null 2>&1
}

function _check_rootless {
    ! grep -qE '^[[:space:]]*0[[:space:]]+0[[:space:]]' /proc/self/uid_map
}

docker_host_ip=""

# Check if the docker host env var is set
if [ "${DOCKER_HOST:-}" ]
then
    potential_docker_host_ip="$(_resolve_host "${DOCKER_HOST}")"
    if _check_ping "$potential_docker_host_ip"
    then
        docker_host_source="environment variable DOCKER_HOST ($DOCKER_HOST)"
        docker_host_ip="$potential_docker_host_ip"
        break
    fi
    
    if [ ! "$docker_host_ip" ]
    then
        echo "[ERROR] could not resolve or ping given DOCKER_HOST ($DOCKER_HOST)"
        exit 1
    fi
else
    # check for rootless docker default host addresses
    if _check_rootless
    then
        # well-known rootless docker network driver host addresses
        ROOTLESS_DOCKER_HOSTS=$'pasta:100.64.0.1
        \tgvisor-tap-vsock:10.0.2.1
        \tslirp4netns:10.0.2.2'
        for rootless_docker_host in $ROOTLESS_DOCKER_HOSTS
        do
            potential_network_driver="${rootless_docker_host%%:*}"
            potential_docker_host_ip="${rootless_docker_host#*:}"
            if _check_ping "$potential_docker_host_ip"
            then
                docker_host_source="well-known rootless host address ($potential_network_driver)"
                docker_host_ip="$potential_docker_host_ip"
                break
            fi
        done
    else
        # check if we can resolve some special hostnames
        # docker - host.docker.internal
        # podman - host.containers.internal
        DOCKER_HOSTNAMES=$'host.docker.internal
        \thost.containers.internal'
        for docker_hostname in $DOCKER_HOSTNAMES
        do
            potential_docker_host_ip="$(_resolve_host "$docker_hostname")"
            if _check_ping "$potential_docker_host_ip"
            then
                docker_host_source="well-known host domains ($docker_hostname)"
                docker_host_ip="$potential_docker_host_ip"
                break
            fi
        done
  
        # use the default gateway address as a fallback
        if [ ! "$docker_host_ip" ]
        then
            docker_host_source="default gateway"
            docker_host_ip="$(ip -4 route show default | cut -d' ' -f3 | head -n1)"
        fi
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


# --- Drop root access and "Ah, ha, ha, ha, stayin' alive" -------------------

# utilize trap to handle docker stop (SIGTERM) and manual interrupt (SIGINT)
exec su nobody -s /bin/sh -c 'trap : TERM INT; sleep infinity & wait'
