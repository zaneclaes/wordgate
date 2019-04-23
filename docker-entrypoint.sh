#!/bin/bash
set -euo pipefail

# Configure the default nginx settings
echo "[Wordgate] configuring nginx..."
mkdir -p /etc/nginx/conf.d
sed -i "s/{{WG_SERVER_PORT}}/${WG_SERVER_PORT:-80}/g" /etc/nginx/conf.d/default.conf

# Configure default docker FPM settings
echo "[Wordgate] configuring fpm..."
cp -f /usr/local/etc/templates/zz-docker.conf "/usr/local/etc/php-fpm.d/zz-docker.conf"
cp -f /usr/local/etc/templates/docker.conf "/usr/local/etc/php-fpm.d/docker.conf"
sed -i "s~{{WG_FPM_ERROR_LOG}}~${WG_FPM_ERROR_LOG:-/dev/stderr}~g" "/usr/local/etc/php-fpm.d/docker.conf"

# Add a config for each wordpress blog
fpm_port=9000
echo "[Wordgate] configuring sites: ${WG_SITES}..."
for sitename in ${WG_SITES[@]}; do
  dv="WG_DOMAIN_${sitename}"
  domains=${!dv}
  echo "[Wordgate] configuring ${sitename} on port ${fpm_port} with domains ${domains}..."
  /usr/local/bin/add-site.sh "$sitename" "$domains" "$fpm_port"
  fpm_port=$((fpm_port+1))
done

echo "[Wordgate] applying ownership/permissions..."
chown -Rf www-data.www-data /var/www/html/

echo "[Wordgate] Starting cron daemon..."
/usr/bin/crontab /usr/local/backup.txt
/usr/sbin/crond -f &

echo "[Wordgate] Starting nginx..."
nginx -g "daemon off;" &

# Finally, call the original entrypoint from Wordpress.
echo "[Wordgate] Starting wordpress w/ $@."
exec /usr/local/bin/orig-entrypoint.sh "$@"
