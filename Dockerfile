FROM alpine:3.10

# Define transmission-daemon version
ARG TR_VERSION=2.94-r2

# Define the authentication user and password
ENV TR_AUTH="transmission:transmission"

# Define a healthcheck
HEALTHCHECK --timeout=5s CMD transmission-remote --authenv --session-info

# Create directories; Create running user
RUN mkdir -pv /etc/transmission-daemon/blocklists \
              /vol/downloads/.incomplete \
              /vol/watchdir \
    && adduser -DHs /sbin/nologin transmission

# Add settings file
COPY ./settings.json /etc/transmission-daemon/settings.json

# Install packages and dependencies
RUN apk add --update \
    curl \
    transmission-cli=${TR_VERSION} \
    transmission-daemon=${TR_VERSION} \
    tzdata \
    && rm -rf /var/cache/apk/*

# Install initial blocklist; Update blocklist hourly
ARG BLOCKLIST_URL="http://list.iblocklist.com/?list=bt_level1&fileformat=p2p&archiveformat=gz"
RUN curl -sL ${BLOCKLIST_URL} | gunzip > /etc/transmission-daemon/blocklists/bt_level1 \
    && chown -R transmission:transmission /etc/transmission-daemon \
    && echo -e '#!/usr/bin/env sh \n set -o errexit \n transmission-remote --authenv --blocklist-update > /dev/stdout' > /etc/periodic/hourly/blocklist-update \
    && chmod +x /etc/periodic/hourly/blocklist-update

# Install transmission-web-control (https://github.com/ronggang/transmission-web-control)
RUN curl -o /tmp/install-tr-control.sh -L https://raw.githubusercontent.com/ronggang/transmission-web-control/master/release/install-tr-control.sh \
    && chmod +x /tmp/install-tr-control.sh \
    && echo 1 | sh /tmp/install-tr-control.sh /usr/share/transmission \
    && rm /tmp/install-tr-control.sh

# Expose ports
EXPOSE 9091 51413 51413/udp

# Add docker volumes
VOLUME /etc/transmission-daemon /vol

# Set running user
USER transmission

# Run transmission-daemon as default command
CMD transmission-daemon --foreground --log-info \
    --config-dir /etc/transmission-daemon \
    --download-dir /vol/downloads \
    --incomplete-dir /vol/downloads/.incomplete \
    -c /vol/watchdir \
    -t --username ${TR_AUTH%:*} --password ${TR_AUTH#*:}
