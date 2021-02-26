FROM alpine:3.12

RUN apk --update --no-cache add iptables libcap

COPY ./entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]
