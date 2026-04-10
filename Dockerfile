FROM arm64v8/ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC

RUN apt-get update && \
    apt-get install -y software-properties-common && \
    add-apt-repository ppa:ondrej/php && \
    apt-get update && \
    apt-get install -y \
        apache2 \
        php8.1 php8.1-cli php8.1-gd php8.1-mysqli php8.1-pdo php8.1-snmp \
        php8.1-mbstring php8.1-curl php8.1-zip php8.1-xml php8.1-bcmath \
        mariadb-client \
        snmp snmpd snmp-mibs-downloader \
        fping \
        rrdtool \
        subversion \
        wget \
        iputils-ping \
        nano \
        cron \
        supervisor \
        libapache2-mod-php8.1 \
        tzdata \
    && rm -rf /var/lib/apt/lists/*

RUN echo "date.timezone = UTC" >> /etc/php/8.1/apache2/php.ini && \
    echo "date.timezone = UTC" >> /etc/php/8.1/cli/php.ini

WORKDIR /opt
RUN wget http://www.observium.org/observium-community-latest.tar.gz && \
    tar zxvf observium-community-latest.tar.gz && \
    rm observium-community-latest.tar.gz

WORKDIR /opt/observium
RUN cp config.php.default config.php && \
    mkdir -p /opt/observium/logs /opt/observium/rrd && \
    chown -R www-data:www-data /opt/observium

RUN a2enmod rewrite && \
    a2dissite 000-default.conf && \
    echo '<VirtualHost *:80>\n\
    DocumentRoot /opt/observium/html/\n\
    <Directory "/opt/observium/html/">\n\
        Options FollowSymLinks MultiViews\n\
        AllowOverride All\n\
        Require all granted\n\
    </Directory>\n\
    ErrorLog ${APACHE_LOG_DIR}/error.log\n\
    CustomLog ${APACHE_LOG_DIR}/access.log combined\n\
</VirtualHost>' > /etc/apache2/sites-available/observium.conf && \
    a2ensite observium.conf

RUN mkdir -p /var/log/supervisor && \
    echo '[supervisord]\nnodaemon=true\n\n[program:apache2]\ncommand=/usr/sbin/apache2ctl -DFOREGROUND\n\n[program:cron]\ncommand=/usr/sbin/cron -f\n' > /etc/supervisor/conf.d/observium.conf

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

COPY observium.cron /etc/cron.d/observium
RUN chmod 644 /etc/cron.d/observium

EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
