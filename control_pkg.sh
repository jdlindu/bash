#!/bin/bash

#
set -o pipefail

FUNCNAME=$(basename $0)

function prompt_tip {
	error_exit "Usage: $(basename $0) [ -v ] pkg version start|stop|restart [ -y ]" 1
}

function info_log {

   local content

   while read content; do
	if [[ "$DEBUG" == "TRUE" ]];then
		printf "%s\n" "$content"
	fi
   	printf "%s | %s | [ info ] | %s\n" "$(date +'%F %T')" "$SUDO_USER" "$content" 1>&2 >> $logFile

   done < <(echo -e "$*")

   return
}

function check_privilege(){
	if [ "$UID" -ne 0 ] ; then
		error_exit "only root can run this script!" 1
	fi
}
function confirm(){
	if [[ "$1" != "-y" ]] ;then
        error_exit "Action cancel,to confirm this action you must append -y option" 1
	fi
}


function pkg_tip(){
	local pkgs=$(ls -F /data/services | egrep ".*$pkgName.*-.*/$" | awk -F- '{print $1}')
	if [ -n "$pkgs" ] ; then
		info_log "maybe you are looking for these pkg \n$pkgs"
	fi
}

function check_pkgname(){

	if [ -z "$1" ];then
		prompt_tip
	else
		pkgDir=$(ls -F /data/services | egrep "^$pkgName-.*/$")
		if [ -z "$pkgDir" ] ; then
			info_log "pkgName=$pkgName not exist!"
			pkg_tip
			error_exit info_log "pkgName=$pkgName not exist!" 1
		fi
	fi
}

function check_version(){
	local pkgPath="$pkgHomeDir/$1-$2"
	local versions=$(ls -F /data/services | egrep "^$pkgName-.*/$" | awk -F'-|/' '{print $2}')
	if [[ -z "$2" ]] ; then
		info_log "version cannot be null,posibble version is :\n$versions"
		error_exit "version cannot be null,posibble version is :\n$versions" 1
	else
		if [ ! -d "$pkgPath" ] ; then
                	info_log "wrong version !! possible version is : \n$versions"
                	error_exit "wrong version !! possible version is : \n$versions" 1
        	fi		
	fi
}

function add_cron {

   local pkg=${1:?$FUNCNAME [ERR ] | pkg name is NULL}

   local ver=${2:?$FUNCNAME [ERR ] | version is NULL}

   local inputFile="$pkgScriptPath/crontab.conf"

   if [ ! -f $inputFile ] ; then
 
        info_log "Oops ! $inputFile not exist !"

        exit 
   else
        info_log "great ! $inputFile exist"

        info_log "$(ls -l $inputFile)"
   fi

   # crontab entry syntax check

   while read line ; do

       x=$(info_log "$line" | awk '$1 !~ /[ 	]*#/ && NF < 7')

       if [ -n "$x" ] ; then

            info_log "cron entry [$line] syntax err"

            exit
       else
            if ! grep -q -x -F "$line" /etc/crontab ; then

                info_log "$line" >> /etc/crontab

                info_log "add entry [$line]" 
           else
                info_log "entry [$line] existed" 
           fi                    
       fi

  done < $inputFile

  rc=$?

  # enforce to remove .no-autostart file under admin/

  info_log "add cron & clean NO_AUTO_START_FLAG_FILE"

  info_log "$(rm -fv $PKG_HOME_DIR/$pkg-$ver/admin/.no-autostart)"

  return $rc
}

function del_cron {

   local pkg=${1:?$FUNCNAME [ERR ] | pkg name is NULL}

   local ver=${2:?$FUNCNAME [ERR ] | version is NULL}

   local inputFile="$pkgScriptPath/crontab.conf"

   local noAutoStartFlagFile="$pkgScriptPath/.no-autostart"

   if [ ! -r $inputFile ] ; then

        info_log "$inputFile read permission denied or not exist"

        exit
   fi

   # do not backup crontab file

   #cp /etc/crontab /etc/crontab.$(date +'%F_%T')

   while read line ; do

        grep -v -F "$line" /etc/crontab > /tmp/crontab.$$ && \

        mv /tmp/crontab.$$ /etc/crontab && \

        info_log "del entry [$line]"

   done < $inputFile

   # enforce to craete .no-autostart file under admin/

   info_log "del cron & set $NO_AUTO_START_FLAG_FILE"

   info_log "$(date +'%F %T') stop by script" > $noAutoStartFlagFile

   info_log "$(ls -l $noAutoStartFlagFile)"

   info_log "$(cat $noAutoStartFlagFile)"

   return
}

function status_report(){

	local status=${1:-0}
	if [ "$1" -eq 0 ];then
		info_log "\n$pkgName $version $action comepleted succeed!"
	else
		info_log "\n$pkgName $version $action failed!"
	fi
	echo "{\"pkg\":\"$pkgName\",\"version\":\"$version\",\"action\":\"$action\",\"status\":\"$1\"}"
}

function error_exit(){
	
	local msg=${1:-$FUNCNAME [ERR ]}

   	local status=${2:-1}
	
	echo "{\"pkg\":\"$pkgName\",\"version\":\"$version\",\"action\":\"$action\",\"status\":\"$status\",\"msg\":\"$msg\"}"	

	exit

}

if [ "$1" = "-v" ];then
                echo "turn debug on"
                DEBUG="TRUE"
                shift
fi

check_privilege
logFile="/data/bizop/public-scripts/log/control_pkg.log.$(date +%F)"
pkgHomeDir="/data/services"
pkgName=$1
version=$2
action=$3
check_pkgname $pkgName
check_version $pkgName $version 
pkgPath="$pkgHomeDir/$pkgName-$version"
pkgScriptPath="$pkgHomeDir/$pkgName-$version/admin"
startScript="$pkgScriptPath/start.sh"
stopScript="$pkgScriptPath/stop.sh"
restartScript="$pkgScriptPath/restart.sh"

tmpLog=$(mktemp -t $pkgName-$version-$action.XXXXXX.log)
info_log "tmpLog is $tmpLog"

case "$action" in

"start")
	confirm "${!#}"
	if [[ "$DEBUG" = "TRUE" ]];then
		 /bin/bash $startScript | tee $tmpLog
	else
		/bin/bash $startScript > $tmpLog 2>&1
	fi
	if [ "$?" -eq 0 ];then
		add_cron $pkgName $version > $tmpLog 2>&1 && status_report $?;
	else
		error_exit "$action $pkgName failed ! detail please see $tmpLog" 1
	fi	
	;;

"stop")
	confirm "${!#}"
        if [[ "$DEBUG" = "TRUE" ]];then
		/bin/bash $stopScript |  tee $tmpLog
	else
        	/bin/bash $stopScript > $tmpLog 2>&1
	fi
	if [ "$?" -eq 0 ];then
		del_cron $pkgName $version  > $tmpLog 2>&1 && status_report $?;
	else
		error_exit "$action $pkgName failed ! detail please see $tmpLog" 1	
	fi
	;;

"restart")
	confirm "${!#}"
	if [[ "$DEBUG" = "TRUE" ]];then
		/bin/bash $restartScript |  tee $tmpLog
	else
        	/bin/bash $restartScript > $tmpLog 2>&1
	fi
	if [ "$?" -eq 0 ];then
                status_report $?;
        else
                error_exit "$action $pkgName failed ! detail please see $tmpLog" 1
        fi
	;;
"")
	prompt_tip
	;;

*)
	prompt_tip
	;;
esac
