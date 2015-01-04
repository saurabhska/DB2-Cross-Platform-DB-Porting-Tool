#!/bin/ksh
#db2look -d db82026 -z sdb82026 -e -l -f -c -x -o db82026.db2look
#sed -n '/CREATE TABLE /,/TERMINATE/p'
. $HOME/sqllib/db2profile
cd $HOME/AIX2WindowsFiles
export DB2CLP=**$$**
db2lookfile=$1
AIXDBSchema=$2
WINDBName=$3
WINDBSchema=$4
if [[ ! -f $db2lookfile ]]
then
   echo "\n\nUsage: $0 db2lookfile"
   echo " or - file not found\n"
   lookfiles=$(grep -l DB2LOOK * | grep -v poor)
   echo "Possible db2look files: \n $lookfiles \n\n"
   exit 2
fi

dt=$(date +"%Y%m%d%H%M")
tblsfile=tblsfromdb2look.$dts
genalways=genalways.$dt

# split fk from rest of ddl
echo "Creating separate files for foreign keys and rest of ddl from $db2lookfile ...." | tee -a AixDBConversion.log
   # remove prev sqls
db=$(perl -nle '/"S(DB\w*)"/ and print $1 and close ARGV;' $db2lookfile)
[[ -f tblddl.sql ]] && rm tblddl.sql
echo "CONNECT TO $WINDBName ;" > fks.sql 


perl -00nle 'BEGIN {open TF, ">> tblddl.sql"; open FK, ">> fks.sql"; } if ( /FOREIGN KEY/ ) { print FK; } else { print TF; }; END {close TF,FK;}' $db2lookfile
echo "COMMIT ;" >> fks.sql
echo "CONNECT RESET ;" >> fks.sql 
echo "CONNECT TO $WINDBName ;" > tablespaces.sql
echo "Creating separate files for tablespaces and rest of ddl from $db2lookfile ...." | tee -a AixDBConversion.log
perl -00nle 'BEGIN {open TS, ">> tablespaces.sql"; open RM, ">> temp.sql"; } if ( /TABLESPACE/ ) { print TS; } else { print RM; }; END {close TS,RM;}' tblddl.sql
echo "COMMIT ;" >> tablespaces.sql
echo "CONNECT RESET ;" >> tablespaces.sql
cp tblddl.sql Original1_tblddl.sql
rm -rf tblddl.sql  
cp temp.sql tblddl.sql
rm -rf temp.sql

echo "CONNECT TO $WINDBName ;" > bufferpools.sql
echo "Creating separate files for bufferpools and rest of ddl from $db2lookfile ...." | tee -a AixDBConversion.log
perl -00nle 'BEGIN {open BP, ">> bufferpools.sql"; open FI, ">> temp.sql"; } if ( /BUFFERPOOL/ ) { print BP; } else { print FI; }; END {close BP,FI;}' tblddl.sql
echo "COMMIT ;" >> bufferpools.sql
echo "CONNECT RESET ;" >> bufferpools.sql
cp tblddl.sql Original2_tblddl.sql
rm -rf tblddl.sql  
cp temp.sql tblddl.sql
rm -rf temp.sql


perl -pi.bak -e 's/^/--/ if /^\s*UPDATE DB/;' tblddl.sql

# get list of file names (excluding TMP_ and EXC_)
echo "Generating tablename file  from $db2lookfile ...." | tee -a AixDBConversion.log
perl -nle '/CREATE TABLE ".*"\."(\w+)" / and $name=$1 and $name !~ /^TMP\_|^EXC\_/  and print $name;' $db2lookfile > $tblsfile

#get list of tables with generated always
echo "Generating generated always tablename file  from $db2lookfile ...." | tee -a AixDBConversion.log
#echo "TABLES with GENERATED ALWAYS COLUMNS" | tee -a AixDBConversion.log
#echo "====================================" | tee -a AixDBConversion.log
perl -00nle 'chomp;/GENERATED ALWAYS/ and /CREATE TABLE ".*"\."(\w+)" / and $name=$1 and  $name !~ /^TMP\_|^EXC\_/ and print $name;' $db2lookfile | sed -e /^$/d > $genalways

perl -00nle 'chomp;/GENERATED ALWAYS AS IDENTITY/ and /CREATE TABLE ".*"\."(\w+)" / and $name=$1 and  $name !~ /^TMP\_|^EXC\_/ and print $name;' $db2lookfile | sed -e /^$/d > IDENTITY

sleep 1
echo "connect to $db2lookfile ;" >  export35.sql
echo "connect to $WINDBName ;" >  load35.sql 

echo "set current schema $AIXDBSchema ;" >>  export35.sql
echo "set current schema $WINDBSchema ;" >>  load35.sql 


echo "Generating export and load files ...." | tee -a AixDBConversion.log
		
for x in $(cat $tblsfile)
        do
         grep -w $x IDENTITY
           if [[ $? -eq 0 ]]
           then
                echo "load client from ${x}.ixf of ixf modified by identityignore insert into $x ;" >> load35.sql
           else 
				grep -w $x $genalways
				if [[ $? -eq 0 ]]
				then
					echo "load client from ${x}.ixf of ixf modified by generatedoverride insert into $x ;" >> load35.sql
				else
					echo "load client from ${x}.ixf of ixf insert into $x ;" >> load35.sql
				fi
			fi
            echo "export to ${x}.ixf  of ixf select * from ${x} ;" >> export35.sql
        done
echo "CONNECT RESET ;" >> export35.sql
echo "CONNECT RESET ;" >> load35.sql		