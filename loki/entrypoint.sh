#!/bin/sh
set -e

# Substitute environment variables in config
envsubst < /etc/loki/config.template.yml > /etc/loki/loki.yml

# Start Loki
exec /usr/bin/loki -config.file=/etc/loki/loki.yml "$@"
