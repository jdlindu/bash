#!/bin/bash
#Date:2012-02-01
#Written by manifold.
#Readme:change server's repository role.

export PATH=/usr/kerberos/sbin:/usr/kerberos/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin

# 角色获取
role=comm_repos

KEY_PRINT () {
(
cat <<'EOF'
yuwanfu--------ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAAgQDG+6HbrgWtZSZvyAxeQ9GKuNFpJpQvrPkEQRnvuRw9ElFj4lUpPbGElK/t0gVEIyc2pUBPJ5+gjE6XiQNswFim1XQL2Fcb0KGUXZ4njdl/Y9NMv4NpgSu9ptXWTEJFGokqxmDT6+p1X80S/h690GNyfAzT7Y7rVx7STDmapJAV0w==
wuhaiting--------ssh-dss AAAAB3NzaC1kc3MAAACBAJd1zuYJoe6SUYvzXHV3lj40BB70m+8GcGRNhhgWoFCrNnIKo1EycgRtCZF4k2CFKb48K9yJrzdHQgfeeHm9mqJzXD2dW8PwJqW4+u+W5fFBAc3TSlFjWgCJfWLtV0nKGbetN29f8Mo4v9a+zzgZ5UkHnyc16t0uONgReC2BYqkjAAAAFQCVPCEC4xuCUBjGqB74jONANoObFQAAAIAzI5xkDjPu4+VWW8+kj+QiJzdyNxLVyH/8u8MS7mDLoul+qzMWTTfUa3MIzvE2yaO1KQ3jyoyOUOFYXB1HNPoK2WPoWGRsDQt1nPQv8Vzw1SWkcHzGzBxm2G8ubV1MbpkkpOHNYcRYPn8gys7PeTCh2IoBAmYUDHKw/H5gCJ1ZegAAAIAr9jMBDx+TZI+piilHeygk4rwOFwU67wqR+rMfsDktOOVjNmexx71ySEfJNakp1Kmz2nhi4PPzKnC881mIy5mEaaLtjH2lpfqaH3LOz0mT2bOPZjxnn1FIeqBHlTZFBuNu/ag7wg1yP9sXTdsZfVfjyG8mF3R9bc6HIHGx4qHGoQ==
EOF
)
}

cat /etc/group|grep -wq "segroup" || groupadd segroup
cat /etc/group|grep -wq "execute" || groupadd execute
for USER in wuhaiting yuwanfu;do
	id $USER > /dev/null 2>&1
    if [ $? -ne 0 ];then
		/usr/sbin/useradd -s /bin/bash -d /home/$USER -m $USER -G segroup
		mkdir -p /home/$USER/.ssh
		KEY_PRINT | grep $USER | awk -F '--------' '{print $2}' > /home/$USER/.ssh/authorized_keys
		chmod 700 /home/$USER/.ssh
		chmod 600 /home/$USER/.ssh/authorized_keys
		chown -R $USER:$USER /home/$USER/
	wait
	fi
	usermod -G segroup $USER
done

if [ "$role" = "comm_repos" ];then
	RUN_USER=yuwanfu
	username=clientupdatea276c728eccbae78089bcc08e0658cae
	password=e40a3775ad30455352775a4a144704c7
else
	echo "the role which user input error,please check."
	echo "four role you can select are:comm_repos webdep db_repos pure_db_repos"
	exit 1
fi

# 判断操作系统
cat /etc/issue|grep -E "CentOS|Red" && LINUX_VERSION="centos"
cat /etc/issue|grep -E "Ubuntu" && LINUX_VERSION="ubuntu"
if [ "$LINUX_VERSION" = "" ];then exit 1;fi

# subversion是否安装成功的判断
if [ "$LINUX_VERSION" = "ubuntu" ];then
	dpkg -l|grep subversion
	if [ "$?" -ne 0 ];then
		echo "not install subvesion,exit now."
		exit 1
	fi
