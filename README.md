# Inception-Docker

This project aims to broaden your knowledge of system administration by using Docker.

we have to virtualize several Docker images, creating them in a virtual machine.

- Each service has to un in a dedicated container. 
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
Bonus part

A Dockerfile must be written for each extra service. Thus, each one of them will run
inside its own container and will have, if necessary, its dedicated volume.
Bonus list:
• Set up redis cache for your WordPress website in order to properly manage the
cache.
• Set up a FTP server container pointing to the volume of your WordPress website.
• Create a simple static website in the language of your choice except PHP (Yes, PHP
is excluded!). For example, a showcase site or a site for presenting your resume.
• Set up Adminer.
• Set up a service of your choice that you think is useful. During the defense, you
will have to justify your choice.

check Subejct file of the Project for more Infos 




