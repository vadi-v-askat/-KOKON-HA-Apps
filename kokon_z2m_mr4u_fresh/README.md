# KOKON Zigbee2MQTT MR4U Fresh

Independent Home Assistant OS app wrapper for a stopped Zigbee2MQTT instance.
The app must be configured with a dedicated MQTT principal, namespace, serial
endpoint and Zigbee identities before its first start.

## Identity

- Source slug: `kokon_z2m_mr4u_fresh`
- Expected installed identity: repository-hash-prefixed source slug (assigned by
  Supervisor when the custom repository is registered)
- Zigbee2MQTT/add-on pin: `2.14.2-1`
- Runtime base image: `ghcr.io/zigbee2mqtt/zigbee2mqtt-amd64:2.14.2-1`
- Data root: `/config/zigbee2mqtt_mr4u_fresh`
- MQTT, coordinator endpoint and credentials: supplied as required Supervisor
  options; none are stored in this repository.
- Adapter: `ember`

The version pin is an upstream release pin, not a floating `latest` reference.
This wrapper uses the supported Supervisor local-build model: no `image` key is
present in `config.yaml`, so Supervisor builds the release `2.14.2-2` wrapper
from its Dockerfile. The Dockerfile explicitly pins the Zigbee2MQTT amd64 base
image to `2.14.2-1`; it does not request a nonexistent `2.14.2-2` upstream
Zigbee2MQTT image.

No public frontend port is mapped: `8099/tcp: null` is internal ingress only.
The wrapper has no `host_network`, privileged, Docker API, udev, USB or device
mapping declarations. The writable `/config` container path is an `app_config`
mapping, so its host backing store is app-specific rather than the shared Home
Assistant configuration root. Exact Supervisor mount readback remains a future
deployment gate.
