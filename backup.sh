#!/bin/sh
set -euo pipefail

# Find HTML modified in the last minute (since this is scheduled on 1-minute interval).
HTML_PATH="/var/www/html/${2}"
modified=$(find "$HTML_PATH" -mmin -1)

if [[ -z "$modified" ]]; then
  cmd="$HTML_PATH/backup.cmd"
  if [[ -f "$cmd" ]]; then
    echo "Backup request detected at $cmd"
    rm -rf "$cmd"
  else
    exit 0
  fi
fi

echo "Beginning '$1' backup of modified files from $2 to $3..."
# if [[ "$1" = *"zip"* ]]; then
# fi

fn="/usr/local/$2.zip"
cd "$HTML_PATH"
echo "Zipping $HTML_PATH as $fn..."
zip -r -q "$fn" .
echo "Uploading $fn as $3.zip..."
aws s3 cp "$fn" "$3.zip"
rm -rf "$fn" || true

# if [[ "$1" = *"sync"* ]]; then
echo "Syncing $HTML_PATH to $3..."
aws s3 sync "$HTML_PATH" "$3" --delete --exclude="*.DS_Store"
# fi

echo "All requested backups complete."
