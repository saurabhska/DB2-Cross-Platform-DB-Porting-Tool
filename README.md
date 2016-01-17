DB2-Cross-Platform-DB-Porting-Tool
==================================
- IBM DB2 databases are OS specific. You can't simply take a backup of database from the AIX server and restore it on a Windows 
  server. 
- This tool, once configured, can be triggred manually or via CRON job to automatically port a DB2 database from the AIX to       Windows machine.
- My DB2's Got Talent presentation on the same topic is checked in into the repository as AutomaticDBPortingProcess.pdf
***********************************************************************************************
This tool creates a windows replica of AIX database and has following salient features:

- Automated generation and transfer of dump files from AIX to windows server.
- Uses relative tablespace path to allow multiple restore of same backup image on same windows server.
- Takes care of GENERATED ALWAYS and IDENTITY columns.
- Validates inoperative/invalid objects.
- Removes tables from check/re-org pending state.
- Reduces DB size.
- Generates DB conversion report and error log reports.
- Publishes DB backup by copying it to shared location and notifies the conversion initiator with conversion reports
  and error logs via an email.

***********************************************************************************************

- The DB conversion process makes use of openSSH, so please verify that local-host and remote-host are running openSSH and
  configured to work together with the steps mentioned below:

-- -----------------------------------------------------------------------------------------
Steps to check and set openSSH

In the steps mentioned below, local-host = Windows server and remote-host = AIX server.
-- -----------------------------------------------------------------------------------------
1)Login from the local-host to remote-host using the SSH key authentication to verify whether it works properly using:
	ssh -l <username> <remote-host-IP> 
  If you are able to login, it means openSSH is working as expected, else if you get an error, follow below steps to set openSSH.

2)Verify that local-host and remote-host are running openSSH using:
	ssh -V (It should give you output someting like: OpenSSH_4.3p2, OpenSSL 0.9.8b 04 May 2006)
  
3)Install local-host's public key on the remote-host.
  Copy the content of the public key from the local-host (\home\<username>\.ssh\id_rsa.pub) and paste it to the /home/<username>/.ssh/authorized_keys on the remote-host. 
  If the /home/<username>/.ssh/authorized_keys already has some other public key, you can append this to the end of it. If the .ssh directory under your home directory on remote-host doesn?t exist, please create it.

4)Give appropriate permissions to the .ssh directory on the remote-host using:
	   chmod 755 ~/.ssh
	   chmod 644 ~/.ssh/authorized_keys
   
5)Verify if openSSH is configured using the command mentioned in step 1.

6)Once done, trigger the DB conversion process (as described below). 

-- -------------------------------------------------------
Steps to trigger the DB conversion:
-- -------------------------------------------------------

- Update D:\DBConversionInfo.properties file to provide information for DB conversion.
Eg: 
Username=d97ro1            (Instance owner of AIX server)
HostAddress=11.158.37.01   (AIX server IP Address)
AIXDBName=DPQRS6           (Source DB name on AIX server)
AIXDBSchema=SDPQRA         (Source DB schema on AIX server)
AIXDBUser=SGHUTR           (Source DB user on AIX server)
WINDBName=BPQRS7           (Target DB name on Windows server)
WINDBSchema=STWDBA         (Target DB schema on Windows server)
WINDBUser=DEVUSER          (Target DB user on Windows server)
PriMailRecipient=saurabh.agrawal@gmail.com      (Primary mail recipient) 
SecMailRecipient=ashish.wadnerkar@gmail.com     (Secondary mail recipient) 

Note:
PriMailRecipient will be informed if DB conversion is successful/failed but SecMailRecipient will be informed only if DB conversion is successful. 
This is to make sure that developers (SecMailRecipient) are informed only if windows DB was created successfully and is available for use. If you don't want to inform anyone else keep same vaule for both parameters.

- You can monitor the process on cygwin command prompt and an email will be sent to primary and secondary recipients once
  the process is completed.
  
- Detailed working of openSSH can be found here: http://www.thegeekstuff.com/2008/06/perform-ssh-and-scp-without-entering-password-on-openssh/
  
