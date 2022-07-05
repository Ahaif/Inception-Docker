#!/bin/bash

mkdir -p $HOME/data/db-data
mkdir -p $HOME/data/www-data
mkdir -p $HOME/data/backup-data
cp -r /var/test /var/www/html/wordpress/
docker-compose up --build
docker-compose down -v
sudo rm -rf $HOME/data