else
	rpm -qa|grep subversion
	if [ "$?" -ne 0 ];then
		echo "not install subvesion,exit now."
		exit 1
	fi
fi

# 准备相关目录
if [ ! -d /usr/local/i386 ];then
	mkdir /usr/local/i386
fi
chown -R $RUN_USER:$RUN_USER /usr/local/i386

# 指定subversion为明文密码保存
mkdir -p /home/$RUN_USER/.subversion
echo -e "[groups]\n[global]\nhttp-timeout = 15\nstore-plaintext-passwords = yes\nssl-authority-files = /etc/ssl/yy-cacert.pem" > /home/$RUN_USER/.subversion/servers
chown -R $RUN_USER:$RUN_USER /home/$RUN_USER/.subversion

# prepare ssl key.
if [ ! -d /etc/ssl ];then
	mkdir -p /etc/ssl
fi

if [ ! -f /etc/ssl/yy-cacert.pem ];then
(
cat <<'EOF'
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            f2:6e:9d:79:63:e9:c9:8c
        Signature Algorithm: sha1WithRSAEncryption
        Issuer: C=CN, ST=GD, L=GZ, O=DUOWAN, OU=YY, CN=ca.yy.duowan.com
        Validity
            Not Before: Dec 17 09:30:59 2011 GMT
            Not After : Dec  9 09:30:59 2041 GMT
        Subject: C=CN, ST=GD, L=GZ, O=DUOWAN, OU=YY, CN=ca.yy.duowan.com
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:dd:b5:b3:ac:2e:48:20:b7:df:74:c5:3b:8c:c4:
                    31:33:cc:24:a0:a2:78:0d:69:65:2a:10:21:a7:9e:
                    eb:3d:64:6a:ee:ce:93:7d:7b:4f:7a:d7:e0:da:a3:
                    0d:da:57:54:95:99:f9:a2:ef:84:93:01:d9:3f:08:
                    66:0a:64:af:73:4b:2b:a4:b5:b9:b8:28:8d:08:0f:
                    45:fd:28:dd:d7:61:75:3f:0c:fe:87:a9:07:7a:0d:
                    ce:a9:22:b6:8c:13:45:10:e4:82:f6:63:65:b7:d9:
                    89:9c:e8:87:70:bd:6d:4c:df:0b:51:89:55:6a:3b:
                    76:b0:4e:9d:03:e1:c9:a9:e0:39:60:09:32:71:3c:
                    f7:24:9b:63:4f:6f:79:e4:f5:ac:6f:b9:6e:6c:6e:
                    41:57:d6:6f:42:2c:4b:23:21:a6:35:3f:ae:fe:52:
                    07:51:8f:4a:62:4a:78:b0:48:29:f5:f0:6b:b7:47:
                    59:13:f4:45:ca:2f:af:1c:f1:bb:48:b8:8a:c9:dd:
                    f7:aa:37:42:d2:9f:9a:b1:3c:63:12:89:f2:ae:aa:
                    f5:47:14:19:07:b3:7b:40:51:c1:3b:8a:6c:0c:77:
                    02:b5:72:b4:29:84:b9:87:00:9c:4c:1c:91:46:9f:
                    7f:7d:24:c6:88:a0:41:4b:4a:f3:40:53:54:82:d0:
                    78:ef
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Subject Key Identifier: 
                CE:04:9A:F3:50:E1:D9:2E:32:9E:9B:78:09:A9:52:DF:B5:B8:32:A7
            X509v3 Authority Key Identifier: 
                keyid:CE:04:9A:F3:50:E1:D9:2E:32:9E:9B:78:09:A9:52:DF:B5:B8:32:A7

            X509v3 Basic Constraints: 
                CA:TRUE
    Signature Algorithm: sha1WithRSAEncryption
        cf:87:b0:24:95:74:fd:ff:90:5a:bb:2a:47:19:fc:48:b1:e7:
        97:e4:65:3d:bf:08:7d:4f:43:f2:03:7f:6d:93:5c:b7:c8:11:
        43:d3:48:df:cb:d4:74:48:96:03:16:80:d5:85:aa:e7:6f:8e:
        e3:f4:b9:d1:c5:89:30:ea:46:2b:ca:fd:5f:c2:b4:47:80:0a:
        a5:4d:0d:b8:72:d7:d5:e6:3f:a2:9a:02:71:e7:71:33:f5:0a:
        f9:44:72:33:39:fd:af:55:2e:12:5e:99:a0:d7:cf:27:64:a8:
        f9:1d:62:7e:98:c5:fd:97:6a:b3:aa:7a:4d:d8:22:f2:56:b6:
        51:45:68:9b:b1:2d:a2:98:b7:28:bc:78:d0:78:c9:66:27:c7:
        8e:ba:21:b7:3f:35:b2:43:95:57:d0:74:d0:d2:d0:80:11:75:
        98:a0:2b:9b:34:fb:d1:e3:f8:91:e1:a0:b1:e4:76:2a:9e:14:
        46:af:16:79:d7:d8:de:13:fe:c0:4a:be:0e:e3:e7:aa:19:3b:
        05:ec:3b:dc:f6:ff:e8:3a:77:59:7d:7c:d7:ef:82:e0:81:53:
        ac:82:60:ce:68:3a:d2:e5:a0:96:d1:94:91:f8:3b:f6:74:9b:
        05:b1:40:60:cd:bd:4f:cb:e5:7f:bf:cd:22:a0:4b:14:1a:c0:
        cf:72:65:34
-----BEGIN CERTIFICATE-----
MIIDkzCCAnugAwIBAgIJAPJunXlj6cmMMA0GCSqGSIb3DQEBBQUAMGAxCzAJBgNV
BAYTAkNOMQswCQYDVQQIDAJHRDELMAkGA1UEBwwCR1oxDzANBgNVBAoMBkRVT1dB
TjELMAkGA1UECwwCWVkxGTAXBgNVBAMMEGNhLnl5LmR1b3dhbi5jb20wHhcNMTEx
MjE3MDkzMDU5WhcNNDExMjA5MDkzMDU5WjBgMQswCQYDVQQGEwJDTjELMAkGA1UE
CAwCR0QxCzAJBgNVBAcMAkdaMQ8wDQYDVQQKDAZEVU9XQU4xCzAJBgNVBAsMAllZ
MRkwFwYDVQQDDBBjYS55eS5kdW93YW4uY29tMIIBIjANBgkqhkiG9w0BAQEFAAOC
AQ8AMIIBCgKCAQEA3bWzrC5IILffdMU7jMQxM8wkoKJ4DWllKhAhp57rPWRq7s6T
fXtPetfg2qMN2ldUlZn5ou+EkwHZPwhmCmSvc0srpLW5uCiNCA9F/Sjd12F1Pwz+
h6kHeg3OqSK2jBNFEOSC9mNlt9mJnOiHcL1tTN8LUYlVajt2sE6dA+HJqeA5YAky
cTz3JJtjT2955PWsb7lubG5BV9ZvQixLIyGmNT+u/lIHUY9KYkp4sEgp9fBrt0dZ
E/RFyi+vHPG7SLiKyd33qjdC0p+asTxjEonyrqr1RxQZB7N7QFHBO4psDHcCtXK0
KYS5hwCcTByRRp9/fSTGiKBBS0rzQFNUgtB47wIDAQABo1AwTjAdBgNVHQ4EFgQU
zgSa81Dh2S4ynpt4CalS37W4MqcwHwYDVR0jBBgwFoAUzgSa81Dh2S4ynpt4CalS
37W4MqcwDAYDVR0TBAUwAwEB/zANBgkqhkiG9w0BAQUFAAOCAQEAz4ewJJV0/f+Q
WrsqRxn8SLHnl+RlPb8IfU9D8gN/bZNct8gRQ9NI38vUdEiWAxaA1YWq52+O4/S5
0cWJMOpGK8r9X8K0R4AKpU0NuHLX1eY/opoCcedxM/UK+URyMzn9r1UuEl6ZoNfP
J2So+R1ifpjF/Zdqs6p6Tdgi8la2UUVom7Etopi3KLx40HjJZifHjrohtz81skOV
V9B00NLQgBF1mKArmzT70eP4keGgseR2Kp4URq8WedfY3hP+wEq+DuPnqhk7Bew7
3Pb/6Dp3WX181++C4IFTrIJgzmg60uWgltGUkfg79nSbBbFAYM29T8vlf7/NIqBL
FBrAz3JlNA==
-----END CERTIFICATE-----
EOF
) > /etc/ssl/yy-cacert.pem
fi

