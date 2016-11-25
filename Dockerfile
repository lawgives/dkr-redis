FROM library/redis:3.2.5-alpine
MAINTAINER Ho-Sheng Hsiao <hosh@legal.io>

# Base image is the official Redis library, which
# contians a custom-compiled version of Redis
RUN apk add -U --no-cache sed bash

ADD etc/redis /etc/redis
# Redis needs to be able to write to configuration files,
# and we are running redis under redis user
RUN chown redis:redis /etc/redis

ADD bin/redis-sentinel /opt/bin/redis-sentinel
