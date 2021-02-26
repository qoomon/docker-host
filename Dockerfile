FROM alpine:3.13

RUN apk --update --no-cache add iptables libcap

COPY ./entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]
