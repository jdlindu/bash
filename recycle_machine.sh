#!/bin/bash
#Written by wuhaiting
#Readme: 清理线上服务器数据，尽可能地还原成刚重装的时候。

IPADDR=`ifconfig|grep "inet addr"|awk '{print $2}'|awk -F ":" '{print $2}'|grep -v "^127\.|^10\.|^192\.|^172\."|head -n1`

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

if [ "$1" != "Fpyrn5jMYzeyjqX0x6" ];then
	echo "passwd no correct."
	echo "aaRESULT=1"
	exit 1
fi

if [ "$2" == "tool_platform" ];then
	source commonFunction.sh
fi

LOG_DIR=/var/log/sysop_manager/

TMP_FILE=`mktemp /tmp/tmp.XXXX`
# check linux version
cat /etc/issue|grep -E "CentOS|Red" && LINUX_VERSION="centos"
cat /etc/issue|grep -E "Ubuntu" && LINUX_VERSION="ubuntu"
SYSTEM_VERSION=`getconf LONG_BIT`
if [ "$LINUX_VERSION" = "" ] || [ "$SYSTEM_VERSION" == "" ];then echo "aaRESULT=1";exit 1;fi

SERVER_IDS=`cat /home/dspeak/yyms/hostinfo.ini|grep "^server_id"|awk -F "=" '{print $2}'`

INSERT_MESSAGES=`locate insert_message.sh|grep "/usr/local/i386/.*/auto/insert_message.sh"`
INSERT_MYSQL () {
	#/bin/bash $INSERT_MESSAGES "$BASENAME" "$1"
	echo "$1"
}

# 首先清理跟管理监控相关的脚步，防止回滚
if [ "$LINUX_VERSION" == "centos" ];then
	/etc/init.d/crond stop >/dev/null 2>&1
	for a in `ls /var/spool/cron/|grep -v "root"`;do
		rm -f /var/spool/cron/$a > /dev/null 2>&1
	done
elif [ "$LINUX_VERSION" == "ubuntu" ];then
	/etc/init.d/cron stop >/dev/null 2>&1
	for a in `ls /var/spool/cron/crontabs |grep -v "root"`;do
		rm -f /var/spool/cron/crontabs/$a > /dev/null 2>&1
	done
fi
rm -rf /etc/crontab

if [ "$LINUX_VERSION" == "ubuntu" ];then
(
cat << 'EOF'
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# m h dom mon dow user  command
17 *    * * *   root    cd / && run-parts --report /etc/cron.hourly
25 6    * * *   root    test -x /usr/sbin/anacron || ( cd / && run-parts --report /etc/cron.daily )
47 6    * * 7   root    test -x /usr/sbin/anacron || ( cd / && run-parts --report /etc/cron.weekly )
52 6    1 * *   root    test -x /usr/sbin/anacron || ( cd / && run-parts --report /etc/cron.monthly )
10 5-23 * * * root /etc/cron.daily/logrotate

EOF
) > /etc/crontab
elif [ "$LINUX_VERSION" == "centos" ];then
(
cat << 'EOF'
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=root
HOME=/

# run-parts
01 * * * * root run-parts /etc/cron.hourly
02 4 * * * root run-parts /etc/cron.daily
22 4 * * 0 root run-parts /etc/cron.weekly
42 4 1 * * root run-parts /etc/cron.monthly
10 5-23 * * * root /etc/cron.daily/logrotate

EOF
) > /etc/crontab
fi
REPOS_DIR=`ls /usr/local/i386/|grep -v "public_repos"|grep -E "comm_repos|webdeb|db_repos|pure_db_reposdns_repos"`
pkill -9 -f $REPOS_DIR
echo "SERVER_INFO\t$IPADDR\t清理crontab完毕."

bash /etc/init.d/syslog-ng stop >/dev/null 2>&1 || pkill -9 -f syslog-ng

