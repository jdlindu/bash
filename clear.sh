#!/bin/bash

#Modified at 2012/12/25 by mrlin

source commonFunction.sh

function alarm(){
        python /home/dspeak/yyms/yymp/yymp_report_script/yymp_report_alarm.py 10660 74738 0 $*
}

reserve_day=5
log_name="*.log.*.gz"
cd /data/yy/log
find /data/yy/log -type f -name $log_name -mtime +$reserve_day | xargs rm
bigFiles=$(find /data/yy/log -name "*.log" -size +10G )
disk_usage=$(df -lh | grep -w "/data" | awk '{print $5}' | tr -d '%')
echo "disk usage = $disk_usage"
if [ "$disk_usage" -gt 80 ] && alarm "disk_usage greate than 80,is $disk_usage" && [ -n "$bigFiles" ]
then
		#返回被清空大文件列表
		find /data/yy/log -name "*.log" -size +10G | xargs ls -lh | awk '{print "BigFile\t"$NF"\t"$5}'
        echo "$bigFiles" | while read bigFile 
                           do
                                [[ -f "$bigFile" ]] && alarm "$bigFile is greater than 10G" && cat /dev/null > $bigFile
                           done
fi
disk_usage=$(df -lh | grep -w "/data" | awk '{print $5}' | tr -d '%')
if [ "$disk_usage" -gt 90 ] 
then
		#返回大文件列表
		find /data/ -name "*.log" -size +10G | xargs ls -lh | awk '{print "OtherBigFile\t"$NF"\t"$5}'
fi

# 最后的信息返回
df -lh | awk '{if(NR!=1)print "DISK\t"$NF"\t"$(NF-1)}'
code=0; msg="$SCRIPT_NAME [INFO ] | successful."

printResult "$code" "$msg"

exit $code