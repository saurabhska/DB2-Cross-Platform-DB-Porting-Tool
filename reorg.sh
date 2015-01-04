#!/bin/ksh
cd /cygdrive/d/AIX2WinDBConvFilesTemp
export DB2CLP=**$$**
WINDBName=$1		#inputs
WINDBSchema=$2

db2 connect to $WINDBName >> output.out #Connect to DB

echo "Checking and removing tables from reorg pending state" | tee -a DBConversion.log
db2 connect to $WINDBName >> output.out #Connect to DB

db2 -x "select 'REORG TABLE '|| TABSCHEMA ||'.'||TABNAME || ' ;' from SYSIBMADM.ADMINTABINFO where REORG_PENDING = 'Y' and locate('_',TABNAME)=0" > chkreorg.sql

tabcnt=$(wc -l < chkreorg.sql)
while [[ ${tabcnt} -gt 0 ]];
 do
	echo "***********************************************" | tee -a DBConversion.log
	echo "Number of tables in reorg pending state : $tabcnt" | tee -a DBConversion.log
	echo "Removing tables from reorg pending state" | tee -a DBConversion.log
	echo "***********************************************" | tee -a DBConversion.log
    db2 -tf chkreorg.sql >> output.out
	db2 "commit" >> output.out
    # look for more tables in check pending state
    db2 -x "select 'REORG TABLE '|| TABSCHEMA ||'.'||TABNAME || ' ;' from SYSIBMADM.ADMINTABINFO where REORG_PENDING = 'Y' and locate('_',TABNAME)=0" > chkreorg.sql
    tabcnt=$(wc -l < chkreorg.sql)
done
echo "No table is in reorg pending state" | tee -a DBConversion.log