FROM alpine:3.16

RUN apk --no-cache upgrade \
 && apk --no-cache add  \
    iptables \
    bash \
    libcap

COPY ./entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]
