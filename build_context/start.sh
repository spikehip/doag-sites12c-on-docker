#!/bin/bash

sudo /etc/init.d/oracle-xe start
cd;weblogic/user_projects/domains/base_domain/startWebLogic.sh 2>&1 >admin.log &
admin_run=`grep -i RUNNING admin.log|grep -v grep |awk 'END{print NR}'`
while [ $admin_run -eq 0 ]
do
sleep 5;
printf "."
admin_run=`grep -i RUNNING admin.log|grep -v grep |awk 'END{print NR}'`
done
weblogic/user_projects/domains/base_domain/bin/startManagedWebLogic.sh wcsites_server1 t3://localhost:7001 2>&1 >managed.log &
tail -f managed.log


