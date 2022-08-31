# Inception-Docker

This project aims to broaden your knowledge of system administration by using Docker.

we have to virtualize several Docker images, creating them in a virtual machine.

- Each Docker image must have the same name as its corresponding service.

- Each service has to run in a dedicated container.

- For performance matters, the containers must be built either from the penultimate stable
version of Alpine Linux, or from Debian Buster. The choice is yours.

- You also have to write your own Dockerfiles, one per service. The Dockerfiles must
be called in your docker-compose.yml by your Makefile.

It means you have to build yourself the Docker images of your project. It is then forbidden to pull ready-made Docker images, as well as using services such as DockerHub

- (Alpine/Debian being excluded from this rule).

You then have to set up:

- A Docker container that contains NGINX with TLSv1.2 or TLSv1.3 only.
- A Docker container that contains WordPress + php-fpm (it must be installed and
configured) only without nginx.
- A Docker container that contains MariaDB only without nginx.
- A volume that contains your WordPress database.
- A second volume that contains your WordPress website files.
- A docker-network that establishes the connection between your containers.

check Subejct file of the Project for more Infos 




sudo docker rm -f $(sudo docker ps -aq)
sudo docker rmi -f $(sudo docker images -q)
docker exec -it nginx sh
sudo vi /etc/hosts

# nginx
The location directive within NGINX server block allows to route request to correct location within the file system.
respond to any request with the pattern of php 
/etc/nginx/fastcgi_params  fastcgi param in nginx 

OpenRC is the init system used in alpine. The init system manages the services, startup and shutdown of your computer.

# wordpress 

/var/www/html/wordpress is where to find wp-config.php

--> for php-fpm
/etc/php7/php-fpm.d is where to find www.conf 


# maria db 
mysql -u ahaifoul -p abdel

show databases;
use wordpress
show tables;
# modify data
SELECT ID, user_login, user_pass FROM wp_users;
UPDATE wp_users SET user_pass= MD5("abdel") WHERE ID = 1;

# check port connection
SHOW GLOBAL VARIABLES LIKE 'PORT'

# create new pswd encryption 
echo -n abdel | md5sum 
e6053eb8d35e02ae40beeeacef203c1a/
INSERT INTO wordpress.wp_users 


# connection 
ftp://10.13.100.29/  ftp sever
http://10.13.100.29:7777/   static website
https://10.11.100.166:443/       wordpress website
https://10.11.100.166:443/wp-admin       wordpress website database connection

http://10.13.100.29:7077/  check adminer interface
