#!/bin/ksh
cd /cygdrive/d/AIX2WinDBConvFilesTemp
WINDBName=$1
WINDBSchema=$2
export DB2CLP=**$$**
db2 connect to $WINDBName >> output.out
db2 set schema $WINDBSchema >> output.out

#update table stats runstats+collect statistics in DBStats Table
before="$(date +%s)" 
echo "************************Updating Table Statistics of Local DB************************" | tee -a /cygdrive/d/AIX2WinDBConvFilesTemp/WindowsDBFiles/AIX2WindowsFiles/DBConversion.log
#echo "CONNECT TO $WINDBName;" > runstats.sql
db2 "select 'RUNSTATS ON TABLE '||trim(TABSCHEMA)||'.'||trim(TABNAME)||';' from syscat.tables where 	
		tabschema='$WINDBSchema' and type='T'" >>WinRunstats.sql
db2 -tvf WinRunstats.sql > WinRunstats.out
db2 "commit" >> output.out
db2 -vm "update DBStats ds set winColCount=(select card from syscat.tables st where st.tabschema='$WINDBSchema' and st.type='T' and st.tabname=ds.tablename)" >>output.out
db2 -vm  "insert into DBStats(tablename,winColCount)
	(select trim(TABNAME),card from syscat.tables st where st.tabschema='$WINDBSchema' and st.type='T'
		and st.TABNAME not in (select tablename from DBStats)" >>output.out		


after="$(date +%s)"
elapsed_seconds="$(expr $after - $before)"
timediff=`echo - | awk -v "S=$elapsed_seconds" '{printf "%dh:%dm:%ds",S/(60*60),S%(60*60)/60,S%60}'`
echo "Time to Update Table Statistics of Windows DB : $timediff" |tee -a /cygdrive/d/AIX2WinDBConvFilesTemp/WindowsDBFiles/AIX2WindowsFiles/Time.log
echo "**************************************************************************" | tee -a /cygdrive/d/AIX2WinDBConvFilesTemp/WindowsDBFiles/AIX2WindowsFiles/DBConversion.log


#Find Objects in converted windows DB and record in DBObjects table
echo "************************Collecting Object Information of windows DB************************" | tee -a /cygdrive/d/AIX2WinDBConvFilesTemp/WindowsDBFiles/AIX2WindowsFiles/DBConversion.log
before="$(date +%s)" 
db2  -vm "update DBObjects do set winObjname=(select trim(TABNAME) from syscat.tables st where tabschema='$WINDBSchema' and type='T' and st.tabname=do.AIXOBJNAME) where ObjType='T'">>output.out
db2 -vm  "update DBObjects do set winObjname=(select trim(TABNAME) from syscat.tables st where tabschema='$WINDBSchema' and type='V' and st.tabname=do.AIXOBJNAME) where ObjType='V'">>output.out
db2 -vm  "update DBObjects do set winObjname=(select trim(ROUTINENAME) from syscat.routines st where ROUTINESCHEMA='$WINDBSchema' and st.ROUTINENAME=do.AIXOBJNAME) where ObjType='P'">>output.out
db2 -vm  "update DBObjects do set winObjname=(select trim(INDNAME) from syscat.INDEXES st where INDSCHEMA='$WINDBSchema' and st.INDNAME=do.AIXOBJNAME) where ObjType='I'">>output.out

db2 -vm  "insert into DBObjects(WinObjname,ObjType)
	(select trim(TABNAME),'T' from syscat.tables st where tabschema='$WINDBSchema' and type='T' 
		and st.TABNAME not in (select AixObjname from DBObjects where ObjType='T'))" >>output.out
db2 -vm  "insert into DBObjects(WinObjname,ObjType)
	(select trim(TABNAME),'V' from syscat.tables st where tabschema='$WINDBSchema' and type='V' 
		and st.TABNAME not in (select AixObjname from DBObjects where ObjType='V'))" >>output.out
db2 -vm  "insert into DBObjects(WinObjname,ObjType)
	(select trim(ROUTINENAME),'P' from syscat.ROUTINES sr where ROUTINESCHEMA='$WINDBSchema'
		and sr.ROUTINENAME not in (select AixObjname from DBObjects where ObjType='P'))" >>output.out
db2 -vm  "insert into DBObjects(WinObjname,ObjType)
	(select trim(INDNAME),'I' from syscat.INDEXES si where INDSCHEMA='$WINDBSchema'
		and si.INDNAME not in (select AixObjname from DBObjects where ObjType='I'))" >>output.out
#Measure Time
after="$(date +%s)"
elapsed_seconds="$(expr $after - $before)"
timediff=`echo - | awk -v "S=$elapsed_seconds" '{printf "%dh:%dm:%ds",S/(60*60),S%(60*60)/60,S%60}'`
echo "Time to collect Object Information of Windows DB : $timediff" |tee -a /cygdrive/d/AIX2WinDBConvFilesTemp/WindowsDBFiles/AIX2WindowsFiles/Time.log
echo "**************************************************************************" | tee -a /cygdrive/d/AIX2WinDBConvFilesTemp/WindowsDBFiles/AIX2WindowsFiles/DBConversion.log

#Generate Objects Report
before="$(date +%s)" 
echo "************Generating DBObjectReport***************************" | tee -a /cygdrive/d/AIX2WinDBConvFilesTemp/WindowsDBFiles/AIX2WindowsFiles/DBConversion.log
echo "**********************DBObjectReport***************************" > DBObjectReport.log

echo "**************Tables Missing in Windows Database*******************" >> DBObjectReport.log
db2 -x "select trim(AixObjname) from DBObjects where ObjType='T' and WinObjname is NULL and AixObjname is not NULL " >> DBObjectReport.log
echo "*******************************************************************" >> DBObjectReport.log

echo "**************Views Missing in Windows Database*******************" >> DBObjectReport.log
db2 -x "select trim(AixObjname) from DBObjects where ObjType='V' and WinObjname is NULL and AixObjname is not NULL" >> DBObjectReport.log
echo "*******************************************************************" >> DBObjectReport.log

echo "**************Procedures Missing in Windows Database*******************" >> DBObjectReport.log
db2 -x "select trim(AixObjname) from DBObjects where ObjType='P' and WinObjname is NULL and AixObjname is not NULL" >> DBObjectReport.log
echo "*******************************************************************" >> DBObjectReport.log

echo "**************Indexes Missing in Windows Database*******************" >> DBObjectReport.log
db2 -x "select trim(AixObjname) from DBObjects where ObjType='I' and WinObjname is NULL and AixObjname is not NULL" >> DBObjectReport.log
echo "*******************************************************************" >> DBObjectReport.log

echo "**************Tables with number of rows mismatch in AIX-Windows Database*******************" >> DBObjectReport.log
db2 -x "select * from DBStats where winColCount < aixColCount and tablename not in ('DBSTATS','DBOBJECTS')" >> DBObjectReport.log
echo "*******************************************************************" >> DBObjectReport.log

echo "**************Inoperative Routines in Windows Database*******************" >> DBObjectReport.log
db2 -x "select substr(ROUTINENAME,1,30) from syscat.routines where valid in ('N','X') and ROUTINESCHEMA='$WINDBSchema'" >> DBObjectReport.log
echo "*******************************************************************" >> DBObjectReport.log

echo "**************Tables in set integrity pending state in Windows Database*******************" >> DBObjectReport.log
db2 -x "select substr(tabname,1,30) from syscat.tables where status='C' and type='T'" >> DBObjectReport.log
echo "*******************************************************************" >> DBObjectReport.log

echo "**************Tables in reorg pending state in Windows Database*******************" >> DBObjectReport.log
db2 -x "select TABNAME from SYSIBMADM.ADMINTABINFO where REORG_PENDING = 'Y'" >> DBObjectReport.log
echo "*******************************************************************" >> DBObjectReport.log

#echo "**************Tables in Database*******************" >> DBObjectReport.log
#db2 -x "select trim(WinObjname) from DBObjects where ObjType='T'" >> DBObjectReport.log
#echo "***************************************************" >> DBObjectReport.log

#echo "**************Indexes in Database*******************" >> DBObjectReport.log
#db2 -x "select trim(WinObjname) from DBObjects where ObjType='I'" >> DBObjectReport.log
#echo "***************************************************" >> DBObjectReport.log

#echo "**************Views in Database*******************" >> DBObjectReport.log
#db2 -x "select trim(WinObjname) from DBObjects where ObjType='V'" >> DBObjectReport.log
#echo "***************************************************" >> DBObjectReport.log

#echo "**************Procedures in Database*******************" >> DBObjectReport.log
#db2 -x "select trim(WinObjname) from DBObjects where ObjType='P'" >> DBObjectReport.log
#echo "***************************************************" >> DBObjectReport.log
#Measure Time
cp DBObjectReport.log /cygdrive/d/AIX2WinDBConvFilesTemp/WindowsDBFiles/AIX2WindowsFiles/
after="$(date +%s)"
elapsed_seconds="$(expr $after - $before)"
timediff=`echo - | awk -v "S=$elapsed_seconds" '{printf "%dh:%dm:%ds",S/(60*60),S%(60*60)/60,S%60}'`
echo "Time to generate windows DB object report : $timediff" |tee -a /cygdrive/d/AIX2WinDBConvFilesTemp/WindowsDBFiles/AIX2WindowsFiles/Time.log
echo "***************************************************" | tee -a /cygdrive/d/AIX2WinDBConvFilesTemp/WindowsDBFiles/AIX2WindowsFiles/DBConversion.log
