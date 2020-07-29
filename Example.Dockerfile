#FROM somewhere
FROM php:7.3.19-fpm-alpine3.11 AS base

FROM base AS build

WORKDIR /www

RUN set -eux; \
    apk update && apk upgrade; \
    \
    apk add --no-cache --virtual .build-deps \
    autoconf \
    ca-certificates \
    curl \
    g++ \
    gcc \
    git \
    libzip-dev \
    openldap-dev \
    make \
    zlib-dev; \
    \
    docker-php-ext-install -j$(nproc) pdo pdo_mysql opcache ldap zip; \
    pecl install redis-5.2.2; \
    docker-php-ext-enable redis;\
    rm -rf /var/cache/apk/*; \
    rm -rf /tmp/*; \
    apk del .build-deps;

FROM base AS app


COPY --from=build /usr/local/lib/php/extensions/no-debug-non-zts-20180731 /usr/local/lib/php/extensions/no-debug-non-zts-20180731

RUN set -eux; \
    apk add --no-cache \
    libzip \
    openldap; \
    \
    docker-php-ext-enable ldap opcache pdo_mysql redis zip; \
    rm -rf /var/cache/apk/*;

# Composer install
COPY --from=composer:1.9 /usr/bin/composer /usr/local/bin/composer

FROM app AS deps

RUN apk add --no-cache git; \
    rm -rf /tmp/*

WORKDIR /tmp/composer

COPY composer.* /tmp/composer/
# ignore package req for composer, since this is only building stage may or may not fullfill requement
RUN set -eux; \
    composer global require hirak/prestissimo --no-ansi --no-progress; \
    composer install --no-autoloader --no-suggest --ignore-platform-reqs --no-ansi --no-progress


# app build section
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


