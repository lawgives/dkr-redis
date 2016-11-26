FROM library/redis:3.2.5-alpine
MAINTAINER Ho-Sheng Hsiao <hosh@legal.io>

# Base image is the official Redis library, which
# contians a custom-compiled version of Redis
RUN apk add -U --no-cache sed bash

ADD etc/redis /etc/redis
ADD bin/entrypoint.sh /opt/bin/entrypoint.sh

VOLUME /data
ENTRYPOINT "/opt/bin/entrypoint.sh"
CMD [""]
