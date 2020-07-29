FROM php:7.4.8-fpm-alpine3.12 AS base

FROM base AS build
WORKDIR /www
RUN set -eux; \
    apk update && apk upgrade; \
    \
    apk add --no-cache --virtual .build-deps  gmp-dev ;\
    docker-php-ext-install -j$(nproc) pdo pdo_mysql opcache gmp; \
    rm -rf /var/cache/apk/*; \
    rm -rf /tmp/*; \
    apk del .build-deps;

FROM base AS app
COPY --from=build /usr/local/lib/php/extensions/no-debug-non-zts-20190902 /usr/local/lib/php/extensions/no-debug-non-zts-20190902
RUN set -eux; \
    apk add --no-cache gmp-dev ;\
    \
    docker-php-ext-enable pdo pdo_mysql opcache gmp; \
    rm -rf /var/cache/apk/*;
COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

FROM app AS deps
RUN apk add --no-cache git; \
    rm -rf /tmp/*
WORKDIR /tmp/composer
COPY composer.* /tmp/composer/
RUN set -eux; \
    composer global require hirak/prestissimo --no-ansi --no-progress; \
    composer install --no-autoloader --no-suggest --ignore-platform-reqs --no-ansi --no-progress


FROM app
VOLUME /auth-logs
USER root
WORKDIR /www
COPY --from=deps /tmp/composer/vendor /www/vendor
COPY . .
RUN set -eux; \
    composer dump --optimize --no-ansi; \
    chmod -R 777 ./storage;

CMD ["php-fpm"]
