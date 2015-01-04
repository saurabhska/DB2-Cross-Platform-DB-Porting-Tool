#!/bin/ksh
#Eg: sh ConversionFiles.sh <USERNAME> <HOSTADDRESS> <AIXDBNAME> <AIXDBSCHEMA> <AIXDBUSER> <WINDBNAME> <WINDBSCHEMA> <WINDBUSER> <mail recipient>
#sh ConversionFiles.sh d97sn1 10.28.33.97 UPGR4001 SONEDBA D97SN1 WNTESTDB WNSCHEMA WNUSER #saurabh.agrawal@aciworldwide.com,prasad.pande@aciworldwide.com
cd /cygdrive/d/AIX2WinDBConvFilesTemp
export DB2CLP=**$$**
if [[ $# -eq 10 ]]; then
	ScriptStart="$(date +%s)"
	Username=$1
	HostAddress=$2
	AIXDBName=$3
	AIXDBSchema=$4
	AIXDBUser=$5
	WINDBName=$6
	WINDBSchema=$7
	WINDBUser=$8
	PriMailRecipient=$9
	SecMailRecipient=${10}
#Inputs Provided
	
	rm -rf *.log *.out mailMessageBody.txt
	echo "****************INPUT VALUES************************" | tee -a WinDBConversion.log
	echo "USERNAME: $Username" | tee -a WinDBConversion.log
	echo "HOST ADDRESS: $HostAddress" | tee -a WinDBConversion.log
	echo "AIX DB NAME: $AIXDBName" | tee -a WinDBConversion.log
	echo "AIX DB SCHEMA: $AIXDBSchema" | tee -a WinDBConversion.log
	echo "AIX DB USER: $AIXDBUser" | tee -a WinDBConversion.log
	echo "WIN DB NAME: $WINDBName" | tee -a WinDBConversion.log
	echo "WIN DB SCHEMA: $WINDBSchema" | tee -a WinDBConversion.log
	echo "WIN DB USER: $WINDBUser" | tee -a WinDBConversion.log
	echo "Primary Email Notification Recipients: $PriMailRecipient" | tee -a WinDBConversion.log
	echo "Secondary Email Notification Recipients: $SecMailRecipient" | tee -a WinDBConversion.log
	echo "*******************************************************" | tee -a WinDBConversion.log

#Start SSH Agent on Local Machine
	#echo "***********************Adding OpenSSHAgent***********************" | tee -a WinDBConversion.log
	#eval `ssh-agent -s` > output.out
	#eval `ssh-add` >> output.out
	#echo "*****************************************************************" | tee -a WinDBConversion.log
	
#Clean Directory on remote server
	echo "***********************Removing Files on Remote Host***********************" | tee -a WinDBConversion.log
	ssh -l $Username $HostAddress exec 'rm -rf $HOME/AIX2WindowsFiles*' 
	echo "***************************************************************************" | tee -a WinDBConversion.log

#Make directory to copy files
	echo "***********************Making Directory on Remote Host***********************" | tee -a WinDBConversion.log
	ssh -l $Username $HostAddress exec 'mkdir $HOME/AIX2WindowsFiles' 
	echo "*****************************************************************************" | tee -a WinDBConversion.log

#Copy files to remote server
	before="$(date +%s)"
	echo "***********************Copying Files on Remote Host***********************" | tee -a WinDBConversion.log
	scp ConversionFiles.sh $Username@$HostAddress:'$HOME/AIX2WindowsFiles'
	scp createdb_execute.sh $Username@$HostAddress:'$HOME/AIX2WindowsFiles'
	scp db2move_execute.sh $Username@$HostAddress:'$HOME/AIX2WindowsFiles'
	scp poormansdb2move.sh $Username@$HostAddress:'$HOME/AIX2WindowsFiles'
	scp generateStats.sh $Username@$HostAddress:'$HOME/AIX2WindowsFiles'
	scp Step.txt $Username@$HostAddress:'$HOME/AIX2WindowsFiles'
	scp postDumpGeneration.sh $Username@$HostAddress:'$HOME/AIX2WindowsFiles'
	scp generateReport.sh $Username@$HostAddress:'$HOME/AIX2WindowsFiles'
	scp set_integrity.sh $Username@$HostAddress:'$HOME/AIX2WindowsFiles'
	scp reorg.sh $Username@$HostAddress:'$HOME/AIX2WindowsFiles'
	echo "**************************************************************************" | tee -a WinDBConversion.log
	

#Remove Windows Characters
	echo "***********************Converting files to UNIX Format on Remote Host***********************" | tee -a WinDBConversion.log
	ssh -l $Username $HostAddress exec 'perl -p -i -e "s/^M//g" $HOME/AIX2WindowsFiles/ConversionFiles.sh'
	ssh -l $Username $HostAddress exec 'perl -p -i -e "s/^M//g" $HOME/AIX2WindowsFiles/db2move_execute.sh'
	ssh -l $Username $HostAddress exec 'perl -p -i -e "s/^M//g" $HOME/AIX2WindowsFiles/createdb_execute.sh'
	ssh -l $Username $HostAddress exec 'perl -p -i -e "s/^M//g" $HOME/AIX2WindowsFiles/poormansdb2move.sh'
	ssh -l $Username $HostAddress exec 'perl -p -i -e "s/^M//g" $HOME/AIX2WindowsFiles/postDumpGeneration.sh'
	ssh -l $Username $HostAddress exec 'perl -p -i -e "s/^M//g" $HOME/AIX2WindowsFiles/generateStats.sh'
	ssh -l $Username $HostAddress exec 'perl -p -i -e "s/^M//g" $HOME/AIX2WindowsFiles/generateReport.sh'
	ssh -l $Username $HostAddress exec 'perl -p -i -e "s/^M//g" $HOME/AIX2WindowsFiles/set_integrity.sh'
	ssh -l $Username $HostAddress exec 'perl -p -i -e "s/^M//g" $HOME/AIX2WindowsFiles/reorg.sh'
#Measure Time	
	after="$(date +%s)"
	elapsed_seconds="$(expr $after - $before)"
	timediff=`echo - | awk -v "S=$elapsed_seconds" '{printf "%dh:%dm:%ds",S/(60*60),S%(60*60)/60,S%60}'`
	echo "File Transfer time : $timediff" | tee -a WinTime.log
	#scp Time.log $Username@$HostAddress:'$HOME/AIX2WindowsFiles'
	echo "********************************************************************************************" | tee -a WinDBConversion.log

#Generate Dump Files on Remote Server
	echo "***********************Generating Dump Files on Remote Host***********************" | tee -a WinDBConversion.log
	#scp DBConversion.log $Username@$HostAddress:'$HOME/AIX2WindowsFiles'
	ssh -l $Username $HostAddress exec 'chmod -R a+x $HOME/AIX2WindowsFiles'
	ssh -l $Username $HostAddress exec sh '$HOME'/AIX2WindowsFiles/db2move_execute.sh $AIXDBName $AIXDBSchema $AIXDBUser $WINDBName $WINDBSchema $WINDBUser
	echo "**********************************************************************************" | tee -a WinDBConversion.log

#Create DB on Windows
	sh postDumpGeneration.sh $Username $HostAddress $WINDBName $AIXDBName $AIXDBSchema $WINDBSchema $AIXDBUser $WINDBUser


	 
	#rm -rf output.out
#Measure Total Script Execution Time
	#cd WindowsDBFiles-----------------------------------------------------------------------------------------
	
	#cd ../..
	 
	# rm -rf ConversionLogs >> output.out
	# mkdir ConversionLogs >> output.out
	# cp ./WindowsDBFiles/AIX2WindowsFiles/*.out ./ConversionLogs
	# cp ./WindowsDBFiles/AIX2WindowsFiles/*.log ./ConversionLogs
	# rm -rf ./ConversionLogs/Aix* ./ConversionLogs/temp* ./ConversionLogs/Win* ./ConversionLogs/export35.log ./ConversionLogs/output.out 
	# rm -rf ./ConversionLogs/WindowsDBFiles
	# zip -q ConversionLogs.zip ./ConversionLogs/* 
#Sending Email
#CHECK_DB=$(db2 list db directory | grep "Database name" | awk -F "=" '{print $2}' | grep $WINDBName| wc -l | awk '{print $1}' )
#CHECK_DB=`ls -l /cygdrive/d/AIX2WinDBConvFilesTemp/WindowsDBFiles/AIX2WindowsFiles | grep -i $WINDBName | awk '{print $9}' | grep -i .001.zip | wc-l`
#if (( ${CHECK_DB} < 1 ))
#then
echo "*********************Zipping database backup copy*********************" | tee -a /cygdrive/d/AIX2WinDBConvFilesTemp/WindowsDBFiles/AIX2WindowsFiles/DBConversion.log
	rm -rf /cygdrive/d/AIX2WinDBConvFilesTemp/WindowsDBFiles/AIX2WindowsFiles/*001.zip
	dbname=""
	#echo "*******************DBName1 is $dbname****************"
	dbname=`ls -l /cygdrive/d/AIX2WinDBConvFilesTemp/WindowsDBFiles/AIX2WindowsFiles | grep -i $WINDBName | awk '{print $9}' | grep -i .001`
	#echo "*******************DBName is $dbname****************" | tee -a ./WindowsDBFiles/AIX2WindowsFiles/DBConversion.log
	rm -rf /cygdrive/d/AIX2WinDBConvFilesTemp/WindowsDBFiles/AIX2WindowsFiles/$dbname.zip  >> output.out
	 DB_APP_HANDLE=$(db2 list applications | grep ${WINDBName} | awk '{print $3}')
		
			for i in ${DB_APP_HANDLE}
			do
				
				db2 "force applications ($i)" >> output.out
			done
			db2 deactivate database ${WINDBName} >> output.out
			db2 terminate >> output.out
			db2 drop db ${WINDBName} >> output.out
	  
	cd /cygdrive/d/AIX2WinDBConvFilesTemp/WindowsDBFiles/AIX2WindowsFiles/;
	zip -q $dbname.zip $dbname
if [[ $? -eq 0 ]]; then
cd  /cygdrive/d/AIX2WinDBConvFilesTemp;
	echo "*********************Copying zipped database backup copy to \\\\cltep16\Share\backup\DB2\current*********************" | tee -a /cygdrive/d/AIX2WinDBConvFilesTemp/WindowsDBFiles/AIX2WindowsFiles/DBConversion.log
	cp /cygdrive/d/AIX2WinDBConvFilesTemp/WindowsDBFiles/AIX2WindowsFiles/$dbname.zip   //nrcdba02/Share/backup/DB2/current
	cp   /cygdrive/d/AIX2WinDBConvFilesTemp/WindowsDBFiles/AIX2WindowsFiles/$dbname.zip //cltep16/Share/backup/DB2/current
	
	echo "Windows DB backup is available at \\\\cltep16\Share\backup\DB2\current and \\\\nrcdba02\Share\backup\DB2\current" | tee -a /cygdrive/d/AIX2WinDBConvFilesTemp/WindowsDBFiles/AIX2WindowsFiles/DBConversion.log
	
	#echo "Windows DB backup is available at \\cltep16\Share\backup\DB2\current" | tee -a /cygdrive/d/AIX2WinDBConvFilesTemp/WindowsDBFiles/AIX2WindowsFiles/DBConversion.log
	 echo "Hi," > mailMessageBody.txt
	 echo "  " >> mailMessageBody.txt
	 echo "Aix to Windows DB Conversion has completed successfully!!!" >> mailMessageBody.txt
	 echo "">>mailMessageBody.txt
	 echo "AIX DB NAME: $AIXDBName" >> mailMessageBody.txt
	 echo "WIN DB NAME: $WINDBName" >> mailMessageBody.txt
	 echo "  ">> mailMessageBody.txt
	 echo "PFA DB conversion logs for your review.">> mailMessageBody.txt
	 echo "  ">> mailMessageBody.txt
	 echo "Windows Copy of backup is available at \\\\nrcdba02\Share\backup\DB2\current  and \\\\cltep16\Share\backup\DB2\current as ${dbname}.zip" >> mailMessageBody.txt
	 #echo "Windows Copy of backup is available at \\\\nrcdba02\Share\backup\DB2\current\ as ${dbname}.zip" >> mailMessageBody.txt
	 echo "  ">> mailMessageBody.txt
	 ScriptEnd="$(date +%s)"
	 elapsed_seconds="$(expr $ScriptEnd - $ScriptStart)"
	 ScriptExecutionTime=`echo - | awk -v "S=$elapsed_seconds" '{printf "%dh:%dm:%ds",S/(60*60),S%(60*60)/60,S%60}'`
	 echo "Total time taken by DB Conversion Process : $ScriptExecutionTime" | tee -a /cygdrive/d/AIX2WinDBConvFilesTemp/WindowsDBFiles/AIX2WindowsFiles/Time.log
	 echo "Total time taken by DB Conversion Process : $ScriptExecutionTime" >> mailMessageBody.txt
	 echo "  ">> mailMessageBody.txt
	rm -rf ConversionLogs >> output.out
	mkdir ConversionLogs >> output.out
	cp ./WindowsDBFiles/AIX2WindowsFiles/*.out ./ConversionLogs
	cp ./WindowsDBFiles/AIX2WindowsFiles/*.log ./ConversionLogs
	cp ./WindowsDBFiles/AIX2WindowsFiles/*.sql ./ConversionLogs
	cp ./WindowsDBFiles/AIX2WindowsFiles/*.sh ./ConversionLogs
	rm -rf ./ConversionLogs/Aix* ./ConversionLogs/temp* ./ConversionLogs/Win* ./ConversionLogs/export35.log ./ConversionLogs/output.out 
	rm -rf ./ConversionLogs/WindowsDBFiles
	zip -q ConversionLogs.zip ./ConversionLogs/*
	 echo "*******************************************************************************************************************************" >> mailMessageBody.txt
	 echo "This is a system generated email. Please don't reply to this mail. Please contact DBA Team in case of issues.">> mailMessageBody.txt
	 echo "*******************************************************************************************************************************" >> mailMessageBody.txt
	 #10.128.97.11 = nrcdba01
	 scp mailMessageBody.txt d97sn1@10.128.97.11:'$HOME'
	 scp ConversionLogs.zip d97sn1@10.128.97.11:'$HOME'
	 scp sendmail.sh d97sn1@10.128.97.11:'$HOME'
	 ssh -l d97sn1 10.128.97.11 exec 'perl -p -i -e "s/^M//g" $HOME/sendmail.sh'
	 
	 ssh -l d97sn1 10.128.97.11 exec sh '$HOME'/sendmail.sh `echo "$PriMailRecipient,$SecMailRecipient"` $AIXDBName
	 
	 #already deleted in postDumpGeneration.sh still to cross check and confirm deleting again
	ssh -l $Username $HostAddress exec 'rm -rf ~/AIX2WindowsFiles*'
	ssh -l $Username $HostAddress exec 'rm -rf ~/AixDBConversion.log'
	ssh -l $Username $HostAddress exec 'rm -rf ~/AIX2WindowsFiles'
	 
	else 
		cd  /cygdrive/d/AIX2WinDBConvFilesTemp;
	 echo "Hi," > mailMessageBody.txt
	 echo "  " >> mailMessageBody.txt
	 echo "Aix to Windows DB Conversion has FAILED!!!" >> mailMessageBody.txt
	 echo "">>mailMessageBody.txt
	 #echo "AIX DB NAME: $AIXDBName" >> mailMessageBody.txt
	 #echo "WIN DB NAME: $WINDBName" >> mailMessageBody.txt
	 echo "PFA DB conversion logs for your review.">> mailMessageBody.txt
	 #echo "Windows Copy of backup is available at \\pun-san02\PubTemp\Aix2WindowsBackup as ${dbname}.zip" >> mailMessageBody.txt
	 #echo "Total time taken by DB Conversion Process : $ScriptExecutionTime" >> mailMessageBody.txt
	 echo "  ">> mailMessageBody.txt
	
	 echo "*******************************************************************************************************************************" >> mailMessageBody.txt
	 echo "This is a system generated email. Please don't reply to this mail. Please contact DBA Team in case of issues.">> mailMessageBody.txt
	 echo "*******************************************************************************************************************************" >> mailMessageBody.txt
	 #10.128.97.11 = nrcdba01
	 scp mailMessageBody.txt d97sn1@10.128.97.11:'$HOME'
	 scp ConversionLogs.zip d97sn1@10.128.97.11:'$HOME'
	 scp sendmail.sh d97sn1@10.128.97.11:'$HOME'
	 ssh -l d97sn1 10.128.97.11 exec 'perl -p -i -e "s/^M//g" $HOME/sendmail.sh'
	 
	 ssh -l d97sn1 10.128.97.11 exec sh '$HOME'/sendmail.sh $PriMailRecipient $AIXDBName
	
	#already deleted in postDumpGeneration.sh still to cross check and confirm deleting again
	ssh -l $Username $HostAddress exec 'rm -rf ~/AIX2WindowsFiles*'
	ssh -l $Username $HostAddress exec 'rm -rf ~/AixDBConversion.log'
	ssh -l $Username $HostAddress exec 'rm -rf ~/AIX2WindowsFiles'
	
	
	 
fi

	
	# ssh -l $Username $HostAddress exec 'rm -rf $HOME/mailMessageBody.txt $HOME/ConversionLogs.zip $HOME/sendmail.sh  $HOME/AixDBConversion.log'
	# ssh -l $Username $HostAddress exec 'rm -rf $HOME/AIX2WindowsFiles*'
	 

	#kill $SSH_AGENT_PID
else
#display error if script is executed without proper arguments
	echo "Run with proper arguments" | tee -a WinDBConversion.log
echo "Syntax- sh ConversionFiles.sh <USERNAME> <HOSTADDRESS> <AIXDBNAME> <AIXDBSCHEMA> <AIXDBUSER> <WINDBNAME> <WINDBSCHEMA> <WINDBUSER> <mail-recipients>" | tee -a WinDBConversion.log
fi