MYSQL_ADDRESS=121.14.36.27
MANAGER_REPOS_LINE=`cat /etc/hosts|grep manager.repos.yy.duowan.com|wc -l`
if [ "$MANAGER_REPOS_LINE" -eq 0 ];then
	echo "$MYSQL_ADDRESS manager.repos.yy.duowan.com" >> /etc/hosts
fi
su - $RUN_USER -c "cd /usr/local/i386 ; svn co https://manager.repos.yy.duowan.com:63579/svn/$role --username=$username --password=$password"

for DIR in `ls /usr/local/i386/|grep -v -w $role`
do
	rm -fr /usr/local/i386/$DIR
done

# 强制更新角色信息
LOG_DIR=/var/log/sysop_manager
> $LOG_DIR/check_motd.log

if [ "$role" == "comm_repos" ];then
	useradd -s /bin/bash -d /home/dspeak -m dspeak
	mkdir -p /home/dspeak/.ssh
	echo "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAIEA7NtU7UFJ0EtWvPo/3tV/8Iia3HBhn9/O2wbfeCKZTmZtv4gc/Q6VtnmGmUvqbLqYRbT00QFLsc1QXRx3lJvKZfLaCpniIHhdeBUTVPgRq0TZF7AxGiRS1AZQv/EAvG1tRqs7q5QhyUIO9ZBbmm+ax93K/W0qDnpGb2oKopQHmus=" > /home/dspeak/.ssh/authorized_keys
	chmod 700 /home/dspeak/.ssh
	chmod 600 /home/dspeak/.ssh/authorized_keys
	chown -R dspeak:dspeak /home/dspeak

	# 创建应用系统所需目录
	INSERT_MYSQL "创建应用系统所需目录: /home/dspeak/release/bin,/data/yy/log"
	mkdir -p /home/dspeak/release/bin
    mkdir -p /home/dspeak/yyms/proc_info
	mkdir -p /data/yy/log
	chsh dspeak -s /sbin/nologin
	
	pkill iptables
	mkdir -p /home/dspeak/iptables
	chown dspeak:dspeak -R /home/dspeak/iptables
	/bin/cp /usr/local/i386/$role/initial_system/iptables/iptables.sh /home/dspeak/iptables/iptables.sh
	iptables -t raw -F
	iptables -t raw -L

	# ipdb网通地址段
	/bin/cp /usr/local/i386/$role/initial_system/route/CncIpDb.txt /home/dspeak/release/bin/CncIpDb.txt
	/bin/cp /usr/local/i386/$role/initial_system/route/CmccIpDb.txt /home/dspeak/release/bin/CmccIpDb.txt
	/bin/cp /usr/local/i386/$role/initial_system/route/EduIpDb.txt /home/dspeak/release/bin/EduIpDb.txt
	
	echo 1qazxcv > /etc/rsync.scr
	chmod 600 /etc/rsync.scr
elif [ "$role" == "webdeb" ];then
	userdel dspeak
fi

/bin/bash /usr/local/i386/$role/auto/base_config.sh nosign

