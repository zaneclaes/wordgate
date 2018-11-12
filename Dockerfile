FROM wordpress:php7.2-fpm-alpine

RUN apk -v --update add \
        python \
        py-pip \
        groff \
        less \
        zip \
        unzip \
        && \
    pip install --upgrade awscli s3cmd python-magic && \
    apk -v --purge del py-pip && \
    rm /var/cache/apk/*

COPY conf/ /usr/local/etc/php/conf.d
COPY wordpress-template.conf /usr/local/wordpress-template.conf
COPY backup.sh /usr/local/bin/backup.sh
RUN chmod +x /usr/local/bin/backup.sh
# RUN ln -s /etc/apache2/mods-available/headers.load /etc/apache2/mods-enabled/

RUN cp /usr/local/bin/docker-entrypoint.sh /usr/local/bin/orig-entrypoint.sh
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh