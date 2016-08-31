#!/bin/bash

###########################################################
# Configure Swarm
###########################################################

set -x

echo "starting swarm configuration"
date
ps ax

DOCKER_COMPOSE_VERSION="1.8.0"

#############
# Parameters
#############

ISMASTER=${1}
IPADDR=${2}
MASTER0IPADDR=${3}
AZUREUSER=${4}
POSTINSTALLSCRIPTURI=${5}
VMNAME=`hostname`

###################
# Common Functions
###################

ensureAzureNetwork()
{
  # ensure the host name is resolvable
  hostResolveHealthy=1
  for i in {1..120}; do
    host $VMNAME
    if [ $? -eq 0 ]
    then
      # hostname has been found continue
      hostResolveHealthy=0
      echo "the host name resolves"
      break
    fi
    sleep 1
  done
  if [ $hostResolveHealthy -ne 0 ]
  then
    echo "host name does not resolve, aborting install"
    exit 1
  fi

  # ensure the network works
  networkHealthy=1
  for i in {1..12}; do
    wget -O/dev/null http://bing.com
    if [ $? -eq 0 ]
    then
      # hostname has been found continue
      networkHealthy=0
      echo "the network is healthy"
      break
    fi
    sleep 10
  done
  if [ $networkHealthy -ne 0 ]
  then
    echo "the network is not healthy, aborting install"
    ifconfig
    ip a
    exit 2
  fi
  # ensure the host ip can resolve
  networkHealthy=1
  for i in {1..120}; do
    hostname -i
    if [ $? -eq 0 ]
    then
      # hostname has been found continue
      networkHealthy=0
      echo "the network is healthy"
      break
    fi
    sleep 1
  done
  if [ $networkHealthy -ne 0 ]
  then
    echo "the network is not healthy, cannot resolve ip address, aborting install"
    ifconfig
    ip a
    exit 2
  fi
}
ensureAzureNetwork

######################
# resolve self in DNS
######################
HOSTADDR=`hostname -i`
echo "$HOSTADDR $VMNAME" | sudo tee -a /etc/hosts

################
# Install Docker
################

echo "Installing and configuring docker"

installDocker()
{
  for i in {1..10}; do
    wget --tries 4 --retry-connrefused --waitretry=15 -qO- https://get.docker.com | sh
    if [ $? -eq 0 ]
    then
      # hostname has been found continue
      echo "Docker installed successfully"
      break
    fi
    sleep 10
  done
}
time installDocker
sudo usermod -aG docker $AZUREUSER

echo 'DOCKER_OPTS="-H unix:///var/run/docker.sock -H 0.0.0.0:2375"' | sudo tee -a /etc/default/docker

echo "Installing docker compose"
installDockerCompose()
{
  for i in {1..10}; do
    wget --tries 4 --retry-connrefused --waitretry=15 -qO- https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
    if [ $? -eq 0 ]
    then
      # hostname has been found continue
      echo "docker-compose installed successfully"
      break
    fi
    sleep 10
  done
}
time installDockerCompose
chmod +x /usr/local/bin/docker-compose

sudo service docker restart

ensureDocker()
{
  # ensure that docker is healthy
  dockerHealthy=1
  for i in {1..3}; do
    sudo docker info
    if [ $? -eq 0 ]
    then
      # hostname has been found continue
      dockerHealthy=0
      echo "Docker is healthy"
      sudo docker ps -a
      break
    fi
    sleep 10
  done
  if [ $dockerHealthy -ne 0 ]
  then
    echo "Docker is not healthy"
  fi
}
ensureDocker

##############################################
# configure swarm
##############################################

if [ $ISMASTER -eq 1 ]; then
  echo "this node is a master"
  if [ "$IPADDR" = "$MASTER0IPADDR" ]; then
    echo "this is the first master, creating swarm"
    docker swarm init --advertise-addr $IPADDR:2377 --listen-addr $IPADDR:2377
  else
    echo "this is a secondary master"
    swarmkey=""
    hasswarmkey=1
    for i in {1..120}; do
      swarmkey=$(docker -H $MASTER0IPADDR:2375 swarm join-token manager -q)
      if [ $? -eq 0 ]; then
        hasswarmkey=0
        break;
      fi 
    done
    if [ $hasswarmkey -ne 0 ]
    then
      echo "couldn't connect to swarm, aborting."
      exit 2
    fi
    docker swarm join --token $swarmkey $MASTER0IPADDR:2377
  fi
else
  echo "this node is an agent"
  swarmkey=""
  hasswarmkey=1
  for i in {1..120}; do
    swarmkey=$(docker -H $MASTER0IPADDR:2375 swarm join-token worker -q)
    if [ $? -eq 0 ]; then
      hasswarmkey=0
      break;
    fi 
  done
  if [ $hasswarmkey -ne 0 ]
  then
    echo "couldn't connect to swarm, aborting."
    exit 2
  fi
  docker swarm join --token $swarmkey $MASTER0IPADDR:2377  
fi

if [ $POSTINSTALLSCRIPTURI != "disabled" ]
then
  echo "downloading, and kicking off post install script"
  /bin/bash -c "wget --tries 20 --retry-connrefused --waitretry=15 -qO- $POSTINSTALLSCRIPTURI | nohup /bin/bash >> /var/log/azure/cluster-bootstrap-postinstall.log 2>&1 &"
fi

echo "processes at end of script"
ps ax
date
echo "completed swarm configuration"
