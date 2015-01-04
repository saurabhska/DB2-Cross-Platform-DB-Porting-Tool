#!/bin/ksh
#Start db2 service
	. $HOME/sqllib/db2profile
#Goto directory which has conversion files
	cd $HOME/AIX2WindowsFiles
#Initialize NULL values to variables
export DB2CLP=**$$**
	AIXDBName=""
	AIXDBSchema=""
	WINDBName=""
	WINDBSchema=""
	WINDBUser=""
	AIXDBUser=""
#Check number of supplied inputs
if [[ $# -eq 6 ]]; then
	AIXDBName=$1
	AIXDBSchema=$2
	AIXDBUser=$3
	WINDBName=$4
	WINDBSchema=$5
	WINDBUser=$6
	before="$(date +%s)"
#Inputs provided
	echo "****************INPUT VALUES for generating dump files on Remote Host************************" | tee -a AixDBConversion.log
	echo "AIX DB NAME: $AIXDBName" | tee -a AixDBConversion.log
	echo "AIX DB SCHEMA: $AIXDBSchema" | tee -a AixDBConversion.log
	echo "AIX DB USER: $AIXDBUser" | tee -a AixDBConversion.log
	echo "WIN DB NAME: $WINDBName" | tee -a AixDBConversion.log
	echo "WIN DB SCHEMA: $WINDBSchema" | tee -a AixDBConversion.log
	echo "WIN DB USER: $WINDBUser" | tee -a AixDBConversion.log
	echo "*****************************************************************************" | tee -a AixDBConversion.log
#Check if DB exists
	CHECK_DB=$(db2 list db directory | grep "Database alias" | awk -F "=" '{print $2}' | grep ${AIXDBName}| wc -l | awk '{print $1}' )
	if (( ${CHECK_DB} < 1 ))
	then
	    echo "On AIX Machine ${AIXDBName} DB does not exist." | tee -a AixDBConversion.log
		exit 
	fi
	
		#Check Space on Server	
		#echo "***********************Checking free Space on Server******************" | tee -a AixDBConversion.log
		#db2 connect to $AIXDBName >>output.out
		#dbsize='`echo `db2 "call get_dbsize_info(?,?,?,-1)" | grep -A 1 DATABASECAPACITY | grep -i Value | awk -F: '{print $2}'` 1024 1024 | awk '{print $1/$2/$3}'`'
		#echo "AIX DB Size is $dbsize MB" | tee -a AixDBConversion.log
		#ssh -l $Username $HostAddress exec avafileSysSizeMB=`df -m ~ | awk  '{print $3}' | grep -v [a-z]`
		#reqfileSysSizeMB=$(($a * 2))
		#echo "Space available on file system $avafileSysSizeMB MB" | tee -a AixDBConversion.log
		#if (( ${reqfileSysSizeMB} > ${avafileSysSizeMB} ))
		#then
		#	echo "Not sufficient space for conversion!!!EXITING!!!" | tee -a AixDBConversion.log
		#	exit 
		#fi
			#echo "*****************************************************************" | tee -a AixDBConversion.log
	
			#Record statistics of AIX DB
			#echo "****************Generating Report Information********************************" | tee -a AixDBConversion.log
			sh generateStats.sh $AIXDBName $AIXDBSchema
			#echo "**********************************************************************" | tee -a AixDBConversion.log
			echo "******************Generating DB2Look File*********************" | tee -a AixDBConversion.log
			db2look -d $AIXDBName -a -x -e -l > $AIXDBName
			echo "******************Generating Data files******************" | tee -a AixDBConversion.log
			sh poormansdb2move.sh $AIXDBName $AIXDBSchema $WINDBName $WINDBSchema
			echo "*******************************************************" | tee -a AixDBConversion.log
			echo "******************Exporting Data******************" | tee -a AixDBConversion.log
			#cat export35.sql | grep -v _  > Newexport35.sql
			#rm -rf export35.sql
			#cp Newexport35.sql export35.sql
			db2 -tvf export35.sql > export35.log
			#gzip -r *.ixf
			echo "*******************************************************" | tee -a AixDBConversion.log
			db2 connect to $AIXDBName >> output.out
			db2 set schema $AIXDBSchema >> output.out

			#------------- set_integrity.sql -----------------
			echo "******************Generating set_integrity.sql******************" | tee -a AixDBConversion.log
			echo "CONNECT TO $WINDBName ;" > set_integrity.sql
			echo "SET SCHEMA $WINDBSchema ;" >> set_integrity.sql
			db2 -x "SELECT 'set integrity for $WINDBSchema.'||TABNAME||' immediate checked ;' FROM SYSCAT.TABLES WHERE TABSCHEMA='$AIXDBSchema' and type='T'" >>set_integrity.sql
			echo "COMMIT;" >> set_integrity.sql
			echo "CONNECT RESET ;" >> set_integrity.sql
			#------------- set_integrity.sql -----------------

			#------------- set_AUTO_REVAL_DB_CFG.sql -----------------
			echo "******************Generating set_AUTO_REVAL_DB_CFG.sql******************" | tee -a AixDBConversion.log
			echo "UPDATE DB CFG FOR $WINDBName USING AUTO_REVAL DEFERRED_FORCE ;" > set_AUTO_REVAL_DB_CFG.sql
			#------------- set_AUTO_REVAL_DB_CFG.sql -----------------

			#------------- alias.sql -----------------
			echo "******************Generating alias.sql******************" | tee -a AixDBConversion.log
			echo "CONNECT TO $WINDBName ;" > alias.sql
			echo "create alias DUAL for sysibm.sysdummy1;" >> alias.sql
			echo "create alias $WINDBSchema.DUAL for sysibm.sysdummy1;" >> alias.sql
			echo "create alias sonedba.DUAL for sysibm.sysdummy1;" >> alias.sql
			echo "create alias devuser.DUAL for sysibm.sysdummy1;" >> alias.sql
			echo "create alias $WINDBUser.DUAL for sysibm.sysdummy1;" >> alias.sql
			#db2 -x "select 'CREATE ALIAS $WINDBSchema.'|| TABNAME ||' FOR $WINDBUser.'|| TABNAME ||';' from syscat.tables where tabschema='$AIXDBSchema'" 	>> alias.sql
			db2 -x "select 'CREATE ALIAS '||TRIM('$WINDBUser')||'.'||TABNAME||' FOR '||TRIM('$WINDBSchema')||'.'||TRIM(BASE_TABNAME)||';' from syscat.tables a where type='A' 
			and exists (select 1 from syscat.tables b where a.tabname=b.tabname and b.type in ('T','V','S'))" >> alias.sql
			#for harris. please comment after use
			db2 -x "select 'CREATE ALIAS '||TRIM('$WINDBSchema')||'.'||TABNAME||' FOR '||TRIM('$WINDBUser')||'.'||TRIM(BASE_TABNAME)||';' from syscat.tables a where type='A' 
			and exists (select 1 from syscat.tables b where a.tabname=b.tabname and b.type in ('T','V','S'))" >> alias.sql
			echo "CONNECT RESET ;" >> alias.sql
			#------------- alias.sql -----------------

			#------------- grant.sql -----------------
			echo "******************Generating grant.sql******************" | tee -a AixDBConversion.log
			echo "CONNECT TO $WINDBName ;" > grant.sql
			echo "GRANT BINDADD  ON DATABASE TO USER $WINDBUser;" >> grant.sql
			echo "GRANT CONNECT  ON DATABASE TO USER $WINDBUser;" >> grant.sql
			#echo "GRANT DBADM WITH DATAACCESS ON DATABASE TO USER $WINDBUser;" >> grant.sql
			#echo "GRANT DBADM WITH DATAACCESS ON DATABASE TO USER db2admin;" >> grant.sql
			#db2 -x "select 'GRANT INSERT,SELECT,UPDATE,DELETE ON $WINDBSchema.'|| TABNAME ||' TO $WINDBUser;' from syscat.tables where
			#	tabschema='$AIXDBSchema'" >> grant.sql
			
			db2 -x "SELECT 'GRANT ' 
       || Substr(T.authstring, 1, Length(T.authstring) - 1) 
       || T.tabname as string
FROM  (SELECT CASE insertauth 
                WHEN 'Y' THEN 'INSERT,' 
                WHEN 'N' THEN '' 
				else ''
              END 
			  || CASE CONTROLAUTH 
                   WHEN 'Y' THEN 'CONTROL,' 
                   WHEN 'N' THEN '' 
				   else ''
                 END 
              || CASE alterauth 
                   WHEN 'Y' THEN 'ALTER,' 
                   WHEN 'N' THEN '' 
				   else ''
                 END 
              || CASE deleteauth 
                   WHEN 'Y' THEN 'DELETE,' 
                   WHEN 'N' THEN '' 
				   else ''
                 END 
              || CASE selectauth 
                   WHEN 'Y' THEN 'SELECT,' 
                   WHEN 'N' THEN '' 
				   else ''
                 END 
              || CASE updateauth 
                   WHEN 'Y' THEN 'UPDATE,' 
                   WHEN 'N' THEN '' 
				   else ''
                 END  AS AUTHSTRING, 
              ' ON ' 
              || TRIM('$WINDBSchema') 
              || '.' 
              || TRIM(tabname) 
              || ' TO ' 
              || CASE granteetype 
                   WHEN 'U' THEN 'USER ' 
                   WHEN 'G' THEN ' ' 
				   else ''
                 END 
              || TRIM('$WINDBUser')
              || ' ;' AS TABNAME 
       FROM   syscat.tabauth 
       WHERE  (insertauth = 'Y' 
               OR alterauth = 'Y' 
               OR deleteauth = 'Y' 
               OR selectauth = 'Y' 
               OR updateauth = 'Y'
			   OR CONTROLAUTH = 'Y') AND  TABSCHEMA='$AIXDBSchema'
			   ) AS T " >> grant.sql
				
			
	db2 -x "SELECT DISTINCT 'GRANT EXECUTE ON PROCEDURE' 
                || ' $WINDBSchema.' 
                || TRIM(b.routinename) 
                || ' TO ' 
                || CASE a.granteetype 
                     WHEN 'U' THEN 'USER ' 
                     ELSE '' 
                   END 
                || '$WINDBUser;' 
FROM   syscat.routineauth a, 
       syscat.routines b 
WHERE  a.specificname = b.specificname 
       AND executeauth <> 'N' 
       AND b.routineschema = '$AIXDBSchema' " >> grant.sql
			
			
			echo "CONNECT RESET ;" >> grant.sql
			#------------- grant.sql -----------------

			#------------- reorg.sql -----------------
			echo "******************Generating reorg.sql******************" | tee -a AixDBConversion.log
			echo "CONNECT TO $WINDBName ;" > reorg.sql
			db2 -x "select 'REORG TABLE $WINDBSchema.'||TABNAME||' ;' from SYSIBMADM.ADMINTABINFO where REORG_PENDING = 'Y'" >> reorg.sql
			db2 -x "select 'REORG TABLE $WINDBSchema.' ||TABNAME||' ;'  from table(sysproc.admin_get_tab_info('$AIXDBSchema','')) as t where
				reorg_pending='Y' " >> reorg.sql
			echo "CONNECT RESET ;" >> reorg.sql
			#------------- reorg.sql -----------------
			
			#------------- refreshMqt.sql -----------------
			echo "******************Generating refreshMqt.sql******************" | tee -a AixDBConversion.log
			echo "CONNECT TO $WINDBName;" > refreshMqt.sql
			db2 -x "select 'refresh table $WINDBSchema.'||tabname||';' from syscat.tables where type='S' and tabschema='$AIXDBSchema'" >> refreshMqt.sql
			echo "CONNECT RESET ;" >> refreshMqt.sql
			#------------- refreshMqt.sql -----------------
			
			echo "****************************Updating tablespace path for windows****************************" | tee -a AixDBConversion.log

			#sed -e 's/\//C:\\DB2\\'$WINDBName'\\/1' -e 's/\//\\/g' tablespaces.sql >> temp.sql

			sed -e 's/\//'$WINDBName'\\/1' -e 's/\//\\/g' -e 's/\\local\\/\\/g' -e 's/\\NODE.*[0-9]\\/\\/g' -e 's/\\db\\/\\/g' -e 's/\\d.*sn1\\/\\/g' -e 	's/\\(/\\/g' -e 's/)\\/\\/g' tablespaces.sql > temp.sql

	# #Backup Original tablespace file
			cp tablespaces.sql Original_tablespaces.sql
			rm -rf tablespaces.sql  
			cp temp.sql tablespaces.sql
			rm -rf temp.sql

			find  -type f -name \*.sql -exec perl -pi.bak -e "s/$AIXDBName/$WINDBName/g" {} \;
			find  -type f -name \*.sql -exec perl -pi.bak -e "s/$AIXDBSchema/$WINDBSchema/g" {} \;
			find  -type f -name tblddl.sql -exec perl -pi.bak -e "s/$AIXDBName/$WINDBName/g" {} \;
			find  -type f -name tblddl.sql -exec perl -pi.bak -e "s/$AIXDBSchema/$WINDBSchema/g" {} \;
			perl -pi.bak -e  "s/\@WINDBName\@/$WINDBName/g" createdb_execute.sh
			perl -pi.bak -e  "s/\@WINDBSchema\@/$WINDBSchema/g" createdb_execute.sh
			perl -pi.bak -e  "s/\@WINDBUser\@/$WINDBUser/g" createdb_execute.sh

			db2 connect reset >> output.out
		
	echo "**************************Zipping the directory for easy transfer**************************" | tee -a AixDBConversion.log
	#curDir=`basename "$PWD"`

	echo "Your exports are in $HOME/AIX2WindowsFiles directory" | tee -a AixDBConversion.log
	#Measure Time
	after="$(date +%s)"
	elapsed_seconds="$(expr $after - $before)"
	timediff=`echo - | awk -v "S=$elapsed_seconds" '{printf "%dh:%dm:%ds",S/(60*60),S%(60*60)/60,S%60}'`
	echo "Time to generate dump files on AIX : $timediff"|tee -a AixTime.log
	cd $HOME
	
	tar -cf AIX2WindowsFiles.tar AIX2WindowsFiles

	if [[ $? -eq 0 ]]; then
		gzip AIX2WindowsFiles.tar 
		echo "Compressed dump files created "|tee -a AixDBConversion.log
	else 
		echo "Error creating .tar.gz file"
		exit
	fi

else
	if [ -z "$AIXDBName"]; then  
		echo "Please give AIXDBName name as third parameter" | tee -a AixDBConversion.log
	fi
	if [ -z "$AIXDBSchema"]; then  
		echo "Please give AIXDB schema name as second parameter" | tee -a AixDBConversion.log
	fi
	if [ -z "$AIXDBUser"]; then  
		echo "Please give AIXDBUser name as third parameter" | tee -a AixDBConversion.log
	fi
	if [ -z "$WINDBName"]; then  
		echo "Please give WINDB name as fourth parameter" | tee -a AixDBConversion.log
	fi
	if [ -z "$WINDBSchema"]; then  
		echo "Please give WINDB schema name as fifth parameter" | tee -a AixDBConversion.log
	fi
	if [ -z "$WINDBUser"]; then  
		echo "Please give WINDBUser name as sixth parameter" | tee -a AixDBConversion.log
	fi

fi
