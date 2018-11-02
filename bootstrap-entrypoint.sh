#!/bin/sh
set -euo pipefail

if [[ -z "${WP_S3_BUCKET}" ]]; then
  echo "No WP_S3_BUCKET env var."
  exit 126
fi

# Restore (sync) the files from the bucket to the local HTML folder.
echo "Syncing wordpress content from ${WP_S3_BUCKET}..."
# aws s3 sync ...
chown -Rf www-data.www-data /var/www/html/

echo "Starting wordpress w/ $@."
exec /usr/local/bin/orig-entrypoint.sh "$@"
