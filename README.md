# Inception-Docker



sudo docker rm -f $(sudo docker ps -aq)
sudo docker rmi -f $(sudo docker images -q)
docker exec -it nginx sh