# clean the /etc/hosts
cat /etc/hosts|grep -v -E "^#|^$" | grep -E "balance.*com|sdaemon.*com|rdaemon.*com|yycookie.*com|bc.*com|config.*com|mirror.*com" > $TMP_FILE
[[ "$LINUX_VERSION" == "ubuntu" ]] && $(echo -e "127.0.0.1 ubuntu\n127.0.1.1 ubuntu\n" > /etc/hosts;cat $TMP_FILE >> /etc/hosts;echo "ubuntu" > /etc/hostname;)
[[ "$LINUX_VERSION" == "centos" ]] && $(echo -e "127.0.0.1 localhost localhost.localdomain localhost4 localhost4.localdomain4" > /etc/hosts;cat $TMP_FILE >> /etc/hosts;sed -i "s/HOSTNAME/HOSTNAME=localhost/g" /etc/sysconfig/network)
echo "SERVER_INFO\t$IPADDR\t重置/etc/hosts 完毕."

# clean the rc.local
RC_FILE=/etc/rc.local
cat /dev/null > $RC_FILE
echo "cd /home/dspeak/yyms/yyms_agent_2_d/build && ./yyms_agent_2_d &" >> $RC_FILE
echo "cd /home/dspeak/yyms/yymp/yyac_worker_ant/bin && ./yyac_worker_ant_d &" >> $RC_FILE
unset RC_FILE
echo "SERVER_INFO\t$IPADDR\t清理rc.local 完毕."

