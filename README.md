# Inception-Docker



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
mysql -u ahaifoul -pabdel

show databases;
use wordpress
show tables;
# modify data
SELECT ID, user_login, user_pass FROM wp_users;
UPDATE wp_users SET user_pass= "abdel" WHERE ID = 1;

# check port connection
SHOW GLOBAL VARIABLES LIKE 'PORT'

# create new pswd encryption 
echo -n "newpass" | md5sum
e6053eb8d35e02ae40beeeacef203c1a

# connection 
ftp://10.11.100.166/  ftp sever
http://10.11.100.166:7777/   static website
https://10.11.100.166:443/       wordpress website
https://10.11.100.166:443/wp-admin       wordpress website database connection

https://10.11.100.166:7077/adminer.php   check adminer interface