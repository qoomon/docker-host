GATEWAY=$(ip route | grep '^default' | cut -d' ' -f3)

echo "GATEWAY $GATEWAY"

iptables -t nat -I PREROUTING -p tcp -j DNAT --to-destination ${GATEWAY}
iptables -t nat -I POSTROUTING -j MASQUERADE

# run forever
while sleep 3600; do :; done
