#!/bin/ksh
#cd /cygdrive/d/AIX2WinDBConvFilesTemp
#export DB2CLP=**$$**
#Inputs
	AIXDBName=$1
	AIXDBSchema=$2
	db2 connect to $AIXDBName >> output.out
	db2 set schema $AIXDBSchema >> output.out

#Collect table stats (runstats+collect statistics in DBStats Table)
	echo "************************Updating Table Statistics of AIX DB************************" | tee -a AixDBConversion.log
	before="$(date +%s)" 
	echo "CONNECT TO $AIXDBName;" > runstats.sql
	db2 -x "select 'RUNSTATS ON TABLE '||trim(TABSCHEMA)||'.'||trim(TABNAME)||' WITH DISTRIBUTION  and  INDEXES ALL;' from syscat.tables where 	
		tabschema='$AIXDBSchema' and type='T' " >>runstats.sql
	echo "COMMIT;" >> runstats.sql
	db2 -tvf runstats.sql > runstats.out
	db2 set schema $AIXDBSchema >> output.out
	db2 drop table DBStats >> output.out
	db2 drop table DBObjects >> output.out
	db2 set schema $AIXDBSchema >> output.out
	db2 "create table DBStats(tablename varchar(50),aixColCount bigint default 0,winColCount bigint default 0) in USERSPACE1" >> output.out
	db2 -vm  "insert into DBStats(tablename,aixColCount)
			(select trim(TABNAME),card from syscat.tables where tabschema='$AIXDBSchema' and type='T' " >>output.out
	after="$(date +%s)"
	elapsed_seconds="$(expr $after - $before)"
	timediff=`echo - | awk -v "S=$elapsed_seconds" '{printf "%dh:%dm:%ds",S/(60*60),S%(60*60)/60,S%60}'`
	echo "Time to update and collect Table Statistics of AIX DB : $timediff" |tee -a AixTime.log
	echo "**************************************************************************" | tee -a AixDBConversion.log
#Collect object stats (collect object information in DBObjects Table)
	echo "************************Collecting Object Information of AIX DB************************" | tee -a AixDBConversion.log
	before="$(date +%s)" 
	db2 "create table DBObjects(AixObjname varchar(50) default NULL,ObjType char(1),winObjname varchar(50) default NULL) in USERSPACE1" >> output.out
	db2  -vm "insert into DBObjects(AixObjname,ObjType)
		(select trim(TABNAME),'T' from syscat.tables where tabschema='$AIXDBSchema' and type='T' " >>output.out
	db2  -vm "insert into DBObjects(AixObjname,ObjType)
		(select trim(TABNAME),'V' from syscat.tables where tabschema='$AIXDBSchema' and type='V' " >>output.out
	db2  -vm "insert into DBObjects(AixObjname,ObjType)
		(select trim(ROUTINENAME),'P' from syscat.ROUTINES where ROUTINESCHEMA='$AIXDBSchema')" >>output.out
	db2  -vm "insert into DBObjects(AixObjname,ObjType)
		(select trim(INDNAME),'I' from syscat.INDEXES where INDSCHEMA='$AIXDBSchema')" >>output.out
	after="$(date +%s)"
	elapsed_seconds="$(expr $after - $before)"
	timediff=`echo - | awk -v "S=$elapsed_seconds" '{printf "%dh:%dm:%ds",S/(60*60),S%(60*60)/60,S%60}'`
	echo "Time to collect Object Information of AIX DB : $timediff" |tee -a AixTime.log
	echo "**************************************************************************" | tee -a AixDBConversion.log