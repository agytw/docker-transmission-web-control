# Inspired by https://github.com/PHLAK/docker-transmission

FROM alpine:3.9

# Define the authentication user and password
ENV TR_AUTH="transmission:transmission"

# Define a healthcheck
HEALTHCHECK --timeout=5s CMD transmission-remote --authenv --session-info

# Create directories
RUN mkdir -pv /etc/transmission-daemon/blocklists \
    /vol/downloads/.incomplete /vol/watchdir

# Create non-root user
RUN adduser -DHs /sbin/nologin transmission

# Add settings file
COPY files/settings.json /etc/transmission-daemon/settings.json

# Install packages and dependencies
RUN apk add --update curl transmission-cli transmission-daemon tzdata \
    && rm -rf /var/cache/apk/*

# Install initial blocklist
ARG BLOCKLIST_URL="http://list.iblocklist.com/?list=bt_level1&fileformat=p2p&archiveformat=gz"
RUN curl -sL ${BLOCKLIST_URL} | gunzip > /etc/transmission-daemon/blocklists/bt_level1 \
    && chown -R transmission:transmission /etc/transmission-daemon

# Create bolcklist-update cronjob
COPY files/blocklist-update /etc/periodic/hourly/blocklist-update
RUN chmod +x /etc/periodic/hourly/blocklist-update

# Expose ports
EXPOSE 9091 51413

# Add docker volumes
VOLUME /etc/transmission-daemon

# Install transmission-web-control (https://github.com/ronggang/transmission-web-control)
ADD https://raw.githubusercontent.com/ronggang/transmission-web-control/master/release/install-tr-control.sh /tmp
RUN chmod +x /tmp/install-tr-control.sh
RUN echo 1 | sh /tmp/install-tr-control.sh /usr/share/transmission \
    && rm /tmp/install-tr-control.sh

# Set running user
USER transmission

# Run transmission-daemon as default command
CMD transmission-daemon --foreground --log-info \
    --config-dir /etc/transmission-daemon \
    --download-dir /vol/downloads \
    --incomplete-dir /vol/downloads/.incomplete \
    --watch-dir /vol/watchdir \
    --username ${TR_AUTH%:*} --password ${TR_AUTH#*:}
