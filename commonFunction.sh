#!/bin/bash
#Date:2012-09-26
#Written by manifold.
#Readme:common function script.

# 已使用返回码：
# 51 parseParameterOld
# 52 parseParameter
# 53 parseParameter
# 54 checkPackageExistOrNot
# 55 operateCrontab
# 56 operateCrontab
# 57 operateCrontab
# 58 operateCrontab
# 59 operateCrontab
# 60 operateCrontab
# 61 operateCrontab


export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export LANG=C


# 屏蔽!
set +H


#------------------------#
# 系统基本信息           #
#------------------------#

# 获取操作系统信息
# Ubuntu 10.04 LTS
function getOsDescription {

    local x=$(lsb_release -d | sed -r 's/^Description:[[:space:]]+//')

    echo "$x"

    return

}


# 获取操作系统位长信息
function getOsLongBit {

   local x=$(getconf LONG_BIT)

   echo $x

   return

}


# 获取操作系统位长信息
function getKernelInfo {

   local x=$(uname -r)

   echo $x

   return

}


# 获取单个IP地址
# xxx.xxx.xxx.xxx
function getSingleIp {

    local x=$(ifconfig |grep ^eth -A 2 |egrep 'inet +addr:' | awk -F '[ :]+' '{print $4}' |head -1)

    echo "$x"

    return

}


# 获取所有IP地址串
# xxx.xxx.xxx.xxx,xxx.xxx.xxx.xxx
function getAllIpString {

    local x=$(ifconfig |grep 'inet addr' |grep -v 127.0.0.1 |awk -F '[ :]+' '{print $4}' | xargs | sed 's/ /,/g')

    echo "$x"

    return

}


# 获取所有IP地址
# xxx.xxx.xxx.xxx
# xxx.xxx.xxx.xxx
function getAllIpInfo {

    local x=$(ifconfig |grep 'inet addr' |grep -v '127.0.0.1' | awk -F '[ :]+' '{print $4}')

    echo "$x"

    return

}


# 单IP地址获取
IP_ADDR=$(getSingleIp)


# 基础脚本变量定义
MYPID=$$


# 脚本名称定义
SCRIPT_NAME=$(basename $0)


# 脚本路径定义
SCRIPT_DIR=$(dirname $0)


# 时间定义
DATE_STRING=$(date +%F)

TIME_STRING=$(date +%T)


# /var/log/sysop_manager 日志目录变量定义
SYSOP_MANAGER_DIR=/var/log/sysop_manager


# /var/log/sysop_manager/sysop_manager.log 日志文件变量定义
SYSOP_MANAGER_LOG=$SYSOP_MANAGER_DIR/sysop_manager.log 



#------------------------#
# 日志/返回 相关信息输出 #
#------------------------#

# 日志打印公共函数
function printLog {

    local x

    while read x ; do

        echo "$(date +'%F %T')| $x" | awk '{$3=sprintf("%22s | ",$3);print $0}'

    done < <(echo "$*")

    return

}


# 执行结果输出格式定义（上报给工具系统。若$1,$2未提交，会直接退出！建议以子shell方式运行）
function printResult {
    
    local code=${1:?$FUNCNAME Err! code must be gived}
    
    local msg=${2:?$FUNCNAME Err! msg must be gived}
    
    echo "code=$code&&msg=$msg"

}



#------------------------#
# 脚本参数相关信息       #
#------------------------#

# 脚本参数解析（全局）
function parseParameter {

    # 将\n替换成\\n，避免echo "$PARA_STRING"时直接就将\干掉了，变成n
    
    sed -i 's#\\n#\\\\n#g' para.config
    
    while read PARA_STRING ; do

        # 判断参数是否符合key=value格式
        
        if ! echo "$PARA_STRING" | egrep -q '^[^ =]+=[^ =]+.*$' ; then

            code=52 ; msg="$FUNCNAME [ERR ] | invalid format \"$PARA_STRING\", it should be in key=value format"

            printResult "$code" "$msg"

            return $code
             
        else
        
            # 遍历定义每一个参数
            
            # 参数名获取           
            PARA_NAME=$( echo "$PARA_STRING" | sed -r 's#(.*)=(.*)#\1#g' )
            
            # 参数值获取           
            PARA_VALUE=$( echo "$PARA_STRING" | sed -r 's#(.*)=(.*)#\2#g' )
            
            # 参数名，参数值对应赋值
            eval "$PARA_NAME=\"$PARA_VALUE\"" 2>/dev/null || { code=53 ; msg="$FUNCNAME [ERR ] | eval error"

            printResult "$code" "$msg"

            return $code; }
             
        fi

    done < para.config

}


