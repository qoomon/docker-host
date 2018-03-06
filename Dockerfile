FROM alpine:latest

RUN apk --update add iptables bind-tools && rm -rf /var/cache/apk/*

COPY ./entrypoint.sh /

ENV PORTS=0:65535
ENTRYPOINT ["/entrypoint.sh"]
