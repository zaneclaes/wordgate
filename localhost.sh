#!/bin/sh
docker-compose stop

if [[ -z "$@" ]]; then
  sites=$(ls ~/wordgate/sites | tr '\n' ' ')
  if [[ -z "$sites" ]]; then
    echo "No sites provided as arguments, and no sites detected in ~/worgate/sites"
    exit 1
  else
    ./localhost.sh $sites
    exit 0
  fi
fi

dc="docker-compose.yml"
rm $dc
rm ~/wordgate/nginx/*
cp docker-compose-base.yml $dc
template=$(cat docker-compose-site.yml)
port=9000

for sitename in "$@"; do
  echo "      - ~/wordgate/sites/${sitename}:/var/www/html/${sitename}" >> $dc
done

echo "    links:" >> $dc
for sitename in "$@"; do
  echo "      - ${sitename}" >> $dc
done

echo "    depends_on:" >> $dc
for sitename in "$@"; do
  echo "      - ${sitename}" >> $dc
done

for sitename in "$@"; do
  echo "Configuring ${sitename} on port ${port}"
  echo "$template" >> $dc
  sed -i.bak "s/{{WG_SITENAME}}/${sitename}/g" $dc && rm "$dc.bak"
  sed -i.bak "s/{{WG_FPM_PORT}}/${port}/g" $dc && rm "$dc.bak"
  port=$((port + 1))
done

docker-compose up
