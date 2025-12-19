FROM php:8.3-apache

# Install the PHP extensions required for TastyIgniter
RUN set -ex; \
	\
	apt-get update; \
	apt-get install -y \
		unzip \
		openssl \
		libcurl4-openssl-dev \
		libjpeg-dev \
		libpng-dev \
		libmcrypt-dev \
		libxml2-dev \
		libonig-dev \
		libzip-dev \
		libfreetype6-dev \
		libicu-dev \
		certbot \
		python3-certbot-apache \
		cron \
		gettext-base \
	; \
	rm -rf /var/lib/apt/lists/*; \
	\
	docker-php-ext-configure gd --with-jpeg --with-freetype; \
	docker-php-ext-configure intl; \
	docker-php-ext-install -j$(nproc) pdo_mysql curl dom gd mbstring xml zip exif intl opcache

# Install redis extension using install-php-extensions (more reliable than pecl)
ADD --chmod=0755 https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/
RUN install-php-extensions redis

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=2'; \
		echo 'opcache.fast_shutdown=1'; \
		echo 'opcache.enable_cli=1'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini

RUN a2enmod rewrite ssl headers

# Configure Apache DocumentRoot to public folder (Laravel/TastyIgniter v4 structure)
ENV APACHE_DOCUMENT_ROOT /var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf
RUN sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

# Set COMPOSER_HOME for www-data user to fix composer require issues
ENV COMPOSER_HOME /var/www/.composer
RUN mkdir -p /var/www/.composer && chown www-data:www-data /var/www/.composer

# Allow .htaccess overrides
RUN sed -i '/<Directory \/var\/www\/>/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf

ENV TASTYIGNITER_VERSION 4.0.4

# Download TastyIgniter from GitHub
RUN set -ex; \
	curl -o tastyigniter.zip -fSL "https://github.com/tastyigniter/TastyIgniter/archive/refs/tags/v${TASTYIGNITER_VERSION}.zip"; \
	unzip tastyigniter.zip -d /usr/src/; \
	rm tastyigniter.zip; \
	mv /usr/src/TastyIgniter-${TASTYIGNITER_VERSION} /usr/src/tastyigniter

COPY .htaccess /usr/src/tastyigniter/public/

# Install Composer and dependencies
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && \
    cd /usr/src/tastyigniter && composer install --no-dev --optimize-autoloader

# Copy TastyIgniter to web root
RUN cp -r /usr/src/tastyigniter/. /var/www/html/ && \
    chown -R www-data:www-data /var/www/html

COPY docker-entrypoint.sh /usr/local/bin/
COPY init-ssl.sh /usr/local/bin/
COPY apache-ssl.conf.template /etc/apache2/

RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/init-ssl.sh

WORKDIR /var/www/html

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["apache2-foreground"]
