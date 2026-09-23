#!/bin/sh
# Railway runs this image entrypoint. Do not override it with a start command:
# a custom start command replaces ENTRYPOINT, and a process that is not bound
# to 0.0.0.0:$PORT makes the public URL return 502.
set -eu

port="${PORT:-15080}"
echo "starting readium on 0.0.0.0:${port}" >&2

if [ -z "${R2_ENDPOINT:-}" ] || [ -z "${R2_ACCESS_KEY_ID:-}" ] || [ -z "${R2_SECRET_ACCESS_KEY:-}" ]; then
  echo "missing R2_ENDPOINT, R2_ACCESS_KEY_ID, or R2_SECRET_ACCESS_KEY" >&2
  exit 1
fi

exec /opt/readium serve \
  -s s3,http,https \
  --address 0.0.0.0 \
  --port "$port" \
  --s3-endpoint "$R2_ENDPOINT" \
  --s3-access-key "$R2_ACCESS_KEY_ID" \
  --s3-secret-key "$R2_SECRET_ACCESS_KEY" \
  --s3-region "${R2_REGION:-auto}" \
  --s3-use-path-style
