#!/bin/bash
clear
a=$1
HOST=${a%:*}
SID=${a##*:}
STATUS="-1"
VERSION=18.5
INSTANCE="nlcdb"
ICINGA="mon-active01"
echo "Parameter not found"
echo "use FQDN:SID as parameter"
[ -z "$1" ] && exit
clear
VARINVALID='FILL IN STEP 2'
mainmenu () {
echo -e "\e[92mInvalid objects investigation"
echo -e "Selected host FQDN: \e[91m$HOST $SID\e[0m"
echo -e "Oracle version: \e[91m$VERSION\e[0m"
if [ $VERSION = "11.2" ]; then echo -e "Oracle SID: \e[91m$INSTANCE\e[0m for 11.2 selection"; fi
echo -e "Active Icinga: \e[91m$ICINGA\e[0m"
echo " "
echo -e "STEP \e[91m1\e[0m check number of invalid objects"
echo -e "STEP \e[91m2\e[0m get name of invalid objects"
echo -e "STEP \e[91m3\e[0m Resolution for $VARNAME type $VARTYPE"
echo -e "STEP \e[91m4\e[0m Run compilation"
echo " "
echo -e "STEP \e[91mI\e[0m Switch active icinga"
echo -e "STEP \e[91mQ\e[0m Query icinga check"
echo -e "STEP \e[91mV\e[0m Toggle Oracle version"
echo -e "STEP \e[91mL\e[0m UTLRP in loop from list.txt"
echo -e "Press \e[91m0\e[0m to exit"
read -n 1 -p "Input Selection:" mainmenuinput
echo " "
  if [ "$mainmenuinput" = "1" ]; then
        clear
        ssh -qn oracle@$HOST "ORACLE_SID=$INSTANCE; export ORACLE_SID; ORACLE_HOME=/opt/oracle/product/$VERSION; export ORACLE_HOME; /opt/oracle/product/$VERSION/bin/sqlplus "/ as sysdba" <<EOF
	ALTER SESSION SET CONTAINER = $SID;
	spool /tmp/invalid_objects.log
	SELECT count(*) err_cnt FROM DBA_OBJECTS WHERE STATUS='INVALID';
	spool off
	exit
	EOF"
#	scp $HOST:/tmp/invalid_objects.log /tmp/.
#	less /tmp/invalid_objects.log
	echo -e "\e[91mNumber of invalid objects in selected PDB. Press any key to continue.\e[0"
	read -n 1
	clear
        mainmenu

  elif [ "$mainmenuinput" = "2" ]; then
	scp invalid_objects.sql $HOST:/tmp/
	clear
        ssh -qn oracle@$HOST "ORACLE_SID=$INSTANCE; export ORACLE_SID; ORACLE_HOME=/opt/oracle/product/$VERSION; export ORACLE_HOME; /opt/oracle/product/$VERSION/bin/sqlplus "/ as sysdba" <<EOF
        ALTER SESSION SET CONTAINER = $SID;
        spool /tmp/invalid_objects.log
	@/tmp/invalid_objects.sql
        spool off
        exit
        EOF"
	echo " "
        echo 'Please fill information about object'
        read -p 'Invalid object OWNER: ' VAROWNER
	read -p 'Invalid object NAME: ' VARNAME
	read -p 'Invalid object TYPE: ' VARTYPE
        clear
        mainmenu

  elif [ "$mainmenuinput" = "3" ]; then
        clear
	if [[ $VARNAME =~ "SYNC_ISM_AVAILABLE_POS" ]]; then STATUS=1 
	#elif [[ $VAROWNER =~ "NLSCSE" ]]; then STATUS=2
        elif [[ $VARTYPE =~ "PACKAGE BODY" && $VAROWNER =~ "NLSCSE" ]]; then STATUS=3
	elif [[ $VAROWNER =~ "NLSCSE" ]]; then STATUS=2
	else STATUS="-1"
	fi

  #      echo "Status" $STATUS
	if [[ $STATUS = -1 ]]; then echo "RESULT WASN'T FOUND IN STEP 2. PLEASE REPEAT STEP 2"
	elif [[ $STATUS = 0 ]]; then echo "UNDEFINED ENTRIES FOUND IN STEP 2. TRY TO RECOMPILE IT WITH UTLRP IN STEP 4 OR CONTACT JAN"
	elif [[ $STATUS = 1 ]]; then echo -e "ISSUE IDENTIFIED AND TRACKED BY PM-55 \n E-fix 2018.1.0.144 or higher must be installed"
	elif [[ $STATUS = 2 ]]; then echo -e "Can be solved by SuiteCube. Put to pending with link NI-2851"
	elif [[ $STATUS = 3 ]]; then echo -e "Can be solved by SuiteCube. You can try to recompile PACKAGE BODY with STEP 4 and requeue list by STEP 2. Or link to NI-2851 and put to pending"
	else echo "HAVE NO IDEA. RESTART ME"
	fi
	echo -e "\e[91m\n\n Press any key to continue.\e[0"
	read -n 1
        clear
        mainmenu

 elif [ "$mainmenuinput" = "4" ]; then
	clear
	if [[ $VARTYPE =~ "PACKAGE BODY" ]]; 
		then ssh -qn oracle@$HOST "ORACLE_SID=$INSTANCE; export ORACLE_SID; ORACLE_HOME=/opt/oracle/product/$VERSION; export ORACLE_HOME; /opt/oracle/product/$VERSION/bin/sqlplus "/ as sysdba" <<EOF
        ALTER SESSION SET CONTAINER = $SID;
        spool /tmp/invalid_objects.log
        ALTER PACKAGE $VAROWNER"."$VARNAME COMPILE BODY;
        spool off
        exit
	EOF"
	read -n 1
	elif [[ $VARTYPE =~ "PACKAGE" ]];
                then ssh -qn oracle@$HOST "ORACLE_SID=$INSTANCE; export ORACLE_SID; ORACLE_HOME=/opt/oracle/product/$VERSION; export ORACLE_HOME; /opt/oracle/product/$VERSION/bin/sqlplus "/ as sysdba" <<EOF
        ALTER SESSION SET CONTAINER = $SID;
        spool /tmp/invalid_objects.log
        ALTER PACKAGE $VAROWNER"."$VARNAME COMPILE PACKAGE;
        spool off
        exit
        EOF"

	else
        ssh -qn oracle@$HOST "ORACLE_SID=$INSTANCE; export ORACLE_SID; ORACLE_HOME=/opt/oracle/product/$VERSION; export ORACLE_HOME; /opt/oracle/product/$VERSION/bin/sqlplus "/ as sysdba" <<EOF
        ALTER SESSION SET CONTAINER = $SID;
        spool /tmp/invalid_objects.log
	@?/rdbms/admin/utlrp.sql        
        spool off
        exit
	EOF"
	fi
	
	clear
	echo "Compilation Finished. Try result with STEP 1"
	mainmenu

 elif [ "$mainmenuinput" = "I" ] || [  "$mainmenuinput" = "i" ]; then
	if [ $ICINGA = "mon-active01.svale.netledger.com" ]; then ICINGA="mon-active01.dub.netledger.com"
	elif [ $ICINGA = "mon-active01.dub.netledger.com" ]; then ICINGA="mon-active01.bos.netledger.com"
	elif [ $ICINGA = "mon-active01.bos.netledger.com" ]; then ICINGA="mon-active01.sea.netledger.com"
	elif [ $ICINGA = "mon-active01.sea.netledger.com" ]; then ICINGA="mon-active01.chi.netledger.com"
        elif [ $ICINGA = "mon-active01.chi.netledger.com" ]; then ICINGA="mon-active01.ams.netledger.com"
	else ICINGA="mon-active01.svale.netledger.com"	
	fi
	clear
	mainmenu

 elif [ "$mainmenuinput" = "Q" ] || [  "$mainmenuinput" = "q" ]; then
        if [ $ICINGA = "mon-active01.svale.netledger.com" ]; then ICINGA="mon-active01.dub.netledger.com"
        elif [ $ICINGA = "mon-active01.dub.netledger.com" ]; then ICINGA="mon-active01.bos.netledger.com"
        elif [ $ICINGA = "mon-active01.bos.netledger.com" ]; then ICINGA="mon-active01.sea.netledger.com"
        elif [ $ICINGA = "mon-active01.sea.netledger.com" ]; then ICINGA="mon-active01.chi.netledger.com"
        elif [ $ICINGA = "mon-active01.chi.netledger.com" ]; then ICINGA="mon-active01.ams.netledger.com"
        else ICINGA="mon-active01.svale.netledger.com"
        fi
        clear
        mainmenu

 elif [ "$mainmenuinput" = "V" ] || [  "$mainmenuinput" = "v" ]; then
	if [ $VERSION = "18.5" ]; then VERSION="18.1"; INSTANCE="nlcdb"
        elif [ $VERSION = "18.1" ]; then VERSION="11.2"; INSTANCE=$SID
        else VERSION="18.5"; $INSTANCE="nlcdb"
        fi
        clear
        mainmenu

 elif [ "$mainmenuinput" = "0" ]; then
        exit


 elif [ "$mainmenuinput" = "L" ]; then
	for i in `cat list.txt` ;  do
        ssh -qn oracle@$HOST "ORACLE_SID=nlcdb; export ORACLE_SID; ORACLE_HOME=/opt/oracle/product/$VERSION; export ORACLE_HOME; /opt/oracle/product/$VERSION/bin/sqlplus "/ as sysdba" <<EOF
        ALTER SESSION SET CONTAINER = $i;
        spool /tmp/invalid_objects.log
        @?/rdbms/admin/utlrp.sql
        spool off
        exit
        EOF"
	done;
	mainmenu

  else

            echo "You have entered an invallid selection!"
            echo "Please try again!"
            echo ""
            echo "Press any key to continue..."
            read -n 1
            clear
            mainmenu
        fi
}
mainmenu

