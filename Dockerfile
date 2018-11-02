FROM wordpress:latest

RUN apt-get update && apt-get install -y zip unzip

COPY conf/ /usr/local/etc/php/conf.d
RUN ln -s /etc/apache2/mods-available/headers.load /etc/apache2/mods-enabled/

RUN cp /usr/local/bin/docker-entrypoint.sh /usr/local/bin/orig-entrypoint.sh
COPY bootstrap-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh