#!/bin/bash 

curl http://installer_server/fmw_12.2.1.2.0_infrastructure_Disk1_1of1.zip -o /tmp/wls.zip
cd ; unzip /tmp/wls.zip

java -jar /u01/app/oracle/fmw_12.2.1.2.0_infrastructure.jar -responseFile /u01/app/oracle/weblogic.rsp -silent -invPtrLoc /u01/app/oracle/oraInst.loc

curl http://installer_server/fmw_12.2.1.2.0_wcsites_Disk1_1of1.zip -o /tmp/sites.zip
cd ; unzip /tmp/sites.zip
java -jar /u01/app/oracle/fmw_12.2.1.2.0_wcsites.jar -responseFile /u01/app/oracle/sites.rsp -silent -invPtrLoc /u01/app/oracle/oraInst.loc -ignoreSysPrereqs -force -novalidation

echo "set up database"
sed -i -E "s/HOST = [^)]+/HOST = 0.0.0.0/g" /u01/app/oracle/product/11.2.0/xe/network/admin/listener.ora
sed -i -E "s/HOST = [^)]+/HOST = 0.0.0.0/g" /u01/app/oracle/product/11.2.0/xe/network/admin/tnsnames.ora
sudo /etc/init.d/oracle-xe start 
cd ; echo "ALTER SESSION SET CURRENT_SCHEMA=&&1;" >weblogic/oracle_common/common/sql/iau/scripts/prepareAuditView.sql
printf "welcome1\\nwelcome1\\n" | weblogic/oracle_common/bin/rcu -silent -createRepository -connectString 127.0.0.1:1521:XE -dbUser SYS -dbRole SYSDBA -useSamePasswordForAllSchemaUsers true -schemaPrefix DEV -component STB -component OPSS -component WCSITES -component WCSITESVS -component IAU -component IAU_APPEND -component IAU_VIEWER

echo "set up weblogic"
cat >> weblogic-setup.py <<END
readTemplate("%s/weblogic/wlserver/common/templates/wls/wls.jar" % os.environ['PWD'])
addTemplate("%s/weblogic/wlserver/common/templates/wls/wls_coherence_template.jar" % os.environ['PWD'])
addTemplate("%s/weblogic/oracle_common/common/templates/wls/oracle.jrf_template.jar" % os.environ['PWD'])
addTemplate("%s/weblogic/em/common/templates/wls/oracle.em_wls_template.jar" % os.environ['PWD'])
addTemplate("%s/weblogic/wcsites/common/templates/wls/oracle.wcsites.examples.template.jar" % os.environ['PWD'])
addTemplate("%s/weblogic/wcsites/common/templates/wls/oracle.wcsites.visitorservices.template.jar" % os.environ['PWD'])

# set pw
cd('Servers/AdminServer')
set('ListenPort', 7001)
cd('/')
cd('Security/base_domain/User/weblogic')
cmo.setPassword('welcome1') 

cd('/')
jdbcsystemresources = cmo.getJDBCSystemResources();
for res in jdbcsystemresources:
    print res
    cd ('/JDBCSystemResource/' + res.getName() + '/JdbcResource/' + res.getName() + '/JDBCConnectionPoolParams/NO_NAME_0');
    cd ('/JDBCSystemResource/' + res.getName() + '/JdbcResource/' + res.getName() + '/JDBCDriverParams/NO_NAME_0');
    cmo.setUrl('jdbc:oracle:thin:@localhost:1521:XE');
    cmo.setPasswordEncrypted('welcome1')

cd("/JDBCSystemResource/wcsitesDS/JdbcResource/wcsitesDS/JdbcDriverParams/NO_NAME_0/Properties/NO_NAME_0/Property/user")
cmo.setValue("DEV_WCSITES") 

writeDomain('%s/weblogic/user_projects/domains/base_domain' % os.environ['PWD'])
closeTemplate()

exit()
END

weblogic/oracle_common/common/bin/wlst.sh weblogic-setup.py
sed -i.bak -e 's/WLS_USER=""/WLS_USER="weblogic"/' -e 's/WLS_PW=""/WLS_PW="'welcome1'"/' -e 's!JAVA_OPTIONS="-Dweblogic!JAVA_OPTIONS="-Djava.security.egd=file:///dev/urandom -Djava.net.preferIPv4Stack=true -Dweblogic!' weblogic/user_projects/domains/base_domain/bin/startManagedWebLogic.sh

cd ; mkdir -p shared/data

echo "bootstrap sites"
sed \
 -e "s/oracle\.wcsites\.shared=.*/oracle.wcsites.shared=\/u01\/app\/oracle\/shared/" \
 -e "s/bootstrap\.status=.*/bootstrap.status=never_done/" \
 -e "s/database\.type=.*/database.type=oracle/" \
 -e "s/database\.datasource=.*/database.datasource=wcsitesDS/" \
 -e "s/wcsites\.hostname=.*/wcsites\.hostname=localhost/" \
 -e "s/wcsites\.portnumber=.*/wcsites\.portnumber=7003/" \
 -e "s/cas\.portnumber=.*/cas\.portnumber=7003/" \
 -e "s/cas\.hostname=.*/cas\.hostname=localhost/" \
 -e "s/cas\.hostnameActual=.*/cas\.hostnameActual=localhost/" \
 -e "s/cas\.hostnameLocal=.*/cas\.hostnameLocal=localhost/" \
 -e "s/cas\.portnumberLocal=.*/cas\.portnumberLocal=7003/" \
 -e "s/password=.*/password=welcome1/" \
 -e "s/admin.user=.*/admin.user=ContentServer/" \
 -e "s/satellite.user=.*/satellite.user=SatelliteServer/" \
 -e "s/app.user=.*/app.user=fwadmin/" \
 -e "s/oracle.wcsites.examples=.*/oracle.wcsites.examples=true/" \
 -e "s/oracle.wcsites.examples.fsii=.*/oracle.wcsites.examples.fsii=true/" \
 -e "s/oracle.wcsites.examples.avisports=.*/oracle.wcsites.examples.avisports=true/" \
 -e "s/oracle.wcsites.examples.Samples=.*/oracle.wcsites.examples.Samples=true/" \
 <weblogic/wcsites/webcentersites/sites-home/template/config/wcs_properties_bootstrap.ini \
 >weblogic/user_projects/domains/base_domain/wcsites/wcsites/config/wcs_properties_bootstrap.ini

echo "configure sites" 
cd;touch admin.log
weblogic/user_projects/domains/base_domain/startWebLogic.sh 2>&1 >admin.log &
admin_run=`grep -i RUNNING admin.log|grep -v grep |awk 'END{print NR}'`
while [ $admin_run -eq 0 ]  
do
sleep 5;
printf "."
admin_run=`grep -i RUNNING admin.log|grep -v grep |awk 'END{print NR}'`
done
cd weblogic/user_projects/domains/base_domain/wcsites/bin/
sed -ie 's/[0-9a-z]*:7001/localhost:7001/g' grant-opss-permission.py 
./grant-opss-permission.sh weblogic welcome1

echo "start sites managed server"
cd;touch managed.log
weblogic/user_projects/domains/base_domain/bin/startManagedWebLogic.sh wcsites_server1 t3://localhost:7001 2>&1 >managed.log &
sites_run=`grep -i RUNNING managed.log|grep -v grep |awk 'END{print NR}'`
while [ $sites_run -eq 0 ]  
do
sleep 5;
printf "."
sites_run=`grep -i RUNNING managed.log|grep -v grep |awk 'END{print NR}'`
done

echo "configure sites"
while ! curl http://localhost:7003/sites/HelloCS | grep Success
do sleep 1 ; done
curl http://localhost:7003/sites/sitesconfig
touch http.log
while ! grep "Sites Configuration finished successfully" http.log
do curl -s http://localhost:7003/sites/configresources/configprogressdynamic.jsp |\
   grep "steps" | tee http.log
   sleep 1
done

echo "stop sites"
weblogic/user_projects/domains/base_domain/bin/stopManagedWebLogic.sh wcsites_server1 t3://localhost:7001 weblogic welcome1
echo "stop weblogic"
weblogic/user_projects/domains/base_domain/bin/stopWebLogic.sh 

echo "clean up"
rm -rf /tmp/wls.zip /tmp/sites.zip /u01/app/oracle/fmw_* /u01/app/oracle/weblogic.rsp /u01/app/oracle/oraInst.loc /u01/app/oracle/wls-installer.sh /u01/app/oracle/weblogic-setup.py /u01/app/oracle/sites.rsp 




