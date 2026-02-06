# Injects .env values into loki/config.yml > into Docker Container

#!/bin/bash
set -e

# cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  echo "❌ .env file not found"
  exit 1
fi

# Load env safely
export $(grep -v '^#' .env | grep -v '^$' | xargs)

# Sanity check
: "${LOKI_S3_ACCESS_KEY:?Missing}"
: "${LOKI_S3_SECRET_KEY:?Missing}"

echo "🔧 Generating Loki config..."
envsubst < loki/config.yml.template > loki/config.yml

echo "✅ Loki config generated"

