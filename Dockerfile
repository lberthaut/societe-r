FROM php:8.2-fpm-alpine as php

RUN apk update \
 && apk add --no-cache $PHPIZE_DEPS \
    zsh curl vim git zip unzip build-base bash shadow

COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

RUN install-php-extensions pdo_mysql pgsql pdo_pgsql intl zip apcu @composer

# Symfony cli
RUN curl -1sLf 'https://dl.cloudsmith.io/public/symfony/stable/setup.alpine.sh' | bash
RUN apk add symfony-cli

FROM php as app

ARG GIT_BRANCH=main
ARG GITLAB_TOKEN
ARG UID

COPY docker/php.ini /usr/local/etc/php/conf.d/app.ini
ADD docker/docker-php-entrypoint /usr/local/bin/
RUN chmod +x /usr/local/bin/*

RUN usermod -u ${UID:-1000} www-data

WORKDIR /srv/app

RUN [ -z "$GITLAB_TOKEN" ] && echo 'no git clone' \
    || ( git clone --branch ${GIT_BRANCH} https://gitlab-ci-token:${GITLAB_TOKEN}@gitlab.com/formation-ri7/2022-06-societe-r.git . \
    && symfony composer install --no-progress --no-suggest --no-interaction )

RUN chmod -R 777 /srv/app
RUN git config --global --add safe.directory /srv/app
USER www-data

RUN sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

HEALTHCHECK --interval=1m --timeout=30s --retries=3 CMD exit 0
EXPOSE 9000
CMD ["php-fpm"]

FROM nginx:alpine as nginx

WORKDIR /var/www
COPY docker/nginx.conf /etc/nginx/
COPY --from=app /srv/app /srv/app

HEALTHCHECK --interval=1m --timeout=30s --retries=3 CMD curl --fail http://localhost:80 || exit 1
CMD ["nginx"]
EXPOSE 80