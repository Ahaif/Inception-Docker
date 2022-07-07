#!/bin/bash

mkdir -p $HOME/data/db-data
mkdir -p $HOME/data/www-data
mkdir -p $HOME/data/backup-data

docker-compose up --build -d
# docker-compose down -v
# sudo rm -rf $HOME/data
