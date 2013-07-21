#!/bin/bash

FUNCNAME=$(basename $0)

function info_log {

   local content

   while read content; do

	printf "%s\n" "$content"
   	printf "%s | %s | [ info ] | %s\n" "$(date +'%F %T')" "$SUDO_USER" "$content" 1>&2 >> $logFile

   done < <(echo -e "$*")

   return
}

function check_privilege(){
	if [ "$UID" -ne 0 ] ; then
		echo "only root can run this script!"
		exit 1
	fi
}
function confirm(){
	[ -z $PS1 ] && echo "non-interactive shell , maybe you should append -y option!" && exit
	while :
        do
        	read -p "$*" answer
        	if [ "$answer" == 'yes' ] || [ "$answer" == 'YES' ]
                then
                	info_log "action confirm!"
                	return 0
		elif [ "$answer" == 'no' ] || [ "$answer" == 'NO' ]
		then
			info_log "actin cancel!"
			return 1
        	fi
	done
}

function pkg_tip(){
	local pkgs=$(ls -F /data/services | egrep ".*$pkgName.*-.*/$" | awk -F- '{print $1}')
	if [ -n "$pkgs" ] ; then
		info_log "maybe you are looking for these pkg \n$pkgs"
	fi
}

function check_pkgname(){

	if [ -z "$1" ];then
		info_log "Usage: $(basename $0) pkg version start|stop|restart [ -y ]"
		exit 1
	else
		pkgDir=$(ls -F /data/services | egrep "^$pkgName-.*/$")
		if [ -z "$pkgDir" ] ; then
			info_log "pkgName=$pkgName not exist!"
			pkg_tip
			exit 1
		fi
	fi
}

function check_version(){
	local pkgPath="$pkgHomeDir/$1-$2"
	local versions=$(ls -F /data/services | egrep "^$pkgName-.*/$" | awk -F'-|/' '{print $2}')
	if [[ -z "$2" ]] ; then
		info_log "version cannot be null,posibble version is :\n$versions"
		exit 1
	else
		if [ ! -d "$pkgPath" ] ; then
                	info_log "wrong version !! possible version is : \n$versions"
                	exit 1
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

case "$action" in

"start")
	[[ "${!#}" == "-y" ]] || confirm "are you sure you are goingto start $pkgName-$version(yes/no)"
	if [[ $? -eq 0 ]];then
		/bin/bash $startScript && add_cron $pkgName $version;
	else
		exit 1
	fi
	;;

"stop")
	[[ "${!#}" == "-y" ]] || confirm "are you sure you are goingto stop $pkgName-$version(yes/no)"
	if [[ $? -eq 0 ]];then
                /bin/bash $stopScript && del_cron $pkgName $version;
	else
		exit 1
        fi
	;;

"restart")
	[[ "${!#}" == "-y" ]] || confirm "are you sure you are goingto restart $pkgName-$version(yes/no)"
	if [[ $? -eq 0 ]];then
                /bin/bash $restartScript;
	else
		exit 1
        fi
	;;
"")
	info_log "Usage: $(basename $0) pkg version start|stop|restart [ -y ]"
	exit 1
	;;

*)
	info_log "Usage: $(basename $0) pkg version start|stop|restart [ -y ]"
	exit 1
	;;
esac

[[ "$?" -eq 0 ]] && info_log "\n$pkg $version $action comepleted success!"
