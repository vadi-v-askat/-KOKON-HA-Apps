#!/usr/bin/env bashio
# KOKON MR4U wrapper entrypoint. Adapted from the official HA add-on runtime
# contract at hassio-zigbee2mqtt v2.14.2-1; no ZigStar source was used.

set -euo pipefail

bashio::log.info 'Preparing isolated MR4U Zigbee2MQTT instance'
bashio::config.require 'data_path'
bashio::config.require 'mqtt.server'
bashio::config.require 'mqtt.user'
bashio::config.require 'mqtt.password'
bashio::config.require 'mqtt.base_topic'
bashio::config.require 'serial.port'
bashio::config.require 'serial.adapter'
bashio::config.require 'advanced.channel'
bashio::config.require 'advanced.pan_id'
bashio::config.require 'advanced.ext_pan_id'
bashio::config.require 'advanced.network_key'
bashio::config.require 'permit_join'
bashio::config.require 'homeassistant.enabled'

DATA_PATH="$(bashio::config 'data_path')"
case "$DATA_PATH" in
  /config/zigbee2mqtt_mr4u_fresh) ;;
  *) bashio::exit.nok 'data_path must be /config/zigbee2mqtt_mr4u_fresh' ;;
esac

mkdir -p "$DATA_PATH" || bashio::exit.nok "Could not create $DATA_PATH"
export ZIGBEE2MQTT_DATA="$DATA_PATH"
export NODE_PATH=/app/node_modules

CONFIG_PATH="${DATA_PATH}/configuration.yaml"

CHANNEL="$(bashio::config 'advanced.channel')"
PAN_ID="$(bashio::config 'advanced.pan_id')"
EXT_PAN_ID="$(bashio::config 'advanced.ext_pan_id')"
NETWORK_KEY="$(bashio::config 'advanced.network_key')"
PERMIT_JOIN="$(bashio::config 'permit_join')"
HA_DISCOVERY="$(bashio::config 'homeassistant.enabled')"

[[ "$CHANNEL" == '25' ]] || bashio::exit.nok 'advanced.channel must be 25'
[[ "$PAN_ID" =~ ^[1-9][0-9]*$ ]] && (( PAN_ID <= 65534 )) || bashio::exit.nok 'advanced.pan_id is invalid'
[[ "$EXT_PAN_ID" =~ ^[0-9A-Fa-f]{16}$ ]] || bashio::exit.nok 'advanced.ext_pan_id must be 16 hexadecimal characters'
[[ "$NETWORK_KEY" =~ ^[0-9A-Fa-f]{32}$ ]] || bashio::exit.nok 'advanced.network_key must be 32 hexadecimal characters'
[[ "$PERMIT_JOIN" == 'false' ]] || bashio::exit.nok 'permit_join must be false before commissioning'
[[ "$HA_DISCOVERY" == 'false' ]] || bashio::exit.nok 'homeassistant.enabled must be false before commissioning'

write_byte_array() {
    local hex="$1"
    local width="$2"
    local index
    for ((index = 0; index < ${#hex}; index += 2)); do
        printf '%*s- %d\n' "$width" '' "$((16#${hex:index:2}))"
    done
}

umask 077

# A pre-existing configuration is the authoritative record of the commissioned
# Zigbee network. Never regenerate it: doing so could replace its PAN, extended
# PAN ID or Network Key. The only mutable startup policy is discovery; it is
# rendered by this wrapper in a stable two-line block and changed atomically.
if [[ -e "$CONFIG_PATH" ]]; then
    [[ -f "$CONFIG_PATH" && ! -L "$CONFIG_PATH" ]] || bashio::exit.nok 'Existing MR4U configuration is not a regular file'
    grep -q '^advanced:$' "$CONFIG_PATH" || bashio::exit.nok 'Existing MR4U configuration lacks advanced network settings'
    grep -q '^  pan_id:' "$CONFIG_PATH" || bashio::exit.nok 'Existing MR4U configuration lacks PAN ID'
    grep -q '^  ext_pan_id:' "$CONFIG_PATH" || bashio::exit.nok 'Existing MR4U configuration lacks Extended PAN ID'
    grep -q '^  network_key:' "$CONFIG_PATH" || bashio::exit.nok 'Existing MR4U configuration lacks Network Key'
    grep -q '^homeassistant:$' "$CONFIG_PATH" || bashio::exit.nok 'Existing MR4U configuration lacks Home Assistant block'
    grep -q '^  enabled: \(true\|false\)$' "$CONFIG_PATH" || bashio::exit.nok 'Existing Home Assistant setting is invalid'
    grep -q '^permit_join: \(true\|false\)$' "$CONFIG_PATH" || bashio::exit.nok 'Existing permit_join setting is invalid'
    CONFIG_TMP="$(mktemp "${DATA_PATH}/.configuration.yaml.XXXXXX")" || bashio::exit.nok 'Could not allocate configuration update'
    awk -v enabled="$HA_DISCOVERY" '
        $0 == "homeassistant:" {
            print
            if (getline != 1 || $0 !~ /^  enabled: (true|false)$/) exit 42
            print "  enabled: " enabled
            next
        }
        $0 ~ /^permit_join: (true|false)$/ {
            print "permit_join: false"
            next
        }
        { print }
    ' "$CONFIG_PATH" > "$CONFIG_TMP" || { rm -f "$CONFIG_TMP"; bashio::exit.nok 'Could not update Home Assistant discovery'; }
    chmod 600 "$CONFIG_TMP"
    mv "$CONFIG_TMP" "$CONFIG_PATH" || bashio::exit.nok 'Could not finalize Home Assistant discovery update'
else
CONFIG_TMP="$(mktemp "${DATA_PATH}/.configuration.yaml.XXXXXX")" || bashio::exit.nok 'Could not allocate configuration file'
{
    cat <<EOF
mqtt:
  server: '$(bashio::config 'mqtt.server')'
  user: '$(bashio::config 'mqtt.user')'
  password: '$(bashio::config 'mqtt.password')'
  base_topic: '$(bashio::config 'mqtt.base_topic')'
serial:
  port: '$(bashio::config 'serial.port')'
  adapter: '$(bashio::config 'serial.adapter')'
advanced:
  channel: ${CHANNEL}
  pan_id: ${PAN_ID}
  ext_pan_id:
EOF
    write_byte_array "$EXT_PAN_ID" 4
    printf '%s\n' '  network_key:'
    write_byte_array "$NETWORK_KEY" 4
    cat <<EOF
frontend:
  enabled: true
  port: 8099
homeassistant:
  enabled: false
permit_join: false
EOF
} > "$CONFIG_TMP" || {
    rm -f "$CONFIG_TMP"
    bashio::exit.nok 'Could not write MR4U configuration'
}
chmod 600 "$CONFIG_TMP"
mv "$CONFIG_TMP" "$CONFIG_PATH" || bashio::exit.nok 'Could not finalize MR4U configuration'
fi

if bashio::config.has_value 'watchdog'; then
    export Z2M_WATCHDOG="$(bashio::config 'watchdog')"
fi

export TZ="$(bashio::supervisor.timezone)"
bashio::log.info 'Starting Zigbee2MQTT MR4U wrapper with prevalidated configuration'
cd /app
exec node index.js
