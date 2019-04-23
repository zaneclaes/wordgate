#!/bin/sh
set -euo pipefail

# Support sub-directories.
s3_path=${WG_S3_PATH:-}
if [[ ! -z "$s3_path" ]]; then
  s3_path="${s3_path}/"
fi

sitename="${1}"
servername="${2}"
fpm_port="${3}"

NGINX_PATH="/etc/nginx/conf.d/${sitename}.conf"
S3_PATH="s3://${WG_S3_BUCKET}/${s3_path}${sitename}"
HTML_PATH="/var/www/html/${sitename}"
CRON_SCHEDULE=${CRON_SCHEDULE:-* * * * *}
BACKUP_MODE=${WG_BACKUP_MODE:-'sync'}
RESTORE_MODE=${WG_RESTORE_MODE:-'sync'}

# Configure Nginx
cp -f /usr/local/etc/templates/wordpress-nginx.conf.template $NGINX_PATH
sed -i "s~{{WG_NGINX_ACCESS_LOG}}~${WG_NGINX_ACCESS_LOG:-/dev/stdout}~g" $NGINX_PATH
sed -i "s~{{WG_NGINX_ERROR_LOG}}~${WG_NGINX_ERROR_LOG:-/dev/stderr}~g" $NGINX_PATH
sed -i "s/{{WG_SITENAME}}/${sitename}/g" $NGINX_PATH
sed -i "s/{{WG_SERVER_NAME}}/${servername}/g" $NGINX_PATH
sed -i "s/{{WG_SERVER_PORT}}/${WG_SERVER_PORT:-80}/g" $NGINX_PATH
sed -i "s/{{WG_FPM_PORT}}/${fpm_port}/g" $NGINX_PATH

cf="/usr/local/etc/php-fpm.d/${sitename}.conf"
cp -f /usr/local/etc/templates/wordpress-fpm.conf.template $cf
sed -i "s/{{WG_FPM_PORT}}/${fpm_port}/g" $cf
sed -i "s/{{WG_SITENAME}}/${sitename}/g" $cf

cf="/usr/local/etc/php-fpm.d/docker.conf"
echo "[${sitename}]" >> $cf
echo "access.log = ${WG_FPM_ACCESS_LOG:-/dev/stdout}" >> $cf
echo "clear_env = no" >> $cf
echo "catch_workers_output = yes" >> $cf

cf="/usr/local/etc/php-fpm.d/zz-docker.conf"
echo "[${sitename}]" >> $cf
echo "listen = ${fpm_port}" >> $cf

# Restore (sync) the files from the bucket to the local HTML folder.
if [[ $RESTORE_MODE = 'zip' ]]; then
  fn="/usr/local/${sitename}.zip"
  rm -rf "$fn" || true
  echo "[Wordgate] downloading backup from ${S3_PATH}.zip..."
  aws s3 cp "$S3_PATH.zip" $fn
  unzip -q -o "$fn" -d "${HTML_PATH}"
  rm -rf "$fn" || true
elif [[ $RESTORE_MODE = 'sync' ]]; then
  echo "[Wordgate] Syncing wordpress content from $S3_PATH/ to ${HTML_PATH}/..."
  if [[ ! -d $HTML_PATH ]]; then
    # When the directory does not exist, sync quietly to prevent log spam.
    aws s3 sync "$S3_PATH/" "${HTML_PATH}/" --delete --exclude "*/mmr/*" --exclude "*.DS_Store" --quiet
  else
    aws s3 sync "$S3_PATH/" "${HTML_PATH}/" --delete --exclude "*/mmr/*" --exclude "*.DS_Store" # --quiet
  fi
elif [[ $RESTORE_MODE = 'none' ]]; then
  if [[ ! -d "${HTML_PATH}" ]]; then
    echo "[Wordgate] FATAL: no restore mode for ${sitename} and no folder at ${HTML_PATH}."
    exit 127
  fi
  echo "No restore mode selected."
else
  echo "Unknown restore mode: ${RESTORE_MODE}"
  exit 1
fi

# Replace WP config variables which may vary between environments.
# wp_config="${HTML_PATH}/wp-config.php"
# if [[ -f "$wp_config" ]]; then
#   echo "[Wordgate] Configuring wordpress at ${wp_config}..."
#   sed -i "s/'DB_PASSWORD',.*'.*'/'DB_PASSWORD', '${db_pw}'/g" "$wp_config"
#   sed -i "s/'DB_HOST',.*'.*'/'DB_HOST', '${db_host:-localhost}'/g" "$wp_config"
#   sed -i "s/'DB_USER',.*'.*'/'DB_USER', '${db_user:-root}'/g" "$wp_config"
#   sed -i "s/'DB_NAME',.*'.*'/'DB_NAME', '${db_name:-wordpress}'/g" "$wp_config"
# else
#   echo "[Wordgate] no config at ${wp_config}"
# fi

# Schedule the cron job to back up to S3
echo "[Wordgate] Scheduling ${BACKUP_MODE} backups..."
echo "$CRON_SCHEDULE /usr/local/bin/backup.sh \"$BACKUP_MODE\" \"$sitename\" \"$s3_path\" >> /dev/stdout" >> /usr/local/backup.txt
