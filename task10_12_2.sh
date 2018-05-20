#!/bin/bash
# Mirantis Internship 2018
# Task 10-12.2
# Eugeniy Khvastunov
# Deployment of Docker containers.
#
echo "Adding Docker repo key..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
echo "Adding Docker repo..."
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update
echo "Installing docker-ce and docker-compose..."
sudo apt-get install docker-ce docker-compose -y

#
echo "Step 0: Reading variables from config..."
SCRPATH="$(/bin/readlink -f "$0" | rev | cut -c 15- | rev)"
CONFIGFILE=$SCRPATH'config'
echo "Config file: $CONFIGFILE"
set -o allexport
source $CONFIGFILE
set +o allexport
echo "===CONFIG START===
SCRPATH: $SCRPATH
CONFIGFILE: $CONFIGFILE
# Host parameters
EXTERNAL_IP=10.14.254.15
HOST_NAME=docker-vm.domain.tld
# Docker parameters
NGINX_IMAGE="nginx:1.13"
APACHE_IMAGE="httpd:2.4"
NGINX_PORT=17080
NGINX_LOG_DIR=/srv/log/nginx
===CONFIG END==="

