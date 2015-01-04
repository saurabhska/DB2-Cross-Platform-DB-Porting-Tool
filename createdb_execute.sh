#!/bin/ksh
cd /cygdrive/d/AIX2WinDBConvFilesTemp/WindowsDBFiles/AIX2WindowsFiles
export DB2CLP=**$$**
echo "*************Creating Windows DB with following values**************" | tee -a DBConversion.log
echo "WIN DB NAME: @WINDBName@" | tee -a DBConversion.log
echo "WIN DB SCHEMA: @WINDBSchema@" | tee -a DBConversion.log
echo "WIN DB USER: @WINDBUser@" | tee -a DBConversion.log
echo "********************************************************************" | tee -a DBConversion.log

echo "***************Creating Database @WINDBName@ **************************" | tee -a DBConversion.log
 db2 create db @WINDBName@ AUTOMATIC STORAGE YES ON C: >> DBCreate.out
 db2 update db cfg for @WINDBName@ using LOGFILSIZ 10000 >> DBCreate.out
 db2 update db cfg for @WINDBName@ using LOGSECOND 200 >> DBCreate.out
 
CHECK_DB=$(db2 list db directory | grep "Database alias" | awk -F "=" '{print $2}' | grep @WINDBName@| wc -l | awk '{print $1}' )

if (( ${CHECK_DB} < 1 ))
then
	    echo "Error creating database @WINDBName@ " | tee -a DBConversion.log
		echo "Error Message:" | tee -a DBConversion.log
		cat DBCreate.out | tee -a DBConversion.log
		exit
