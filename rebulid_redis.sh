#!/bin/bash

function checkIsValidIp {

	local x

	x=$(echo "$1" | awk -F '.' 'NF==4 && (0<$1 && $1<255) &&  (0<=$2 && $2<255) &&  (0<=$3 && $3<255) &&  (0<$4 && $4<255)')

	if [ "$x" = "$1" ] && [ -n "$x" ] ; then

		return 0

	else

		return 1

	fi
}

function getSingleIp {

	local x=$(/sbin/ifconfig |grep ^eth -A 2 |egrep 'inet +addr:' | awk -F '[ :]+' '{print $4}' |head -1)

	echo "$x"

	return

}

function turn2store {
	[[ ! -f "$1" ]] && { echo "$1 is not a valid file "; return false; }
	sudo sed -i 's/<mode>1<\/mode>/<mode>2<\/mode>/' $1
	if [[ "$?" -ne 0 ]]; then
		#statements
		return 0
	else
		echo 'turn to store mode succeed'
		return 1
	fi
}

function turn2mt {
	[[ ! -f "$1" ]] && { echo "$1 is not a valid file "; return false; }
	sudo sed -i 's/<mode>2<\/mode>/<mode>1<\/mode>/' $1
	if [[ "$?" -ne 0 ]]; then
		#statements
		return 0
	else
		echo 'turn to mt mode succeed'
		return 1
	fi
}

function confirm_next {
	while :
	do
	read -p "$*" answer
	if [ "$answer" == 'yes' ]
		then
		echo "Great,let's go to next"
		break
	fi
done
}

function is_synced {
	while :
	do
        	msg_file=$(find /data/ -name "msg.*" -mmin -1)
        	[[ -n "$msg_file" ]] && break
	done	
}

if [ "$#" -ne 1 ]
	then
	echo "Usage: $(basename $0) dstip"
	exit
else
	checkIsValidIp "$1"
	if [ "$?" -ne 0 ]
		then
		echo '$1 is not a valid ip'
		exit
	fi
fi

scrip=$(getSingleIp) #source ip
dstip="$1"
sqc_dir='/data/services/db_sqc_rdsesscache_d-306786'
dbd_dir='/data/services/db_rdsesscache_d-306786'


confirm_next "Step 1 : Please stop $scrip and $1  db_rdsesscache_d in pakage system (yes/no)"


echo "turning $scrip and $1 's sqc to store mode"
ssh -np32200 $dstip "sudo sed -i 's/<mode>1<\/mode>/<mode>2<\/mode>/' $sqc_dir'/conf/sqc_redis.xml' && sudo bash $sqc_dir/admin/restart.sh" 
sleep 10
turn2store $sqc_dir"/conf/sqc_redis.xml" && sudo bash $sqc_dir'/admin/restart.sh'


confirm_next 'Step2 : dump redis data ?(yes/no)'
sudo rm /data1/dump.rdb.*
/data1/redis-cli -p 6380 save
/data1/redis-cli -p 6379 save


confirm_next "Step3 : restore local sqc service"
turn2mt $sqc_dir"/conf/sqc_redis.xml" && sudo bash $sqc_dir'/admin/restart.sh'
while :
do
	msg_file=$(find . -name "msg.*" -mmin -1)
	[[ -n "$msg_file" ]] && break
done
echo 'start $scrip db_rdsesscache_d'
sudo bash $dbd_dir'/admin/start.sh'

confirm_next "Step4 : restore remote sqc service"
ssh -np32200 $dstip "sudo rm /data1/dump.rdb.*"
scp -P32200 -C /data1/dump.rdb.* $dstip:/data1
echo 'start remote redis-server'
ssh -np3200 $dstip "sudo /data1/redis-server-lz redis.conf.ban && /data1/redis-server-lz redis.conf.core"
sleep 10
echo 'change remote sqc mode to mt'
ssh -np32200 $dstip "sudo sed -i 's/<mode>2<\/mode>/<mode>1<\/mode>/' $sqc_dir'/conf/sqc_redis.xml' && sudo bash $sqc_dir/admin/restart.sh" 
echo 'waiting data be synced to redis'
while :
do
	msg_file=$(ssh -np32200 $dstip 'find /data/ -name "msg.*" -mmin -1')
	[[ -n "$msg_file" ]] && break
done
echo 'finally starting dbd process'
ssh -np32200 $dstip "sudo bash $dbd_dir'/admin/start.sh'"
echo 'done'
exit 0
