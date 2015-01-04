#!/bin/ksh
mailRecipient=$1
DBName=$2
(cat mailMessageBody.txt; uuencode ConversionLogs.zip ConversionLogs.zip ) |  mail -s "AIX To Windows DB Conversion for $DBName DB" $mailRecipient