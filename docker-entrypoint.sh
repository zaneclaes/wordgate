#!/bin/sh
set -euo pipefail

# Support sub-directories.
s3_path=${WG_S3_PATH:-}
if [[ ! -z "$s3_path" ]]; then
  s3_path="${s3_path}/"
fi

NGINX_PATH="/etc/nginx/conf.d/${WG_SITENAME}.conf"
WG_SERVER_PORT="${WG_SERVER_PORT:-80}"
S3_PATH="s3://${WG_S3_BUCKET}/${s3_path}${WG_SITENAME}"
HTML_PATH="/var/www/html/${WG_SITENAME}"
CRON_SCHEDULE=${CRON_SCHEDULE:-* * * * *}
BACKUP_MODE=${WG_BACKUP_MODE:-'zip sync'}
RESTORE_MODE=${WG_RESTORE_MODE:-'zip'}

# Configure Nginx
echo "Wordgate Configuring ${WG_SITENAME} for nginx at ${NGINX_PATH} on port ${WG_FPM_PORT}..."
cp /usr/local/wordpress-template.conf $NGINX_PATH
sed -i "s/{{WG_SITENAME}}/${WG_SITENAME}/g" $NGINX_PATH
sed -i "s/{{WG_SERVER_NAME}}/${WG_SERVER_NAME}/g" $NGINX_PATH
sed -i "s/{{WG_SERVER_NAME}}/${WG_SERVER_PORT}/g" $NGINX_PATH
sed -i "s/{{WG_FPM_HOST}}/${WG_FPM_HOST:-localhost}/g" $NGINX_PATH
sed -i "s/{{WG_FPM_PORT}}/${WG_FPM_PORT}/g" $NGINX_PATH
sed -i "s/listen = 127.0.0.1:9000/listen = 127.0.0.1:${WG_FPM_PORT}/g" /usr/local/etc/php-fpm.d/www.conf
sed -i "s/listen = 127.0.0.1:9000/listen = 127.0.0.1:${WG_FPM_PORT}/g" /usr/local/etc/php-fpm.d/www.conf.default
sed -i "s/9000/${WG_FPM_PORT}/g" /usr/local/etc/php-fpm.d/zz-docker.conf

# Restore (sync) the files from the bucket to the local HTML folder.
if [[ $RESTORE_MODE = 'zip' ]]; then
  fn="/usr/local/${WG_SITENAME}.zip"
  rm -rf "$fn" || true
  echo "$fn requires downloading from ${S3_PATH}.zip..."
  aws s3 cp "$S3_PATH.zip" $fn
  echo "Extracting $fn to ${HTML_PATH}..."
  unzip -q -o "$fn" -d "${HTML_PATH}"
  echo "Removing $fn..."
  rm -rf "$fn" || true
elif [[ $RESTORE_MODE = 'sync' ]]; then
  echo "Wordgate Syncing wordpress content from ${S3_PATH}..."
  aws s3 sync "$S3_PATH/" "${HTML_PATH}/" --delete --quiet
else
  echo "Unknown restore mode: ${RESTORE_MODE}"
  exit 1
fi
chown -Rf www-data.www-data $HTML_PATH

# Replace WP config variables which may vary between environments.
WP_CONFIG="${HTML_PATH}/wp-config.php"
echo "Wordgate Configuring wordpress at ${WP_CONFIG}..."
sed -i "s/'DB_PASSWORD',.*'.*'/'DB_PASSWORD', '${WORDPRESS_DB_PASSWORD}'/g" $WP_CONFIG
sed -i "s/'DB_HOST',.*'.*'/'DB_HOST', '${WORDPRESS_DB_HOST:-localhost}'/g" $WP_CONFIG
sed -i "s/'DB_USER',.*'.*'/'DB_USER', '${WORDPRESS_DB_USER:-root}'/g" $WP_CONFIG
sed -i "s/'DB_NAME',.*'.*'/'DB_NAME', '${WORDPRESS_DB_NAME:-wordpress}'/g" $WP_CONFIG

# Schedule the cron job to back up to S3
echo "Wordgate Scheduling backups..."
echo "$CRON_SCHEDULE /usr/local/bin/backup.sh \"$BACKUP_MODE\" \"$WG_SITENAME\" \"$S3_PATH\" >> /dev/stdout" >> /usr/local/backup.txt
/usr/bin/crontab /usr/local/backup.txt
echo "Wordgate Starting cron daemon..."
/usr/sbin/crond -f &

# Finally, call the original entrypoint from Wordpress.
echo "Wordgate Starting wordpress w/ $@."
exec /usr/local/bin/orig-entrypoint.sh "$@"