# 旧的参数获取函数（于2012-10-18停用）

function parseParameterOld {

    # for PARA_STRING in $(cat para.config);do
    # for ((i=0;i<${#BASH_ARGV[*]};i++)); do
    # 2012-10-17 改成while的模式去跑，para.config的格式为一行一个key=value
    cat para.config | while read PARA_STRING ; do

        # 判断参数是否包含空格
        if echo "$PARA_STRING" | egrep -q '[[:space:]]' ; then

            code=51 ; msg="$FUNCNAME [ERR ] | \"$PARA_STRING\" contain space character"

            printResult "$code" "$msg"

            return $code

        # 判断参数是否符合key=value格式
        elif ! echo "$PARA_STRING" | egrep -q '^[^ =]+=[^ =]+$' ; then

            code=52 ; msg="$FUNCNAME [ERR ] | invalid format \"$PARA_STRING\", it should be in key=value format"

            printResult "$code" "$msg"

            return $code
             
        else
        
            # 遍历定义每一个参数
            eval "$PARA_STRING" 2>/dev/null || { code=53 ; msg="$FUNCNAME [ERR ] | $PARA_STRING eval error"

            printResult "$code" "$msg"

            return $code; }
             
        fi

    done

}



#------------------------#
# 功能定义               #
#------------------------#

# pid获取（系统默认的pidof在crontab里面运行会core掉）
function pidof {
    
    local name="$*"

    # strip all options
    name=$(echo "$name" | sed -r 's/(-x|-s|-o|-c) //g')

    # only one pname  is allowed
    if [ "${name// }" != "$name" ] ; then
        return 1
    fi

    if [ -z "$name" ] ; then
       return 1
    fi

    local pids

    pids=$(ps -e --no-headers -opid,cmd | awk '$2 !~ /^\[/' | awk '{print $1,$2}' | sed -r 's/ (.*)\/(.*)/ \2/g' | awk -v x=$name '$2 == x {print $1}')

    if [ -z "$pids" ] ; then
        return 1
    else
        echo "$pids"
        return 0
    fi
    
}


# 获取当前系统运行的所有进程列表
function listAllPorcess {

    ps -e --no-headers -ocmd | awk '$2 !~ /^\[/' | awk '{print $1}' | sed -r 's/^(.*)\/(.*)/\2/g'
    
}


# 备份相应文件的内容到 LOG_DIE
function bakcupFileContent {

    local backup_file_name="$1"
    
    if [ -e $backup_file_name ] && [ -f $backup_file_name ];then
    
        printLog info "backup $backup_file_name content" >> $SYSOP_MANAGER_LOG
        cat $backup_file_name >> $SYSOP_MANAGER_LOG && return 0
        
    else
    
        printLog "$backup_file_name not exist or not a regular file" >> $SYSOP_MANAGER_LOG
        return 1
        
    fi
    
    return 1
    
}


# 安装包检查
function checkPackageExistOrNot {
    
    local pkg_name="$*"

    if echo "$pkg_name" | egrep -q '[[:space:]]' ; then
    
        code=54 ; msg="$FUNCNAME [ERR ] | \"$pkg_name\" contain space character,only one parameter is permited."

        printResult "$code" "$msg"

        return $code
        
    fi
    
    # 检查是否有安装对应的软件包
    checkOs ubuntu && query_command="dpkg -l|grep -q "
    checkOs centos && query_command="rpm -qa|grep -q "
    
    eval "$query_command $pkg_name" && return 0 || return 1
    
}


