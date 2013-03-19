#!/bin/bash

# FILENAME     : rsync_manager.bash 
# DESCRIPTION  : send remote file to remote machine
# AUTHOR       : Juliam
# CREATED DATE : 2012-04-19
# LAST MODIFIED: 2012-04-19

if [ $# -ne 4 ]
then 
	echo "Usage  : bash $0 SOURCE_IP SOURCE_DIR TARGET_IP TARGET_DIR"
	echo "Example: bash $0 121.9.221.148 /data/www/www.duowan.com 183.61.6.123 /data/webapps/www.duowan.com"
	exit 1
fi

GEN_FILE="gen_rsync.bash"
SYNC_FILE="rsync_code_file.bash"
SOURCE_IP=$1
SOURCE_DIR=$2
TARGET_IP=$3
TARGET_DIR=$4
CODE=$(openssl rand 30 -base64)
#MODULE=$(echo "$SOURCE_DIR"|awk -F'/' '{print $NF}'|tr '.' '_')
#MODULE=$(echo "$SOURCE_DIR"|sed 's#/$##g'|awk -F'/' '{print $NF}'|tr '.' '_')
MODULE=$(echo "$SOURCE_DIR"|sed 's#/$##g'|sed 's#^/##g'|tr '/' '_'|tr '.' '_')
USER="migration_$(echo "$MODULE"|cut -d'_' -f1)"

scp -P 32200 $GEN_FILE $SOURCE_IP:~
ssh -p 32200 $SOURCE_IP "sudo bash $GEN_FILE $SOURCE_DIR  $MODULE  $USER $CODE $TARGET_IP"

scp -P 32200 $SYNC_FILE $TARGET_IP:~
ssh -p 32200 $TARGET_IP "sudo bash $SYNC_FILE $TARGET_DIR $MODULE  $USER $CODE $SOURCE_IP;echo $?"  2>&1|tee $SOURCE_IP.log
STATUS=$(tail -n 1 $SOURCE_IP.log)
[ $STATUS -eq 0 ] && echo -e "DONE! \n $SOURCE_DIR :\t$USER@$SOURCE_IP::$MODULE/* \t$CODE" || echo " Failed. -_-||| "
echo -e "$(date +"%F %T")\t $SOURCE_DIR :\t$USER@$SOURCE_IP::$MODULE/* \t$CODE" |tee -a rsync_record.log
