#!/bin/bash 

curl http://installer_server/jdk-8u112-linux-x64.rpm -o /tmp/jdk8.rpm
rpm -i /tmp/jdk8.rpm
rm -rf /tmp/jdk8.rpm /jdk8-installer.sh
