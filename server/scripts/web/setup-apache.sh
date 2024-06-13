#!/bin/bash

cp "$SCRIPTS/web/conf/apache.conf" /etc/apache2/sites-available/httpd.conf

sudo a2enmod rewrite
sudo a2dissite 000-default #remove apache default site because it interferes with port 80
sudo a2ensite httpd #use the simplified crawl config for serving files on port 80 inside the container
sudo a2enmod cgi
