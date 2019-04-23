#!/bin/sh
set -euo pipefail

# Find HTML modified in the last minute (since this is scheduled on 1-minute interval).
HTML_PATH="/var/www/html/${2}"
modified=$(find "$HTML_PATH" -mmin -1 -type f ! -path '*/mmr/*' ! -path '*/wp-config.php')

if [[ -z "$modified" ]]; then
  exit 0
fi

echo "--------------------"
echo "Beginning '$1' backup of modified files from $2 to $3..."
echo "--------------------"
echo "$modified"
echo "--------------------"
if [[ "$1" = *"zip"* ]]; then
  fn="/usr/local/$2.zip"
  cd "$HTML_PATH"
  echo "[Wordgate] Zipping $HTML_PATH as $fn..."
  zip -r -q "$fn" .
  echo "[Wordgate] Uploading $fn as $3.zip..."
  aws s3 cp "$fn" "$3.zip"
  rm -rf "$fn" || true
fi
if [[ "$1" = *"sync"* ]]; then
  echo "[Wordgate] Syncing $HTML_PATH to $3..."
  aws s3 sync "$HTML_PATH" "$3" --delete --exclude="*.DS_Store" --exclude wp-content/mmr
fi

echo "[Wordgate] All requested backups complete."