# clean /root directory
rm -rf /root/*
# 路由重新生成
rm -f $LOG_DIR/CncRouteDb.txt
echo "SERVER_INFO\t$IPADDR\t清除/root和路由信息 完毕."

# 清楚home目录下面
for a in `ls -l /home|grep -v -E "yuwanfu|wuhaiting|hujinli|zhangtao|backup|dspeak|total"|awk '{print $NF}'`;do
	/usr/sbin/userdel -r $a > /dev/null 2>&1
	rm -rf /home/$a > /dev/null 2>&1
	sed -i "/$a/d" /etc/group
done
unset a
rm -rf /home/backup/*
#清理/etc/passwd /etc/group
for a in `cat /etc/passwd|grep -E "/bin/bash|/bin/sh"|grep -v -E '^#|user_00|yuwanfu|wuhaiting|hujinli|zhangtao|backup|dspeak|total'| awk -F : '{if($3>=500) print $1}'`;do
	sed -i "/$a/d" /etc/passwd
	sed -i "/$a/d" /etc/group
done
chmod 644 /etc/passwd /etc/group
unset a
echo "SERVER_INFO\t$IPADDR\t删除所有无关用户 完毕."

# 整理/etc/
chmod 440 /etc/sudoers
chmod 640 /etc/shadow
cat /dev/null > /etc/hosts.allow
cat /dev/null > /etc/hosts.deny
cat /dev/null > /etc/sysctl.conf
echo -e "include /etc/ld.so.conf.d/*.conf \n/data/services/libs" > /etc/ld.so.conf
ldconfig
chmod 644 /etc/hosts.allow /etc/hosts.deny /etc/sysctl.conf /etc/ld.so.conf
if [ "$LINIUX_VERSION" == "ubuntu" ];then
	update-locale LANG=C
fi
echo "SERVER_INFO\t$IPADDR\t重置/etc/下面文件 完毕."

# clean iptables
iptables -F;iptables -t nat -F
rm -rf /usr/local/virus/iptables/*
echo "SERVER_INFO\t$IPADDR\t恢复默认iptables策略 完毕."

# clean /var/log
rm -f /var/log/*.gz /var/log/*.log
cat /dev/null > /var/log/messages
[[ -f /var/log/kern ]] && cat /dev/null > /var/log/kern
[[ -f /var/log/cron ]] && cat /dev/null > /var/log/cron
[[ -f /var/log/error ]] && cat /dev/null > /var/log/error
echo "SERVER_INFO\t$IPADDR\t清理/var/log/ 完毕."

rm -rf /usr/local/mysql*
aptitude -y remove apache2 mysqld mysql > /dev/null 2>&1

# clean /home/dspeak
[[ -d /home/dspeak/yyms/yymp/yymp_agent/bin/logs ]] && rm -rf /home/dspeak/yyms/yymp/yymp_agent/bin/logs/*
[[ -d /home/dspeak/yyms/yymp/yyac_worker_ant/bin/logs ]] && rm -rf /home/dspeak/yyms/yymp/yyac_worker_ant/bin/logs/*
[[ -d /home/dspeak/release ]] && rm -rf /home/dspeak/release
[[ -d /home/dspeak/iptables ]] && rm -rf /home/dspeak/iptables
echo "SERVER_INFO\t$IPADDR\t清理/home/dspeak 完毕."

# clean /var/log/sysop_manager dir
for a in `ls /var/log/sysop_manager/|grep -E "*.2012-|*.2011-|*.2013-"`;do
	rm -rf /var/log/sysop_manager/$a
done
rm -rf /var/log/sysop_manager/yymp*
cat /dev/null > /var/log/sysop_manager/sysop_manager.log

if [ "$LINUX_VERSION" == "ubuntu" ];then
	for SERVICE in `ls /etc/rc2.d|grep -v -E "acpid|dbus|ssh|bootlogs.sh|dns-clean|pppd-dns|atd|cron|ondemand|rc.local|rmnologin|syslog-ng|snmpd|README"`
	do
		rm -fr /etc/rc2.d/$SERVICE
	done
fi

# 清理/data /data1....所有内容，时间比较久
(
cat << 'EOF'
/bin/bash

for a in `cat /etc/mtab|grep "\/data.*"|awk '{print $2}'`;do
if [ "$a" == "/data" ];then
		for b in `ls /data|grep -v "tools-platform"`;do
			rm -rf /data/$b
		done
	else
		rm -rf $a/*
	fi
done

pkill -9 -f yymp
pkill -9 -f yyac
rm -rf /tmp/*

rm $0

EOF
) > /tmp/clean_system.sh
/bin/bash /tmp/clean_system.sh &
echo "SERVER_INFO\t$IPADDR\t清理所有分区数据....."

# 修改业务模块和负责人
#wget -O /tmp/tmp.sdfef -t 3 -T 2 "http://esb.sysop.duowan.com:35000/webservice/server/updateServerAdmin.do?server_id=$SERVER_IDS&sysop_admin=dw_hujinli&tech_admin=dw_hujinli&bus_id=000000100000100041103876"
#cat /tmp/tmp.sdfef|grep -q "true"
#if [ "$?" -eq 0 ];then
#	echo "SERVER_INFO\t$IPADDR\t修改为buffer机器，负责人胡锦礼 完毕"
#else
#	cat /dev/null > /tmp/tmp.sdfef
#	wget -O /tmp/tmp.sdfef -t 3 -T 2 "http://esb.sysop.duowan.com:35000/webservice/server/updateServerAdmin.do?server_id=$SERVER_IDS&sysop_admin=dw_hujinli&tech_admin=dw_hujinli&bus_id=000000100000100041103876"
#	cat /tmp/tmp.sdfef|grep -q "true"
#	if [ "$?" -eq 0 ];then
#		echo "SERVER_INFO\t$IPADDR\t修改为buffer机器，负责人胡锦礼 完毕"
#	else
#		echo "SERVER_INFO\t$IPADDR\t修改业务模块和负责人失败，请手工修改."
#	fi
#fi
rm -f /tmp/tmp.sdfef
/etc/init.d/syslog-ng start
/etc/init.d/cron* start

if [ "$2" == "tool_platform" ];then
	code=0; msg="$SCRIPT_NAME [INFO ] | successful."
	printResult "$code" "$msg"
	exit $code
else
	echo "aaRESULT=0"
	exit 0
fi
