FROM ubuntu:24.04

# Runtime dependencies: download tooling (curl/wget), xz/tar for artifacts,
# gettext-base for envsubst, CA certs for HTTPS, tzdata for TZ, libatomic1 for FXServer.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl wget ca-certificates xz-utils tar gettext-base tzdata libatomic1 \
    && rm -rf /var/lib/apt/lists/*

# Non-root user (SPECS §9). uid 1000 lines up with the default host user for bind mounts.
# ubuntu:24.04 ships a default "ubuntu" user already holding uid 1000 — drop it first.
RUN userdel -r ubuntu 2>/dev/null || true \
    && useradd --uid 1000 --create-home --shell /bin/bash fivem \
    && mkdir -p /opt/fivem/artifacts /opt/fivem/config /opt/fivem/txData \
               /opt/fivem/resources /opt/fivem/logs \
    && chown -R fivem:fivem /opt/fivem

WORKDIR /opt/fivem

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER fivem

# Game (TCP+UDP) and txAdmin web port.
EXPOSE 30120/tcp 30120/udp 40120/tcp

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