# 接口调用
function wgetAction {

    # 参数拼装
    
    local api_server="$1"
    
    local api_name="$2"
    
    local output_file="$3"
    
    local post_string="$4"
    
    # 接口调用动作
    
    wget --post-data "$post_string" --http-user=manifold --http-passwd=dw_manifold --timeout=8 --tries=1 --quiet --output-document="$output_file" "http://$api_server:63217/$api_name"

}


# IP地址对应地区信息获取
function getIpAreaInfo {

    WGET_TEMP_FILE=$(mktemp)
    
    local x="$1"
    
    wgetAction 121.14.36.27 nali.php $WGET_TEMP_FILE "ip=$x"
    
    IP_AREA_INFO=$(cat $WGET_TEMP_FILE|sed -r 's/ +/-/g')
    
    # IP_AREA_INFO=${IP_AREA_INFO:="信息查询失败"}
    
    [[ -z "$IP_AREA_INFO" ]] && { IP_AREA_INFO="信息查询失败" ; local result="1" ; } || { local result="0" ; }

    rm -f $WGET_TEMP_FILE
    
    echo $IP_AREA_INFO
    
    return 1
    
}


# （正/负）整数检查
function checkIsIntegerOrNot {

    # local x=${1:?$FUNCNAME Err! parameter must be gived}
    # 以上方式必须采用子shell的方式去调用，否则整个父shell都会退出

    local x
    
    x='^[+-]?[0-9]+$'

    if [[ "$1" =~ $x ]] ; then

        return 0
        
    else

        return 1
        
    fi
   
}


# 正整数检查
function checkIsPositiveIntegerOrNot {

    local x

    x='^[+]?[0-9]+$'

    if [[ "$1" =~ $x ]] ; then

        return 0
        
    else

        return 1
        
    fi
   
}


# 负整数检查
function checkIsNegativeIntegerOrNot {

    local x

    x='^[-]?[0-9]+$'

    if [[ "$1" =~ $x ]] ; then

        return 0
        
    else

        return 1
        
    fi

}


# IP合法性检查
function checkIsValidIp {

   local x

   x=$(echo "$1" | awk -F '.' 'NF==4 && (0<$1 && $1<255) &&  (0<=$2 && $2<255) &&  (0<=$3 && $3<255) &&  (0<$4 && $4<255)')

   if [ "$x" = "$1" ] && [ -n "$x" ] ; then

        return 0
        
   else
   
        return 1
        
   fi

}


# 小写字母转大写字母
function stringToUpper {

   local x=$( echo "$1" | tr 'a-z' 'A-Z' )
   
   echo "$x"

   return

}


# 大写字母转小写字母
function stringToLower {

   local x=$( echo "$1" | tr 'A-Z' 'a-z' )
   
   echo "$x"

   return

}


