#!/bin/ksh

rm -rf /cygdrive/d/AIX2WinDBConvFilesTemp

mkdir /cygdrive/d/AIX2WinDBConvFilesTemp

cp /cygdrive/d/AIX2WinDBConvFiles/* /cygdrive/d/AIX2WinDBConvFilesTemp 

dos2unix /cygdrive/d/AIX2WinDBConvFilesTemp/*.sh

sh /cygdrive/d/AIX2WinDBConvFilesTemp/ConversionFiles.sh `awk -F= '{print $2}' /cygdrive/d/DBConversionInfo.properties`

rm -rf /cygdrive/d/AIX2WinDBConvFilesTemp