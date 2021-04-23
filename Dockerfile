FROM alpine:3.13

RUN apk add --update --no-cache \
  iptables \
  libcap

COPY ./entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]
