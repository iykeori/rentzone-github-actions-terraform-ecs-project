# Use the latest version of the Amazon Linux base image
FROM amazonlinux:2

# Update all installed packages
RUN yum update -y && yum clean all && rm -rf /var/cache/yum

# Install utilities
RUN yum install -y unzip wget git httpd \
    && yum clean all && rm -rf /var/cache/yum

# Install PHP and extensions
RUN amazon-linux-extras enable php7.4 && \
    yum clean metadata && \
    yum install -y \
      php php-common php-pear php-cgi php-curl php-mbstring \
      php-gd php-mysqlnd php-gettext php-json php-xml php-fpm \
      php-intl php-zip \
    && yum clean all && rm -rf /var/cache/yum

# Download the MySQL repository package
RUN wget https://repo.mysql.com/mysql80-community-release-el7-3.noarch.rpm

# Import the GPG key for the MySQL repository
RUN rpm --import https://repo.mysql.com/RPM-GPG-KEY-mysql-2023

# Install the MySQL repository package and clean up
RUN yum localinstall -y mysql80-community-release-el7-3.noarch.rpm \
    && rm -f mysql80-community-release-el7-3.noarch.rpm \
    && yum clean all && rm -rf /var/cache/yum

# Install the MySQL community server package and clean up
RUN yum install -y mysql-community-server \
    && yum clean all && rm -rf /var/cache/yum

# Change directory to the html directory
WORKDIR /var/www/html

# Set the build argument directive
ARG PERSONAL_ACCESS_TOKEN
ARG GITHUB_USERNAME
ARG REPOSITORY_NAME
ARG WEB_FILE_ZIP
ARG WEB_FILE_UNZIP
ARG DOMAIN_NAME
ARG RDS_ENDPOINT
ARG RDS_DB_NAME
ARG RDS_DB_USERNAME
ARG RDS_DB_PASSWORD

# Use the build argument to set environment variables
ENV PERSONAL_ACCESS_TOKEN=$PERSONAL_ACCESS_TOKEN
ENV GITHUB_USERNAME=$GITHUB_USERNAME
ENV REPOSITORY_NAME=$REPOSITORY_NAME
ENV WEB_FILE_ZIP=$WEB_FILE_ZIP
ENV WEB_FILE_UNZIP=$WEB_FILE_UNZIP
ENV DOMAIN_NAME=$DOMAIN_NAME
ENV RDS_ENDPOINT=$RDS_ENDPOINT
ENV RDS_DB_NAME=$RDS_DB_NAME
ENV RDS_DB_USERNAME=$RDS_DB_USERNAME
ENV RDS_DB_PASSWORD=$RDS_DB_PASSWORD

# Clone the GitHub repository
RUN git clone https://$PERSONAL_ACCESS_TOKEN@github.com/$GITHUB_USERNAME/$REPOSITORY_NAME.git

# Unzip the zip folder containing the web files
RUN unzip $REPOSITORY_NAME/$WEB_FILE_ZIP -d $REPOSITORY_NAME/

# Copy the web files into the HTML directory
RUN cp -av $REPOSITORY_NAME/$WEB_FILE_UNZIP/. /var/www/html

# Remove the repository we cloned
RUN rm -rf $REPOSITORY_NAME

# Enable the mod_rewrite setting in the httpd.conf file
RUN sed -i '/<Directory "\/var\/www\/html">/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /etc/httpd/conf/httpd.conf

# Give full access to the /var/www/html directory
RUN chmod -R 777 /var/www/html

# Give full access to the storage directory
RUN chmod -R 777 storage/

# Update .env file
RUN sed -i '/^APP_ENV=/ s/=.*$/=production/' .env
RUN sed -i "/^APP_URL=/ s/=.*$/=https:\/\/$DOMAIN_NAME\//" .env
RUN sed -i "/^DB_HOST=/ s/=.*$/=$RDS_ENDPOINT/" .env
RUN sed -i "/^DB_DATABASE=/ s/=.*$/=$RDS_DB_NAME/" .env 
RUN sed -i "/^DB_USERNAME=/ s/=.*$/=$RDS_DB_USERNAME/" .env
RUN sed -i "/^DB_PASSWORD=/ s/=.*$/=$RDS_DB_PASSWORD/" .env

# Copy the file, AppServiceProvider.php
COPY AppServiceProvider.php app/Providers/AppServiceProvider.php

# Expose Apache and MySQL ports
EXPOSE 80 3306

# Start Apache in foreground
ENTRYPOINT ["/usr/sbin/httpd", "-D", "FOREGROUND"]
