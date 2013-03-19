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

          dstFile=/home/dspeak/release/bin/server.xml
     else
          dstFile="$2"
     fi

     print_log "whitelist file = $dstFile"

     if [ ! -f "$dstFile" ] ; then

          print_log "Err! white list file [$dstFile] not a file or not exist"

          aaRESULT=1; echo "aaRESULT=$aaRESULT" ; exit $aaRESULT 
     else
          # set dstFile to the full-path 

          dstFile="$(readlink -f $dstFile)"

          print_log "whitelist file full-path = $dstFile"

          tmpFile="${dstFile}.tmp"

          print_log "tmp file = $tmpFile"
     fi

     # you can input ip-isp-string , or base64-encoded string , both are supported

     ipList=$(echo "$1" | egrep -v '^[[:space:]]*$' | sed -r 's/^(([0-9]{1,3}\.){3}[0-9]{1,3}[[:space:]]+[[:alpha:]]+[[:space:]]+)+[0-9]+$//g') 

     if [ -n "$ipList" ] ; then

          # try base64 decode

          ipList=$(base64 -d <(echo "$1")) || { print_log "Err! invalid base64 string [$1], decode failed";

                                                aaRESULT=1 ; echo "aaRESULT=$aaRESULT" ; exit $aaRESULT; }

          if [ -z "$ipList" ] ; then
     
               print_log "Err! base64 decode failed" 
     
               aaRESULT=1 ; echo "aaRESULT=$aaRESULT" ; exit $aaRESULT
          else 
               print_log "Ok! base64 decode succeed"
          fi
     else
          print_log

          print_log "Ok! input type is ip-isp-cmdbGroupId string , no need to decode"

          # re-assign the ipList var to the input content

          ipList=$(echo "$1" | egrep -v '^[[:space:]]*$')
     fi

     print_log

     print_log "$ipList"

     print_log
     
     # sort ip list reverse , so it will add in asscending order finally

     #ipList=$(echo "$ipList" | sort -t '.' -k1,1rn -k2,2rn -k3,3rn -k4,4rn)

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

     while read line ; do

          print_log "----------------------------------------------------------------------------------------------------"

          set -- $line

          print_log "read line content is : $line"

          if [ $# -eq 3 ] ; then

                ip=$1 ; isp=$2 ; cmdbGroupId=$3 ; ipType="single"

                print_log "ip=$ip isp=$isp cmdbGroupId=$cmdbGroupId"

          elif [ $# -eq 5 ] ; then

                ip1=$1 ; isp1=$2; ip2=$3 ; isp2=$4 ; cmdbGroupId=$5 ; ipType="multi"

                print_log "ip1=$ip1 isp1=$isp1 ip2=$ip2 isp2=$isp2 cmdbGroupId=$cmdbGroupId"
          else
                print_log "Err! wrong line \"$line\"" ; aaRESULT=1 ; echo "aaRESULT=$aaRESULT" ; exit $aaRESULT
          fi

          # allow isp : dip,wip,jip,yip,bip,brip,hkip

          # check 1 -- try to find if already exist

          if [ "$ipType" = "single" ] ; then

                 if egrep -q "\"${ip//./\\.}\"" $tmpFile ; then

                      print_log "Err! single-line ip : $ip already exist"

                      print_log "$(egrep "\"${ip//./\\.}\"" $tmpFile)"

                      aaRESULT=1 ; echo "aaRESULT=$aaRESULT" ; exit $aaRESULT
                 else
                      print_log "Ok! single-line ip $ip not exist , prepare to add"
                 fi
           else
                 if egrep -q "\"(${ip1//./\\.}|${ip2//./\\.})\"" $tmpFile ; then

                      print_log "Err! multi-line ip : $ip1 or $ip2 already exist"

                      print_log "$(egrep "\"(${ip1//./\\.}|${ip2//./\\.})\"" $tmpFile)"    

                      aaRESULT=1 ; echo "aaRESULT=$aaRESULT" ; exit $aaRESULT
                 else
                      print_log "Ok! multi-line ip $ip1 and $ip2 not exist , prepare to add"
                 fi
          fi

          # check 2 -- find all same cmdbGroupId entries and check their "groupid" attr

          sameCmdbGroupIdCount=$(sed -n "/<allows>/,/<\/allows>/p" $tmpFile | egrep "cmdbGroupId=\"$cmdbGroupId\"" | sort -u |wc -l)
          
          sameCmdbGroupIdList=$(sed -n "/<allows>/,/<\/allows>/p" $tmpFile | egrep "cmdbGroupId=\"$cmdbGroupId\"" | sort -u)
  
          groupIdList=$(echo "$sameCmdbGroupIdList" | egrep -o 'groupId="[^"]+"' | sort -u) 

          if [ $sameCmdbGroupIdCount -gt 0 ] && [ $(echo "$groupIdList" | wc -l) -gt 1 ] ; then

               print_log "Err! find multiple groupId settings for cmdbGroupId : $cmdbGroupId"

               print_log "$groupIdList"

               aaRESULT=1 ; echo "aaRESULT=$aaRESULT" ; exit $aaRESULT

          elif [ $sameCmdbGroupIdCount -gt 0 ] && [ $(echo "$groupIdList" | wc -l) -eq 1 ] ; then

               print_log "Ok! only a single groupId is found for cmdbGroupId ($cmdbGroupId)"

               print_log "$groupIdList"

               newNetwork="false"

          elif [ $sameCmdbGroupIdCount -eq 0 ] ; then

               print_log "Ok! no entries for cmdbGroupId ($cmdbGroupId) found , it is a ( NEW ) network"

               newNetwork="true"
          fi

          # check 3 -- find all same cmdbGroupId entries and check any entries without groupId attr

          noGroupIdList=$(echo "$sameCmdbGroupIdList" | egrep -v 'groupId="' |sort -u)

          if [ "$newNetwork" = "false" ] ; then

               if [ -n "$noGroupIdList" ] ; then

                     print_log "Err! find same cmdbGroupId entries , but someone without groupId attr setted"

                     print_log "$noGroupIdList"

                     aaRESULT=1 ; echo "aaRESULT=$aaRESULT" ; exit $aaRESULT
               else
                     print_log "Ok! find same cmdbGroupId entries, all with groupId attr setted"
               fi

          else
               print_log "Ok! it's a ( NEW ) network . no need to check groupId"
          fi

          # chck 4 -- if only a single groupId is found within the same cmdbGroupId , and no incomplete entries , then add

          if [ "$newNetwork" = "false" ]; then

               # set the final groupId

               groupId=$(echo "$groupIdList" | awk -F '"' '{print $2}')

               print_log "Ok! use old groupId : ( $groupId )"

          elif [ "$newNetwork" = "true" ] ; then

               if [ "$ipType" = "multi" ] ; then

                    groupId="$(echo $ip1 | sed -r 's/\.[0-9]+$/.0/')"

                    print_log "Ok! use default groupId ($groupId) for ip1 ($ip1)"
               else
                    groupId="$(echo $ip | sed -r 's/\.[0-9]+$/.0/')"

                    print_log "Ok! use default groupId ($groupId) for ip ($ip)"
               fi
          else
               print_log "use other [$newNetwork]"

          fi

          if [ "$ipType" = "single" ] ; then
   
               sed -i -r "/<allows>/a \      <allow ${isp}=\"${ip}\" groupId=\"$groupId\" cmdbGroupId=\"$cmdbGroupId\"\/>" $tmpFile

               print_log "add entries <allow ${isp}=\"${ip}\" groupId=\"$groupId\" cmdbGroupId=\"$cmdbGroupId\"\/>"

               print_log $(egrep "\"${ip}\"" $tmpFile)
          else
               sed -i -r "/<allows>/a \      <allow ${isp1}=\"${ip1}\" ${isp2}=\"${ip2}\" groupId=\"$groupId\" cmdbGroupId=\"$cmdbGroupId\"\/>" $tmpFile

               print_log "add entries <allow ${isp1}=\"${ip1}\" ${isp2}=\"${ip2}\" groupId=\"$groupId\" cmdbGroupId=\"$cmdbGroupId\"\/>"

               print_log $(egrep "\"${ip1}\"" $tmpFile)
          fi

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

         (sleep 1;echo "reloadconf";sleep 1)|telnet 0 4500 2>/dev/null | grep 'reloadconf succeed' && \

         (sleep 1;echo "reloadconf";sleep 1)|telnet 0 4501 2>/dev/null | grep 'reloadconf succeed'

         if [ $? -eq 0 ] ; then

              print_log "Ok! reload new conf succeed"

              print_log "Finished"

              aaRESULT=0 ; echo "aaRESULT=$aaRESULT"; exit $aaRESULT 
         else
              print_log "Err! reload new conf failed , begin to rollback"

              cp $dstFile ${dstFile}.bad
           
              mv $bakFile $dstFile

              (sleep 1;echo "reloadconf";sleep 1)|telnet 0 4500 ; (sleep 1;echo "reloadconf";sleep 1)|telnet 0 4501

              print_log "rollback to old whitelist file succeed"

              print_log "Finished"

              aaRESULT=1; echo "aaRESULT=$aaRESULT" ; exit $aaRESULT 
         fi    
    else
         print_log "Err! $dstFile backup failed"

         chattr -i $dstFile 

         aaRESULT=1 ; echo "aaRESULT=$aaRESULT" ; exit $aaRESULT 
    fi


fi
