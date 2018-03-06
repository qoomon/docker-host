#!/bin/sh
set -e

macGateway="$(dig +short docker.for.mac.host.internal)"
if [ -z "$macGateway" ]
then
    GATEWAY=$(ip route | grep '^default' | cut -d' ' -f3)
else
    GATEWAY=$macGateway
fi        
echo "Docker Host Gateway: $GATEWAY"

iptables -t nat -I PREROUTING -p tcp --match multiport --dports "${PORTS:-'0:65535'}" -j DNAT --to-destination ${GATEWAY}
iptables -t nat -I POSTROUTING -j MASQUERADE

#run forever
tail -f /dev/null