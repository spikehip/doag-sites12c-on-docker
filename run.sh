#!/bin/bash

#run local web server to serve the oracle install kits
if [ $(docker ps | grep installer_server | wc -l) -lt 1 ]; then
  docker run -d --name installer_server -v $(pwd)/oracle_installer_kits:/usr/share/nginx/html:rw nginx
fi

#build base image with supervisord
#docker build -t oraclelinux:supervisord -f build_context/Dockerfile-oraclelinux\:supervisord build_context

#add jdk8 
docker build -t oraclelinux:jdk8builder -f build_context/Dockerfile-oraclelinux\:jdk8 build_context
docker run --link installer_server:installer_server --name jdk8 oraclelinux:jdk8builder /bin/bash /jdk8-installer.sh
docker commit jdk8 oraclelinux:jdk8
docker rm jdk8
docker rmi oraclelinux:jdk8builder

#try jdk8
docker run --rm oraclelinux:jdk8 java -version 

#add oracle XE database
docker build -t oracle:xebuilder -f build_context/Dockerfile-oracle\:xe build_context
docker run --link installer_server:installer_server --name xe oracle:xebuilder /bin/bash /xe-installer.sh
docker commit xe oracle:xe
docker rm xe
docker rmi oracle:xebuilder

#add weblogic and sites 12c
docker build -t oracle:wlsbuilder -f build_context/Dockerfile-oracle:wls build_context
docker run -P --link installer_server:installer_server --name wls oracle:wlsbuilder /bin/bash /u01/app/oracle/wls-installer.sh
docker commit wls oracle:wls
docker rm wls
docker rmi oracle:wlsbuilder

#add start
docker build -t oracle:wcs -f build_context/Dockerfile-oracle:wcs build_context
docker run -ti --rm -P oracle:wcs
docker run -P
