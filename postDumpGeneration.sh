#!/bin/ksh
export DB2CLP=**$$**
cd /cygdrive/d/AIX2WinDBConvFilesTemp
#input
	Username=$1
	HostAddress=$2
	WINDBName=$3
	AIXDBName=$4
	AIXDBSchema=$5
	WINDBSchema=$6
	AIXDBUser=$7
	WINDBUser=$8
#Measure time
	before="$(date +%s)"
#clean existing files (if any)
	rm -rf AIX2WindowsFiles* >> output.out
	rm -rf WindowsDBFiles >> output.out
#create a dir to copy dump files
	mkdir WindowsDBFiles >> output.out
	cp WinDBConversion.log ./WindowsDBFiles
	cp WinTime.log ./WindowsDBFiles
	cd WindowsDBFiles
	
	echo "************Copying Dump Files to Local Machine******************" | tee -a tempDBConversion.log
	scp $Username@$HostAddress:~/AIX2WindowsFiles.tar.gz .
	if [[ $? -eq 0 ]]; then #if copy successful
#Measure Time
		after="$(date +%s)"
		elapsed_seconds="$(expr $after - $before)"
		timediff=`echo - | awk -v "S=$elapsed_seconds" '{printf "%dh:%dm:%ds",S/(60*60),S%(60*60)/60,S%60}'`
		echo "Time to copy dump files to local machine : $timediff" |tee -a tempTime.log
		echo "*****************************************************************" | tee -a tempDBConversion.log
		ssh -l $Username $HostAddress exec 'rm -rf ~/AIX2WindowsFiles*'
		echo "************Unzipping Dump Files on Local Machine****************" | tee -a tempDBConversion.log
		CreateDBBefore="$(date +%s)"
		gunzip AIX2WindowsFiles.tar.gz
		if [[ $? -eq 0 ]]; then
			tar -xmf AIX2WindowsFiles.tar	
		else 
			echo "Error extracting .gz file" | tee -a tempDBConversion.log
			exit
		fi
		if [[ $? -eq 0 ]]; then
			#gunzip -r ./AIX2WindowsFiles/*.gz
			cp WinDBConversion.log ./AIX2WindowsFiles
			cp WinTime.log ./AIX2WindowsFiles
			cp tempDBConversion.log ./AIX2WindowsFiles
			cp tempTime.log ./AIX2WindowsFiles
			cd AIX2WindowsFiles	
			cat WinDBConversion.log >> DBConversion.log
			cat AixDBConversion.log >> DBConversion.log
			cat tempDBConversion.log >> DBConversion.log
			cat WinTime.log >> Time.log
			cat AixTime.log >> Time.log
			cat tempTime.log >> Time.log
			#rm -rf WinDBConversion.log AixDBConversion.log tempDBConversion.log WinTime.log AixTime.log tempTime.log
		else 
			echo "Error extracting tar file" | tee -a tempDBConversion.log
			exit
		fi
		echo "*****************************************************************" | tee -a DBConversion.log
#Replace proper values
		perl -pi.bak -e  "s/$AIXDBName/$WINDBName/g" tblddl.sql
		perl -pi.bak -e  "s/$AIXDBSchema/$WINDBSchema/g" tblddl.sql
		perl -pi.bak -e  "s/$AIXDBUser/$WINDBUser/g" tblddl.sql
		perl -pi.bak -e  "s/$AIXDBName/$WINDBName/g" fks.sql
		perl -pi.bak -e  "s/$AIXDBSchema/$WINDBSchema/g" fks.sql
		perl -pi.bak -e  "s/$AIXDBUser/$WINDBUser/g" fks.sql
#Check if DB exists
		CHECK_DB=$(db2 list db directory | grep "Database alias" | awk -F "=" '{print $2}' | grep ${WINDBName}| wc -l | awk '{print $1}' )

		if (( ${CHECK_DB} < 1 ))
		then
			echo "${WINDBName} does not exist, database will be created." | tee -a DBConversion.log
			sh createdb_execute.sh 
		else
			echo "Database ${WINDBName} exists and will be dropped" | tee -a DBConversion.log
			echo "Forcing any connections that still exist to the database..." | tee -a DBConversion.log
			#echo "" | tee -a DBConversion.log

			DB_APP_HANDLE=$(db2 list applications | grep ${WINDBName} | awk '{print $3}')
		
			for i in ${DB_APP_HANDLE}
			do
				echo "Forcing Application handles on ${WINDBName}" | tee -a DBConversion.log
				db2 "force applications ($i)" >> output.out
			done
			db2 deactivate database ${WINDBName} >> output.out
			db2 terminate >> output.out

			echo "Dropping previous version of database and creating new database" | tee -a DBConversion.log
			db2 drop db ${WINDBName} >> output.out
			db2 terminate >> output.out
			echo "Dropped database ${WINDBName}" | tee -a DBConversion.log
			sh createdb_execute.sh   
		fi
		CreateDBAfter="$(date +%s)"
		elapsed_seconds="$(expr $CreateDBAfter - $CreateDBBefore)"
		timediff=`echo - | awk -v "S=$elapsed_seconds" '{printf "%dh:%dm:%ds",S/(60*60),S%(60*60)/60,S%60}'`
		echo "Time to Create DB,Reduce DB size and Backup the DB : $timediff" |tee -a Time.log
			
	else 
		echo "Error copying dump files" | tee -a tempDBConversion.log
		exit
	fi
