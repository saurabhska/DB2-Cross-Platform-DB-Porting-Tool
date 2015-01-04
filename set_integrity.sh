#!/bin/ksh
cd /cygdrive/d/AIX2WinDBConvFilesTemp
export DB2CLP=**$$**
WINDBName=$1		#inputs
WINDBSchema=$2
echo "Checking and removing tables from set integrity pending state" | tee -a DBConversion.log
db2 connect to $WINDBName >> output.out #Connect to DB

db2 -x "select 'SET INTEGRITY FOR '|| TABSCHEMA ||'.'||TABNAME || ' IMMEDIATE CHECKED;' from SYSCAT.TABLES where STATUS='C' and type='T' and tabschema='$WINDBSchema' and locate('_',tabname)=0" > chkset_integrity.sql

tabcnt=$(wc -l < chkset_integrity.sql)
while [[ ${tabcnt} -gt 0 ]];
 do
	echo "***********************************************" | tee -a DBConversion.log
	echo "Number of tables in set integrity pending state : $tabcnt" | tee -a DBConversion.log
	echo "Setting integrity of table in set integrity pending state" | tee -a DBConversion.log
	echo "***********************************************" | tee -a DBConversion.log
    db2 -tf chkset_integrity.sql >> output.out
	db2 "commit" >> output.out
    # look for more tables in check pending state
    db2 -x "select 'SET INTEGRITY FOR '|| TABSCHEMA ||'.'||TABNAME || ' IMMEDIATE CHECKED;' from SYSCAT.TABLES where STATUS='C' and type='T' and tabschema='$WINDBSchema' and locate('_',tabname)=0" > chkset_integrity.sql
    tabcnt=$(wc -l < chkset_integrity.sql)
done
echo "No table in set integrity pending state" | tee -a DBConversion.log