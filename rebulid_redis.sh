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
        	msg_file=$(sudo find /data/ -name "msg.0*" -mmin -30 -size +0c )
        	[[ -z "$msg_file" ]] && break
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
dbd_dir='/data/services/db_rdsesscache_d-343472'

confirm_next "Step 0 : Have you update $1's kernel yet ? (yes/no)"
confirm_next "Step 1 : Please stop $scrip $1  db_rdsesscache_d in pakage system (yes/no)"


echo "turning $scrip and $1 's sqc to store mode"
ssh -np32200 $dstip "sudo sed -i 's/<mode>1<\/mode>/<mode>2<\/mode>/' $sqc_dir'/bin/sqc_redis.xml' && sudo bash $sqc_dir/admin/restart.sh" || exit
echo "$dstip 's sqc restart succeed!"
sleep 10
turn2store $sqc_dir"/bin/sqc_redis.xml" 
sudo bash $sqc_dir'/admin/restart.sh'


echo 'Step2 : dump redis data ?(yes/no)'
sudo rm /data1/dump.rdb.*
/data1/redis-cli -p 6380 save
/data1/redis-cli -p 6379 save


echo "Step3 : restore local sqc service (yes/no)"
turn2mt $sqc_dir"/bin/sqc_redis.xml"
sudo bash $sqc_dir'/admin/restart.sh'
is_synced
echo 'start $scrip db_rdsesscache_d'
sudo bash $dbd_dir'/admin/start.sh'

echo "Step4 : restore remote sqc service (yes/no) "
ssh -np32200 $dstip "sudo rm /data1/dump.rdb.*" || exit
scp -P32200 -C /data1/dump.rdb.* $dstip:/data1 || exit
echo 'start remote redis-server'
ssh -np32200 $dstip "sudo /data1/redis-server-lz /data1/redis.conf.ban && sudo /data1/redis-server-lz /data1/redis.conf.core" || exit
sleep 10
echo 'change remote sqc mode to mt'
ssh -np32200 $dstip "sudo sed -i 's/<mode>2<\/mode>/<mode>1<\/mode>/' $sqc_dir'/bin/sqc_redis.xml' && sudo bash $sqc_dir/admin/restart.sh"  || exit
echo 'waiting data be synced to redis'
while :
do
	msg_file=$(ssh -np32200 $dstip 'sudo find /data/ -name "msg.0*" -mmin -30 -size +0c ')
	[[ -z "$msg_file" ]] && break
done
echo 'finally starting dbd process'
ssh -np32200 $dstip "sudo bash $dbd_dir'/admin/start.sh'"
echo 'done'
exit 0
