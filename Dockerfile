FROM php:7.3-apache
# Build the complete image
RUN set -ex; \
    \
    savedAptMark="$(apt-mark showmanual)"; \
    \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        libjpeg-dev \
        libpng-dev \
        libfreetype6-dev \
    ; \
    docker-php-ext-configure pdo_mysql --with-pdo-mysql=mysqlnd; \
    docker-php-ext-configure mysqli --with-mysqli=mysqlnd; \
    docker-php-ext-install pdo_mysql; \
    docker-php-ext-install mysqli; \
    pecl install apcu-stable; \
    docker-php-ext-enable apcu; \
    \
    apt-mark auto '.*' > /dev/null; \
    apt-mark manual $savedAptMark; \
    ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
        | awk '/=>/ { print $3 }' \
        | sort -u \
        | xargs -r dpkg-query -S \
        | cut -d: -f1 \
        | sort -u \
        | xargs -rt apt-mark manual; \
    \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN set -ex; \
    { \
        echo 'realpath_cache_size=4096k'; \
        echo 'realpath_cache_ttl=300'; \
    } > /usr/local/etc/php/conf.d/tuning.ini; 

RUN set -ex; \
    { \
        echo 'date.timezone=UTC'; \
    } > /usr/local/etc/php/conf.d/timezone.ini

RUN set -ex; \
    a2enmod rewrite;

COPY overlay /

ENV FORMALZ_VERSION 1.1.0
ENV FORMALZ_DOWNLOAD_BASE_URL https://github.com/e-ucm/formalz-game/releases/download/${FORMALZ_VERSION}
ENV FORMALZ_DOWNLOAD_URL_BACKEND ${FORMALZ_DOWNLOAD_BASE_URL}/formalz-backend_${FORMALZ_VERSION}.tar.gz
ENV FORMALZ_DOWNLOAD_URL_GAME ${FORMALZ_DOWNLOAD_BASE_URL}/formalz-game_${FORMALZ_VERSION}.tar.gz
ENV FORMALZ_DOWNLOAD_URL_PATHS ${FORMALZ_DOWNLOAD_BASE_URL}/formalz-paths.tar.gz
ENV FORMALZ_BACKEND_SHA256 ab4dca38d2953526349fd0a2bafcc059a8e86d4c30319dc128105f740c84589c
ENV FORMALZ_GAME_SHA256 6e5cad0b55edd474e2b0b3a445189c1a22bef668581f0b8b1200c55beed1d393
ENV FORMALZ_PATHS_SHA256 46f7a9f30cf87e542c13a5b53af2f1de709a904433c227a0399a559113063bf1

RUN set -ex; \
    curl -fsSL "$FORMALZ_DOWNLOAD_URL_BACKEND" -o /tmp/formalz-backend.tar.gz; \
    echo "$FORMALZ_BACKEND_SHA256 /tmp/formalz-backend.tar.gz" | sha256sum -c -; \
    curl -fsSL "$FORMALZ_DOWNLOAD_URL_GAME" -o /tmp/formalz-game.tar.gz; \
    echo "$FORMALZ_GAME_SHA256 /tmp/formalz-game.tar.gz" | sha256sum -c -; \
    curl -fsSL "$FORMALZ_DOWNLOAD_URL_PATHS" -o /tmp/formalz-paths.tar.gz; \
    echo "$FORMALZ_PATHS_SHA256 /tmp/formalz-paths.tar.gz" | sha256sum -c -; \
    mkdir /app; \
    tar -xzf /tmp/formalz-backend.tar.gz --strip-components=1 -C /app > /dev/null 2>&1; \
    tar -xzf /tmp/formalz-game.tar.gz --strip-components=1 -C /app/public > /dev/null 2>&1; \
    tar -xzf /tmp/formalz-paths.tar.gz -C /app/resources > /dev/null 2>&1; \
    chown www-data: -R /app; \
    rm -fr /tmp/*;

VOLUME ["/app/storage"]

EXPOSE 8080

ENTRYPOINT ["/usr/bin/entrypoint"]
CMD ["/usr/bin/server", "start"]