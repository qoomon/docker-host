#!/bin/sh
set -e

GATEWAY=$(ip route | grep '^default' | cut -d' ' -f3)
echo "Docker Host Gateway: $GATEWAY"

iptables -t nat -I PREROUTING -p tcp --match multiport --dports "${PORTS:-'0:65535'}" -j DNAT --to-destination ${GATEWAY}
iptables -t nat -I POSTROUTING -j MASQUERADE

# run forever
while sleep 3600; do :; done
