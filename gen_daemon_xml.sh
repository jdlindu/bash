#!/bin/bash

trap 'if [ -n "$dstFile" ] ; then 

         chattr -i $dstFile &>/dev/null 

      fi' EXIT TERM KILL HUP

set +H

export PATH="/usr/bin:/bin:/sbin:/usr/sbin"

export LANG=C

function print_log {

   local line

   while read line ; do

      echo "$(date +'%F %T')| $line"

   done < <(echo "$*")

   return

}

if [ "$UID" -ne 0 ] ; then

     print_log "Err! only root user can run this script"

     aaRESULT=1 ; echo "aaRESULT=$aaRESULT" ; exit $aaRESULT 
fi

chmod a+x $0

print_log "$0 $*"

# set xml syntax check python code

code=$( 
cat <<EOF
#!/usr/bin/env python
from xml.dom.minidom import parse
import sys
if not sys.argv[1]:
        sys.exit(1)
try:
        parse(sys.argv[1])
except:
        sys.exit(1)
EOF
)

# paramater check

if [ $# -lt 1 ] || [ $# -gt 2 ] ; then
	
     print_log "Err! $0 <base64-encoded paras> [/path/to/file]"; aaRESULT=1 ; echo "aaRESULT=$aaRESULT" ; exit $aaRESULT 
else
     # check whether file exist

     if [ $# -eq 1 ] ; then 

          dstFile=/home/dspeak/release/bin/allow.xml
     else
          dstFile="$2"
     fi

     print_log "whitelist file = $dstFile"

     if [ ! -f "$dstFile" ] ; then

          print_log "Err! white list file [$dstFile] not a file or not exist"

          aaRESULT=1 ; echo "aaRESULT=$aaRESULT" ; exit $aaRESULT 
     else
          # set dstFile to the full-path 

          dstFile="$(readlink -f $dstFile)"

          print_log "whitelist file full-path = $dstFile"

          tmpFile="${dstFile}.tmp"

          print_log "tmp file = $tmpFile"
     fi

     # decoded base64-encoded string

     ipList=$(base64 -d <(echo "$1")) || { print_log "Err! invalid base64 string [$1], decode failed";

                                           aaRESULT=1 ; echo "aaRESULT=$aaRESULT" ; exit $aaRESULT; }

     if [ -z "$ipList" ] ; then

        print_log "Err! decode result is Empty !!!"

        aaRESULT=1 ; echo "aaRESULT=$aaRESULT" ; exit $aaRESULT 
     fi

     # check ip list format if it contains invalid characters

	 x=$(echo "$ipList" | sed -r 's/([0-9]{1,3}\.){3}[0-9]{1,3}[[:space:]]+[[:alpha:]]+[[:space:]]([0-9]{1,3}\.){3}[0-9]{1,3}[[:space:]]+[[:alpha:]]//g')
     #x=$(echo "$ipList" | sed -r 's/([0-9]{1,3}\.){3}[0-9]{1,3}[[:space:]]+[[:alpha:]]+//g')

     if [ -n "$x" ] ; then

          print_log "ip list contain invalid characters : [$x]"

          print_log "it should be \"<ip> <isp>\" format"
     
          aaRESULT=1 ; echo "aaRESULT=$aaRESULT" ; exit $aaRESULT 
     fi
     
     # trasfer to UPPER case and split them

     ipList=$(echo "$ipList" | tr '[[:lower:]]' '[[:upper:]]' | sort -t '.' -k1,1rn -k2,2rn -k3,3rn -k4,4rn) 

     # check whether <allows> line exist

     symbolLine='<allows>'

     if ! egrep -q "^[[:space:]]*${symbolLine}[[:space:]]*$" $dstFile ; then

          print_log "Err! $symbolLine line NOT found in $dstFile"

          aaRESULT=1 ; echo "aaRESULT=$aaRESULT" ; exit $aaRESULT 

     elif [ $(egrep -c "^[[:space:]]*${symbolLine}[[:space:]]*$" $dstFile) -gt 1 ] ; then

          print_log "Err! more than 1 $symbolLine line found in $dstFile"

          aaRESULT=1 ; echo "aaRESULT=$aaRESULT" ; exit $aaRESULT
     fi

     # check whether is opened by vi

     swpFile="$(dirname $dstFile)/.$(basename $dstFile).swp"

     if [ -f "$swpFile" ] ; then

        print_log "Err! found swp file $swpFile , may be opened by vim" ; aaRESULT=1 ; echo "aaRESULT=$aaRESULT" ; exit $aaRESULT

     fi

     # change $dstFile to readonly

     if ! chattr +i $dstFile ; then

          print_log "Err! set file [$dstFile] read-only failed"; aaRESULT=1 ; echo "aaRESULT=$aaRESULT" ; exit $aaRESULT 
     fi           

     # create a backup file

     cp $dstFile $tmpFile 

     # begin to work

     while read ip isp ; do

          if [ "$isp" != "CTL" ] && [ "$isp" != "CNC" ] && [ "$isp" != "MOB" ] && [ "$isp" != "EDU" ] && [ "$isp" != "BGP" ] && [ "$isp" != "BR"] && [ "$isp" != "HK" ]; then

             print_log "Err! invalid isp : $isp for ip $ip"

             aaRESULT=1 ; echo "aaRESULT=$aaRESULT" ; exit $aaRESULT 
          fi 

          print_log "ip=$ip ; isp=$isp"

          # delete old line

          lineNumber=$(egrep "[[:space:]]*<ip type=\"${isp}\">${ip}</ip>[[:space:]]*$" $tmpFile -n | awk -F':' '{print $1}')

          if [ -n "$lineNumber" ] ; then

               print_log "lineNumber=[$lineNumber]"

               print_log "content=$(sed -n "${lineNumber}p" $tmpFile)" 

               startLine=$(( lineNumber - 1 ))

               if ! sed -n "${startLine}p" $tmpFile | grep -q '^[[:space:]]*<host>[[:space:]]*$' ; then

                  x=$(sed -n "${startLine}p" $tmpFile | sed -r 's/^[[:space:]]*//g;s/[[:space:]]*$//g')

                  print_log "Err! $ip is not a single-line ip (start-line:$startLine is $x)" 

                  aaRESULT=1 ; echo "aaRESULT=$aaRESULT" ; exit $aaRESULT
               fi

               endLine=$(( lineNumber + 1 ))

               if ! sed -n "${endLine}p" $tmpFile | egrep -q '^[[:space:]]*</host>[[:space:]]*$' ; then
                  
                  x=$(sed -n "${endLine}p" $tmpFile |  sed -r 's/^[[:space:]]*//g;s/[[:space:]]*$//g')

                  print_log "Err! $ip is not a single-line ip (end-line:$endLine is $x)"

                  aaRESULT=1 ; echo "aaRESULT=$aaRESULT" ; exit $aaRESULT
               fi

               print_log "found ${ip}:${isp} exist, remove it"

               sed -i "${startLine},${endLine}d" $tmpFile
          else
               echo "${ip}:${isp} not found , add it"  
          fi  

          # insert new one

          insertCmd="/<allows>/a \        <host>\n            <ip type=\"${isp}\">${ip}</ip>\n        </host>"

          sed -i -r "$insertCmd" $tmpFile

     done <<< "$ipList"

     # check xml syntax

     if python <(echo "$code") ${tmpFile:?XML file must be gived} ; then

          print_log "Ok! $tmpFile XML syntax check passed"
     else
          print_log "Err! $tmpFile XML syntax check failed"

          chattr -i $dstFile

          aaRESULT=1 ; echo "aaRESULT=$aaRESULT" ; exit $aaRESULT 
     fi

     # backup $dstFile and overwrite it with $tmpFile
   
     bakFile="$dstFile.$(date +'%Y%m%d_%H%M')"

     if cp $dstFile $bakFile ; then

         print_log "Ok! $dstFile backup succeed"

         chattr -i $dstFile

         mv $tmpFile $dstFile

         # reload

         localIp=$(ifconfig eth0 |grep 'inet addr:' | head -n1 | awk -F '[ :]+' '{print $4}')

         print_log "local ip = $localIp"

         (sleep 1;echo "reload_allow";sleep 1) | telnet $localIp 2020 2>/dev/null | grep 'reloaded' 

         if [ $? -eq 0 ] ; then

              print_log "Ok! reload new conf succeed"

              print_log "Finished"

              aaRESULT=0 ; echo "aaRESULT=$aaRESULT" ; exit $aaRESULT 
         else
              print_log "Err! reload new conf failed , begin to rollback"

              cp $dstFile ${dstFile}.bad
           
              mv $bakFile $dstFile

              (sleep 1;echo "reload_allow";sleep 1) | telnet $localIp 2020 

              print_log "rollback to old whitelist file succeed"

              print_log "Finished"

              aaRESULT=1 ; echo "aaRESULT=$aaRESULT" ; exit $aaRESULT 
         fi    
    else
         print_log "Err! $dstFile backup failed"

         chattr -i $dstFile 

         aaRESULT=1 ; echo "aaRESULT=$aaRESULT" ; exit $aaRESULT 
    fi
fi
