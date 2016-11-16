#!/bin/bash 

curl http://installer_server/oracle-xe-11.2.0-1.0.x86_64.rpm.zip -o /tmp/xe.zip
yum -y install unzip libaio
unzip /tmp/xe.zip
rpm -i Disk1/oracle-xe-11.2.0-1.0.x86_64.rpm
sed -i -e 's/^\(memory_target=.*\)/#\1/' /u01/app/oracle/product/11.2.0/xe/config/scripts/initXETemp.ora
sed -i -e 's/^\(memory_target=.*\)/#\1/' /u01/app/oracle/product/11.2.0/xe/config/scripts/init.ora
/etc/init.d/oracle-xe configure responseFile=/xe.rsp
rm -rf /tmp/xe.zip /xe-installer.sh /Disk1 /xe.rsp
yum clean all
