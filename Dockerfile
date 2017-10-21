FROM alpine:latest

RUN apk --update add iptables && rm -rf /var/cache/apk/*

COPY ./entrypoint.sh /

ENTRYPOINT ["./entrypoint.sh"]
