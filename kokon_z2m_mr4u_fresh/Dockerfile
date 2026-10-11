# Supervisor local-build image. The wrapper release is 2.14.2-4; Zigbee2MQTT
# itself remains pinned to the existing upstream 2.14.2-1 amd64 image.
FROM ghcr.io/zigbee2mqtt/zigbee2mqtt-amd64:2.14.2-1

LABEL \
  io.hass.version="2.14.2-4" \
  io.hass.type="app" \
  io.hass.arch="amd64"

COPY rootfs /
RUN chmod 755 /docker-entrypoint.sh
