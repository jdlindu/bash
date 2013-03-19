#!/bin/bash

# FILENAME     : del_cmdb_proc.bash 
# DESCRIPTION  : delete registered process information from CMDB
# AUTHOR       : Juliam
# CREATED DATE : 2012-11-29
# LAST MODIFIED: 2012-11-29

source commonFunction.sh
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export LANG=C

URL="http://cmdb1.sysop.duowan.com:8088"

function ip_porc_del 
{
	IP=$1
	PROC=$2
	[[ $(curl $URL/webservice/ipPool/getByIp.do?ip=$IP 2>/dev/null) =~ \"device_id\":([[:digit:]]+), ]] && \
		SERVER_ID=${BASH_REMATCH[1]} || { echo "Specified IP does not exist in CMDB."; return 1; }
	if [ "$PROC" == "" ]
	then
		echo "Specified $PROC does not exist for this IP."
		return 2
	elif [ "$PROC" == "all" ]
	then
		PROC_LIST="$(curl $URL/webservice/serverProc/getByServerId.do?server_id=$SERVER_ID 2>/dev/null|awk '{print $1}')"
		[ "$PROC_LIST" == "" ] && { echo -e "DELETE_RESULT\t$IP\tNULL\tSuccess"; return 254; }
		while read PRO
		do
			VISIT=$(echo "$URL/webservice/pkgRep/del.do?ip=$IP&json=\{\"ip\":\"$IP\",\"exe\":\"$PRO\"\}&server_id=$SERVER_ID")
			[[ $(curl "$VISIT" 2>/dev/null) =~ \"success\":true ]]  && echo -e "DELETE_RESULT\t$IP\t$PRO\tSuccess" || echo -e "DELETE_RESULT\t$IP\t$PRO\tFailed"
		done <<< "$PROC_LIST" 
	else
		VISIT=$(echo "$URL/webservice/pkgRep/del.do?ip=$IP&json=\{\"ip\":\"$IP\",\"exe\":\"$PROC\"\}&server_id=$SERVER_ID")
		[[ $(curl "$VISIT" 2>/dev/null) =~ \"success\":true ]]  && echo -e "DELETE_RESULT\t$IP\t$PROC\tSuccess" || echo -e "DELETE_RESULT\t$IP\t$PROC\tFailed"
	fi
}

parseParameter || exit $?
while read LINE
do
	set -- $LINE
	IP=$1
	shift
	PROCS="$*"
	[ -z "$PROCS" ] && PROCS=all
	ip_porc_del $IP $PROCS
done < <( echo -e "$IP_PROC" )

code=0; msg="del_cmdb_proc.bash successful."
echo "$code" "$msg"
exit $code
