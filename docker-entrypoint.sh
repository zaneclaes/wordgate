#!/bin/sh
set -euo pipefail

S3_PATH="s3://${WG_S3_BUCKET}/${WG_S3_PATH}"

# Restore (sync) the files from the bucket to the local HTML folder.
echo "Syncing wordpress content from ${S3_PATH}..."
HTML_PATH="/var/www/html/"
aws s3 sync "$S3_PATH" "$HTML_PATH"
chown -Rf www-data.www-data $HTML_PATH

# https://github.com/ocastastudios/docker-sync-s3/blob/master/start.sh
# CRON_SCHEDULE=${CRON_SCHEDULE:-*/5 * * * *}
# echo "$CRON_SCHEDULE aws s3 sync \"$HTML_PATH\" \"$S3_PATH\"" | crontab -
# exec cron -f

echo "Starting wordpress w/ $@."
exec /usr/local/bin/orig-entrypoint.sh "$@"
