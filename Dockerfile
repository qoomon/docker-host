# syntax=docker/dockerfile:1
FROM alpine:3.20.2

RUN apk --no-cache upgrade \
 && apk --no-cache add  \
    # nftables \
    iptables iptables-legacy \
    libcap

COPY ./entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]
