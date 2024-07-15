# syntax=docker/dockerfile:1
FROM alpine:3.20.1

RUN apk --no-cache upgrade \
 && apk --no-cache add  \
    nftables \
    libcap

COPY ./entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]
