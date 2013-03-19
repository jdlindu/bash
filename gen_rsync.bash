#!/bin/bash

# FILENAME     : gen_rsync.bash
# DESCRIPTION  : generate rsync configuration
# AUTHOR       : Juliam
# CREATED DATE : 2012-04-19
# LAST MODIFIED: 2012-04-19

if [ "$(whoami)" != "root" ]
then
	echo "MUST be run by root!"
	exit 1
fi

USER_FILE=/etc/rsyncd_migrate_users
DIR=$1
MODULE=$2
USER=$3
CODE=$4
ALLOW_IP=$5

if [ -s /etc/rsyncd.conf ]
then
	cat >> /etc/rsyncd.conf <<EOF
[$MODULE]
        path = $DIR
        comment = for migrate files
        read only = no
        ignore errors
        strict modes = yes
        auth users = $USER
        secrets file = $USER_FILE
	hosts allow = $ALLOW_IP
	hosts deny = *
EOF

else
	cat > /etc/rsyncd.conf <<EOF
uid = www-data
gid = www-data
use chroot = yes

pid file = /var/run/rsyncd.pid  
lock file = /var/run/rsync.lock  
log file = /var/log/rsyncd.log 


# added by Juliam

[$MODULE]
        path = $DIR
        comment = for migrate files
        read only = no
        ignore errors
        strict modes = yes
        auth users = $USER
        secrets file = $USER_FILE
	hosts allow = $ALLOW_IP
	hosts deny = *
EOF

fi

#chown -R www-data:www-data $DIR
cat >> $USER_FILE <<EOF
$USER:$CODE
EOF

chmod 600  $USER_FILE

sed -i 's/^RSYNC_ENABLE=false/RSYNC_ENABLE=true/g' /etc/default/rsync 

cd /etc/rc2.d/
ln -s ../init.d/rsync S59rsync
ps -C rsync >/dev/null || rsync  --daemon

echo "DONE!"
