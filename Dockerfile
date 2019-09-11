FROM debian:buster-slim

# Version Pinning
ENV TR_VERSION="2.94-2"
ENV SUPERCRONIC_URL=https://github.com/aptible/supercronic/releases/download/v0.1.9/supercronic-linux-amd64 \
    SUPERCRONIC=supercronic-linux-amd64 \
    SUPERCRONIC_SHA1SUM=5ddf8ea26b56d4a7ff6faecdd8966610d5cb9d85

# Define the authentication user and password
ENV TR_AUTH="transmission:transmission"

# Define a healthcheck
HEALTHCHECK --timeout=5s CMD transmission-remote --authenv --session-info

# Create directories; Create running user
RUN mkdir -pv /vol/config/blocklists \
    /vol/downloads/.incomplete /vol/watchdir \
    && useradd --system --user-group --shell /bin/false transmission

# Install packages and dependencies
RUN apt-get update && apt-get install -y \
    curl \
    transmission-cli=${TR_VERSION} \
    transmission-daemon=${TR_VERSION} \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

# Add settings file
COPY ./settings.json /vol/config/settings.json

# Install initial blocklist
ARG BLOCKLIST_URL="http://list.iblocklist.com/?list=bt_level1&fileformat=p2p&archiveformat=gz"
RUN curl -sL ${BLOCKLIST_URL} | gunzip > /vol/config/blocklists/bt_level1 \
    && chown -R transmission:transmission /vol/config/

# Update blocklist hourly using supercronic (a cron alternative built for containers)
RUN curl -fsSLO "$SUPERCRONIC_URL" \
    && echo "${SUPERCRONIC_SHA1SUM}  ${SUPERCRONIC}" | sha1sum -c - \
    && chmod +x "$SUPERCRONIC" \
    && mv "$SUPERCRONIC" "/usr/local/bin/${SUPERCRONIC}" \
    && ln -s "/usr/local/bin/${SUPERCRONIC}" /usr/local/bin/supercronic \
    && echo "@hourly transmission-remote --authenv --blocklist-update" > /etc/blocklist-update \
    && supercronic /etc/blocklist-update

# Install transmission-web-control (https://github.com/ronggang/transmission-web-control)
RUN curl -o /tmp/install-tr-control.sh -L https://raw.githubusercontent.com/ronggang/transmission-web-control/master/release/install-tr-control.sh \
    && chmod +x /tmp/install-tr-control.sh \
    && echo 1 | sh /tmp/install-tr-control.sh /usr/share/transmission \
    && rm /tmp/install-tr-control.sh

# Expose ports
EXPOSE 9091 51413 51413/udp

# Add docker volumes
VOLUME /vol

# Set running user
USER transmission

# Run transmission-daemon as default command
CMD transmission-daemon --foreground --log-info \
    --config-dir /vol/config \
    --download-dir /vol/downloads \
    --incomplete-dir /vol/downloads/.incomplete \
    -c /vol/watchdir \
    -t --username ${TR_AUTH%:*} --password ${TR_AUTH#*:}