else
	echo "***************Enabling AUTO_REVAL Parameter************************" | tee -a DBConversion.log
	db2 -tvf set_AUTO_REVAL_DB_CFG.sql > set_AUTO_REVAL_DB_CFG.out
	echo "***************Creating bufferpools*********************************" | tee -a DBConversion.log
	  db2 -tvf bufferpools.sql > bufferpools.out
	echo "***************Creating Tablespaces*********************************" | tee -a DBConversion.log
	  db2 -tvf tablespaces.sql > tablespaces.out 
	echo "***************Creating Tables**************************************" | tee -a DBConversion.log
	  db2 -tvf tblddl.sql > tblddl.out

	echo "***************Loading data into tables*****************************" | tee -a DBConversion.log
	before="$(date +%s)"
	#cat load35.sql | grep -v _ > Newload35.sql
	#rm -rf load35.sql
	#cp Newload35.sql load35.sql
	db2 -tvf load35.sql > load35.out
	after="$(date +%s)"
	elapsed_seconds="$(expr $after - $before)"
	timediff=`echo - | awk -v "S=$elapsed_seconds" '{printf "%dh:%dm:%ds",S/(60*60),S%(60*60)/60,S%60}'`
	echo "Time to load data in tables : $timediff"|tee -a Time.log
	echo "***************Setting Integrity of Tables**************************" | tee -a DBConversion.log
	  db2 -tvf set_integrity.sql > set_integrity.out
	  sh set_integrity.sh @WINDBName@ @WINDBSchema@
	echo "***************Adding Foreign Key Constraints***********************" | tee -a DBConversion.log
	  db2 -tvf fks.sql > fks.out
	echo "***************Validating Procedures********************************" | tee -a DBConversion.log
		db2 connect to @WINDBName@ >>output.out
	#------------- PrepSPCalls -----------------
		echo "CONNECT TO @WINDBName@;" > PrepSPCalls.sql
		db2 -x "select 'CALL @WINDBSchema@.'||PROCNAME||' ();' from syscat.procedures where PROCNAME like '%PREPSP%'" >> PrepSPCalls.sql
		db2 -x "select 'CALL @WINDBSchema@.'||PROCNAME||' ();' from syscat.procedures where PROCNAME like '%DGTT%'" >> PrepSPCalls.sql
		db2 -x "select 'CALL @WINDBSchema@.'||PROCNAME||' (100);' from syscat.procedures where PROCNAME like '%PREPSP%'" >> PrepSPCalls.sql
		db2 -x "select 'CALL @WINDBSchema@.'||PROCNAME||' (100);' from syscat.procedures where PROCNAME like '%DGTT%'" >> PrepSPCalls.sql
		db2 -x "select 'CALL SYSPROC.ADMIN_REVALIDATE_DB_OBJECTS('||''''||'PROCEDURE'||''''||','||''''||trim(ROUTINESCHEMA)||''''||','||''''||
				trim(ROUTINENAME)||''''||');' from syscat.routines where valid in ('N','X')" >> PrepSPCalls.sql
		echo "CALL SYSPROC.ADMIN_REVALIDATE_DB_OBJECTS(NULL, '@WINDBSchema@', NULL);" >> PrepSPCalls.sql
		echo "CONNECT RESET ;" >> PrepSPCalls.sql
		db2 -tvf PrepSPCalls.sql > PrepSPCalls.out
	#------------- PrepSPCalls ----------------- 
	echo "***************Creating Alias***************************************" | tee -a DBConversion.log
	  db2 -tvf alias.sql > alias.out
	echo "***************Granting Privileges**********************************" | tee -a DBConversion.log
	  db2 -tvf grant.sql > grant.out
	echo "***************************Refresh MQTs*****************************" | tee -a DBConversion.log  
	   db2 -tvf refreshMqt.sql > refreshMqt.out
	echo "***************Removing Tables from Reorg Pending State*************" | tee -a DBConversion.log
	  db2 -tvf reorg.sql > reorg.out
	  sh reorg.sh @WINDBName@ @WINDBSchema@
	echo "***************Windows DB created successfully**********************" | tee -a DBConversion.log

	echo "***************Reducing DB Size********************************************" | tee -a DBConversion.log
	before="$(date +%s)"
	db2 connect to @WINDBName@ >> output.out
	echo "CONNECT TO @WINDBName@;" > reduceDBSize.sql 
	db2 -x "select 'Alter tablespace ' || TBSPACE || ' AUTORESIZE YES INCREASESIZE 5 PERCENT ;' from syscat.tablespaces where TBSPACETYPE = 'D'" >> reduceDBSize.sql
	echo "commit;" >> reduceDBSize.sql
	db2 -x "select 'Alter tablespace ' || trim(TBSP_NAME) || ' reduce (all ' || trim(char(TBSP_FREE_PAGES - 100)) || ');' from sysibmadm.TBSP_UTILIZATION where TBSP_TYPE='DMS' and TBSP_FREE_PAGES > 100 and TBSP_NAME not in('SYSTOOLSPACE','SYSCATSPACE','USERSPACE1')" >> reduceDBSize.sql
	echo "COMMIT;" >> reduceDBSize.sql
	echo "CONNECT RESET;" >> reduceDBSize.sql

	db2 -tvf reduceDBSize.sql > reduceDBSize.out
	after="$(date +%s)"
	elapsed_seconds="$(expr $after - $before)"
	timediff=`echo - | awk -v "S=$elapsed_seconds" '{printf "%dh:%dm:%ds",S/(60*60),S%(60*60)/60,S%60}'`
	echo "Time to reduce DB size : $timediff"|tee -a Time.log
	echo "*********************************************************************************" | tee -a DBConversion.log

	sh generateReport.sh @WINDBName@ @WINDBSchema@

	echo "***************Scanning for Errors in output files******************" | tee -a DBConversion.log

	echo "***************Errors in set_AUTO_REVAL_DB_CFG.out******************" >> Errors.log 
	grep -i SQL[0-9]*N  < set_AUTO_REVAL_DB_CFG.out >> Errors.log
	echo "********************************************************************" >> Errors.log

	echo "***************Errors in bufferpools.out******************" >> Errors.log 
	grep -i SQL[0-9]*N < bufferpools.out | grep -v SQL0204N | grep -v SQL0601N >> Errors.log
	echo "********************************************************************" >> Errors.log

	echo "***************Errors in tablespaces.out******************" >> Errors.log 
	grep -i SQL[0-9]*N < tablespaces.out | grep -v SQL0204N | grep -v SQL0601N >> Errors.log
	echo "********************************************************************" >> Errors.log

	echo "***************Errors in tblddl.out******************" >> Errors.log 
	grep -i SQL[0-9]*N < tblddl.out | grep -v SQL0204N | grep -v SQL0601N >> Errors.log
	echo "********************************************************************" >> Errors.log

	echo "***************Errors in load35.out******************" >> Errors.log 
	grep -i SQL[0-9]*N < load35.out | grep -v SQL3109N | grep -v SQL3150N | grep -v SQL3153N | grep -v SQL3110N >> Errors.log
	grep -i "Number of rows skipped" < load35.out >> Errors.log
	grep -i "Number of rows rejected" < load35.out >> Errors.log
	grep -v "Number of rows skipped      = 0" < Errors.log | grep -v "Number of rows rejected     = 0" | grep -v SQL0204N > temp.txt
	cat temp.txt > Errors.log
	rm -rf temp.txt
	echo "********************************************************************" >> Errors.log

	echo "***************Errors in set_integrity.out******************" >> Errors.log 
	grep -i SQL[0-9]*N < set_integrity.out | grep -v SQL3600N | grep -v SQL0156N | grep -v SQL0204N | grep -v SQL3608N >> Errors.log
	echo "********************************************************************" >> Errors.log

	echo "***************Errors in fks.out******************" >> Errors.log 
	grep -i SQL[0-9]*N < fks.out | grep -v SQL0204N | grep -v SQL0601N >> Errors.log
	echo "********************************************************************" >> Errors.log

	echo "***************Errors in PrepSPCalls.out ******************" >> Errors.log 
	grep -i SQL[0-9]*N < PrepSPCalls.out | grep -v SQL0204N | grep -v SQL0440N >> Errors.log
	echo "********************************************************************" >> Errors.log

	echo "***************Errors in alias.out******************" >> Errors.log 
	grep -i SQL[0-9]*N < alias.out| grep -v SQL0601N | grep -v SQL0204N >> Errors.log
	echo "********************************************************************" >> Errors.log

	echo "***************Errors in grant.out******************" >> Errors.log 
	grep -i SQL[0-9]*N < grant.out | grep -v SQL0204N >> Errors.log
	echo "********************************************************************" >> Errors.log

	echo "***************Errors in reorg.out******************" >> Errors.log 
	grep -i SQL[0-9]*N < reorg.out | grep -v SQL0204N >> Errors.log
	echo "********************************************************************" >> Errors.log

	echo "***************Errors in reduceDBSize.out******************" >> Errors.log 
	grep -i SQL[0-9]*N < reduceDBSize.out >> Errors.log
	echo "********************************************************************" >> Errors.log
	echo "***************Errors encountered during process are in file Errors.log**************************" | tee -a DBConversion.log
	
	echo "***************Setting Integrity of Tables**************************" | tee -a DBConversion.log
	  db2 -tvf set_integrity.sql > set_integrity_final.out
	  sh set_integrity.sh @WINDBName@ @WINDBSchema@
	echo "***************Removing Tables from Reorg Pending State*************" | tee -a DBConversion.log
	  db2 -tvf reorg.sql > reorg_final.out
	  sh reorg.sh @WINDBName@ @WINDBSchema@
	
	echo "****************************Taking Database Backup**************************** " | tee -a DBConversion.log
		DB_APP_HANDLE=$(db2 list applications | grep @WINDBName@ | awk '{print $3}')
		
			for i in ${DB_APP_HANDLE}
			do
				echo "Forcing Application handles on database @WINDBName@" | tee -a DBConversion.log
				db2 "force applications ($i)" >> output.out
			done
			db2 deactivate database @WINDBName@ >> output.out
			db2 terminate >> output.out
			rm -rf /cygdrive/d/AIX2WinDBConvFilesTemp/WindowsDBFiles/AIX2WindowsFiles/*.001
			db2 backup db @WINDBName@ compress >> output.out
fi