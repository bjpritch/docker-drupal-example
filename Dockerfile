# Docker - Customer Portal Drupal
# 
# VERSION       dev
# Use RHEL 7 image as the base image for this build.  
# Depends on subscription-manager correctly being setup on the RHEL 7 host VM that is building this image
# With a correctly setup RHEL 7 host with subscriptions, those will be fed into the docker image build and yum repos 
# will become available
FROM    rhel7:latest
MAINTAINER Ben Pritchett <bjpritch@redhat.com>

# Install all the necessary packages for Drupal and our application.  Immediately yum update and yum clean all in this step
# to save space in the image
RUN yum -y --enablerepo rhel-7-server-optional-rpms install tar wget git httpd php python-setuptools vim php-dom php-gd memcached php-pecl-memcache mc gcc make php-mysql mod_ssl php-soap hostname rsyslog php-mbstring; yum -y update; yum clean all

# Still need drush installed
RUN pear channel-discover pear.drush.org && pear install drush/drush

# Install supervisord (since this image runs without systemd)
RUN easy_install supervisor
RUN chown -R apache:apache /usr/sbin/httpd
RUN chown -R memcached:memcached /usr/bin/memcached
RUN chown -R apache:apache /var/log/httpd

# we run Drupal with a memory_limit of 512M
RUN sed -i "s/memory_limit = 128M/memory_limit = 512M/" /etc/php.ini
# we run Drupal with an increased file size upload limit as well
RUN sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 100M/" /etc/php.ini
RUN sed -i "s/post_max_size = 8M/post_max_size = 100M/" /etc/php.ini

# we comment out this rsyslog config because of a known bug (https://bugzilla.redhat.com/1088021)
RUN sed -i "s/$OmitLocalLogging on/#$OmitLocalLogging on/" /etc/rsyslog.conf

# Uses the drush make file in this Docker repo to correctly install all the modules we need
# https://www.drupal.org/project/drush_make
ADD drupal.make /tmp/drupal.make

# Add a drushrc file to point to default site
ADD drushrc.php /etc/drush/drushrc.php

# Install registry rebuild tool.  This is helpful when your Drupal registry gets 
# broken from moving modules around
RUN drush @none dl registry_rebuild --nocolor

# Install Drupal via drush.make.
RUN rm -rf /var/www/html ; drush make /tmp/drupal.make /var/www/html --nocolor;

# Do some miscellaneous cleanup of the Drupal file system.  If certain files are volume linked into the container (via -v at runtime)
# some of these files will get overwritten inside the container
RUN chmod 664 /var/www/html/sites/default && mkdir -p /var/www/html/sites/default/files/tmp && mkdir /var/www/html/sites/default/private && chmod 775 /var/www/html/sites/default/files && chmod 775 /var/www/html/sites/default/files/tmp && chmod 775 /var/www/html/sites/default/private
RUN chown -R apache:apache /var/www/html

# Pull in our custom code for the Customer Portal Drupal application
RUN git clone $INTERNAL_GIT_REPO /opt/drupal-custom

# Put our custom code in the appropriate places on disk
RUN ln -s /opt/drupal-custom/all/themes/kcs /var/www/html/sites/all/themes/kcs
RUN ln -s /opt/drupal-custom/all/modules/custom /var/www/html/sites/all/modules/custom
RUN ln -s /opt/drupal-custom/all/modules/features /var/www/html/sites/all/modules/features
RUN rm -rf /var/www/html/sites/all/libraries
RUN ln -s /opt/drupal-custom/all/libraries /var/www/html/sites/all/

# get version 0.8.0 of raven-php.  This is used for integration with Sentry
RUN git clone https://github.com/getsentry/raven-php.git /opt/raven; cd /opt/raven; git checkout d4b741736125f2b892e07903cd40450b53479290
RUN ln -s /opt/raven /var/www/html/sites/all/libraries/raven

# Add all our config files from the Docker build repo
ADD supervisord /etc/supervisord.conf
ADD drupal.conf /etc/httpd/conf.d/site.conf
ADD ssl_extras.conf /etc/httpd/conf.d/ssl.conf
ADD docker-start.sh /docker-start.sh
ADD drupal-rsyslog.conf /etc/rsyslog.d/drupal.conf
USER root

CMD ["/bin/bash", "/docker-start.sh"]