# /etc/crontab任务调度
function operateCrontab {


    # 参数个数检测
    if [ "$#" -ne 2 ];then
    
        code=55 ; msg="$FUNCNAME [ERR ] | parameter must be #2."

        printResult "$code" "$msg"

        return $code
        
    fi

    
    # 参数1检查 -- 操作类型
    local CRONTAB_ACTION=$( echo "$1" | awk '{if($1=="add" || $1=="del" || $1=="show") print $1}' )
    
    if [ "$CRONTAB_ACTION" != "$1" ] || [ -z "$CRONTAB_ACTION" ] ; then
    
        code=56 ; msg="$FUNCNAME [ERR ] | only accept parameter #1 is add|del|show."

        printResult "$code" "$msg"

        return $code
        
    fi
    
    
    # 参数2检查 -- crontab任务条目
    local CRONTAB_ENTRY=$( echo "$2" )
    
    # crontab条目语法检查（$1 分，$2 时，$3 日，$4 月，$5 周）
    # 2012-10-25 将 ( $6 ~ /[[:alpha:]]+/ )  &&  \ 替换成 ( $6 ~ /[a-zA-Z]+/ )  &&  \，因为ubuntu 9.10 的系统不认[[:alpha:]]
    CRONTAB_ENTRY=`echo "$CRONTAB_ENTRY" |  awk '( $1 !~ /[[:space:]]*#/  &&  $1 !~ /[0-9]+\/\*/ &&  $1 >= 0  &&  $1 < 60  || $1 == "*" || $1 ~ /\*\/[0-9]+/ )  &&  \
                                                 ( $2 >= 0  &&  $2 !~ /[0-9]+\/\*/ &&  $2 < 24  ||  $2 == "*" || $2 ~ /\*\/[0-9]+/ )  &&  \
                                                 ( $3 >= 1  &&  $3 !~ /[0-9]+\/\*/ &&  $3 <= 31  ||  $3 == "*" || $3 ~ /\*\/[0-9]+/ )  &&  \
                                                 ( $4 >= 1  &&  $4 !~ /[0-9]+\/\*/ &&  $4 <= 12  ||  $4 == "*" || $4 ~ /\*\/[0-9]+/ )  &&  \
                                                 ( $5 >= 0  &&  $5 !~ /[0-9]+\/\*/ &&  $5 <= 6  ||  $5 == "*" || $5 ~ /\*\/[0-9]+/ )  &&  \
                                                 ( $6 ~ /[a-zA-Z]+/ )  &&  \
                                                 ( NF >= 7 )'`
    
    if [ -z "$CRONTAB_ENTRY" ] ; then
    
        code=57 ; msg="$FUNCNAME [ERR ] | crontab format error."

        printResult "$code" "$msg"

        return $code

    fi
    
    
    # 任务调度
    
    # CRONTAB_ACTION:add
    if [ "$CRONTAB_ACTION" = "add" ];then
    
        if ! grep -q -x -F "$CRONTAB_ENTRY" /etc/crontab ; then

            # 备份当前/etc/crontab内容
            /bin/cp /etc/crontab $SYSOP_MANAGER_DIR/crontab.${DATE_STRING}_${TIME_STRING}
            
            echo "$CRONTAB_ENTRY" >> /etc/crontab || { code=58 ; msg="$FUNCNAME [ERR ] | add crontab entry [$CRONTAB_ENTRY] failed."

                                                       printResult "$code" "$msg"

                                                       return $code; }
            
        else
        
            code=59 ; msg="$FUNCNAME [ERR ] | entry [$CRONTAB_ENTRY] already existed."

            printResult "$code" "$msg"

            return $code
            
        fi
 
    fi

    
    # CRONTAB_ACTION:del
    if [ "$CRONTAB_ACTION" = "del" ];then
    
        if ! grep -q -x -F "$CRONTAB_ENTRY" /etc/crontab ; then

            code=60 ; msg="$FUNCNAME [ERR ] | entry [$CRONTAB_ENTRY] not existed."

            printResult "$code" "$msg"

            return $code
        
        else
        
            /bin/cp /etc/crontab $SYSOP_MANAGER_DIR/crontab.${DATE_STRING}_${TIME_STRING}
            
            grep -v -F "$CRONTAB_ENTRY" /etc/crontab > /tmp/crontab.$$ && \

            /bin/cp /tmp/crontab.$$ /etc/crontab || { code=61 ; msg="$FUNCNAME [ERR ] | del entry [$CRONTAB_ENTRY] failed."

                                                      printResult "$code" "$msg"

                                                      return $code; }

        fi
    
    fi
    
    
    # CRONTAB_ACTION:show
    if [ "$CRONTAB_ACTION" = "show" ];then
    
        if ! grep -x -F "$CRONTAB_ENTRY" /etc/crontab ; then
            
            code=60 ; msg="$FUNCNAME [ERR ] | entry [$CRONTAB_ENTRY] not existed."

            printResult "$code" "$msg"

            return $code
            
        fi

    fi
    
    
}


# 去掉参数两边的空格
function trimSpace {

   local x=$( echo "$1" | sed -r 's/^[[:space:]]+//g;s/[[:space:]]+$//g' )
   
   echo "$x"

   return

}



#------------------------#
# 基本信息检查           #
#------------------------#

# 脚本运行用户检查
function checkUser {
    
    local username=${1:?$FUNCNAME Err! username must be gived}
    
    local x=$(whoami)
   
	echo $x|egrep -q -w "$username" && return 0 || return 1

}



# 脚本运行操作系统检查
function checkOs {

    local x=${1:?$FUNCNAME Err! os must be gived}

    getOsDescription | egrep -q -i "$x" && return 0 || return 1

}



