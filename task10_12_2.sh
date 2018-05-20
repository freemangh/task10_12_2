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
EXTERNAL_IP: $EXTERNAL_IP
HOST_NAME: $HOST_NAME
# Docker parameters
NGINX_IMAGE: $NGINX_IMAGE
APACHE_IMAGE: $APACHE_IMAGE
NGINX_PORT: $NGINX_PORT
NGINX_LOG_DIR: $NGINX_LOG_DIR
===CONFIG END==="
#
echo "Step 1: Setting up stuff..."
echo "Adding Docker repo key..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
echo "Adding Docker repo..."
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update
echo "Installing docker-ce and docker-compose..."
sudo apt-get install docker-ce docker-compose -y
echo "Installing OpenSSL..."
sudo apt-get install openssl -y
#
echo "Generating certs..."
mkdir -vp $SCRPATH'certs'

echo "[ req ]
default_bits = 2048
prompt = no
default_md = sha256
x509_extensions = v3_req
distinguished_name = dn

[ dn ]
C = UA
ST = Kharkov
L = Kharkov
O = Mirantis
OU=Internship
emailAddress = khvastunov@gmail.com
CN = $HOST_NAME

[ san ]
subjectAltName = \"DNS:$HOST_NAME,IP:$EXTERNAL_IP\"
" > /etc/ssl/docker.cnf

openssl genrsa -out $SCRPATH'certs/root.key' 4096
/usr/bin/openssl req -x509 -new -nodes -key $SCRPATH'certs/root.key' -sha256 -days 365 -out $SCRPATH'certs/root.crt' -subj "/C=UA/ST=Kharkov/L=Kharkov/O=Mirantis/OU=Internship/CN=$HOST_NAME/" -reqexts san -extensions san -config /etc/ssl/docker.cnf
/usr/bin/openssl genrsa -out $SCRPATH'certs/web.key' 2048
/usr/bin/openssl req -new -out $SCRPATH'certs/web.csr' -key $SCRPATH'certs/web.key' -subj "/C=UA/ST=Kharkov/L=Kharkov/O=Mirantis/OU=Internship/CN=$HOST_NAME/" -reqexts san -extensions san -config /etc/ssl/docker.cnf
/usr/bin/openssl x509 -req -in $SCRPATH'certs/web.csr' -CA $SCRPATH'certs/root.crt' -CAkey $SCRPATH'certs/root.key' -CAcreateserial -out $SCRPATH'certs/web.crt'

cat $SCRPATH'certs/root.crt' $SCRPATH'certs/web.crt' > $SCRPATH'certs/chain.pem'
#
echo "Creating nginx log dir:"
mkdir -vp $NGINX_LOG_DIR
echo "Creating nginx conf dir:"
mkdir -vp $SCRPATH'etc'
#---<START: nginx default sitetemplate>---
echo "user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
        worker_connections 768;
        # multi_accept on;
}

http {

        ##
        # Basic Settings
        ##

        sendfile on;
        tcp_nopush on;
        tcp_nodelay on;
        keepalive_timeout 65;
        types_hash_max_size 2048;
        # server_tokens off;

        # server_names_hash_bucket_size 64;
        # server_name_in_redirect off;

        include /etc/nginx/mime.types;
        default_type application/octet-stream;

        ##
        # SSL Settings
        ##

        ssl_protocols TLSv1 TLSv1.1 TLSv1.2; # Dropping SSLv3, ref: POODLE
        ssl_prefer_server_ciphers on;

        ##
        # Logging Settings
        ##

        access_log /var/log/nginx/access.log;
        error_log /var/log/nginx/error.log;

        ##
        # Gzip Settings
        ##

        gzip on;
        gzip_disable "msie6";

	server {
		listen 443 ssl default_server;
		# listen [::]:443 ssl default_server;
	
		#root /var/www/html;

		# Add index.php to the list if you are using PHP
		#index index.html index.htm index.nginx-debian.html;

		server_name _;
		ssl_certificate /etc/nginx/certs/chain.pem;
		ssl_certificate_key /etc/nginx/certs/root.key;

		location / {
			proxy_set_header HOST \$host;
			proxy_set_header X-Forwarded-Proto \$scheme;
			proxy_set_header X-Real-IP \$remote_addr;
			proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
			proxy_pass http://apache:8080\$request_uri;
		}

	}
}" > $SCRPATH'etc/nginx.conf'
#---<END: nginx default sitetemplate>---
#
#---<START: Docker compose template>---
echo "version: '2'
services:
  nginx:
    image: ${NGINX_IMAGE}
    hostname: nginx
    volumes:
      - .etc:/etc/nginx
      - .certs:/etc/nginx/certs
      - ${NGINX_LOG_DIR}:/var/log/nginx
  ports:
      - "${NGINX_PORT}:443"
  apache:
    image: ${APACHE_IMAGE}
    hostname: apache
    ports:
      - "8080:80" " > $SCRPATH'docker-compose.yml'
#---<END: Docker compose template>---
echo "Deploying containers..."
docker-compose up -d
