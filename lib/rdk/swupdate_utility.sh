#!/bin/sh
##########################################################################
# If not stated otherwise in this file or this component's Licenses.txt
# file the following copyright and licenses apply:
#
# Copyright 2019 RDK Management
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##########################################################################
## Script to do Device Initiated Firmware Download
## Once box gets IP, check for DCMSettings.conf
## If DCMSettings.conf file is present schedule a cron job using schedule time from conf file
## Invoke deviceInitiated with no retries in this case
## If DCMSettings.conf is not present, Invoke DeviceInitiated with retry (1hr)
##########################################################################

. /etc/include.properties
. /etc/device.properties

CLOUD_URL=$CLOUDURL

echo "Started executing swupdate_utility.sh and device type is :"$DEVICE_TYPE
if [ "$DEVICE_TYPE" != "mediaclient" ]; then
   . $RDK_PATH/commonUtils.sh
else
   . $RDK_PATH/utils.sh
fi

response_file=/tmp/cloudhttpresp.txt

if [ -f $response_file ] ; then
    rm $response_file
fi

if [ ! -d "/rdklogs/logs" ] ; then
   mkdir -p /rdklogs/logs
fi

### main app

echo "Main app & Triggering deviceInitiatedFWDnld.sh "

currentVersion=`grep "^imagename" /version.txt | cut -d ':' -f2`
#estbMac=`ifconfig erouter0 | grep HWaddr | cut -c39-55`

if [ "$DEVICE_TYPE" == "hybrid" ] || [ "$DEVICE_TYPE" == "mediaclient" ] ; then
 estbMac=`ifconfig eth0 | grep HWaddr | cut -c39-55`
elif [ "$DEVICE_TYPE" == "broadband" ]; then 
 estbMac=`ifconfig erouter0 | grep HWaddr | cut -c39-55`
fi

JSONSTR=$estbMac

CURL_CMD="curl -w "%{http_code}" '$CLOUD_URL$JSONSTR'  -o /tmp/cloudurl.txt >> /tmp/cloudhttpresp.txt" 
echo URL_CMD: $CURL_CMD
result= eval $CURL_CMD

curl_http_code=$(awk -F\" '{print $1}' /tmp/cloudhttpresp.txt)
if [ "$curl_http_code" != "200" ]; then    
    #Added for retry - START 
    rm -f /tmp/cloudhttpresp.txt			
    rm -f /tmp/cloudurl.txt

    xconfRetryCount=0
    while [ $xconfRetryCount -ne 10 ]
    do
        echo "Trying to Retry connection with XCONF server..."
		
	CURL_CMD="curl -w "%{http_code}" '$CLOUD_URL$JSONSTR'  -o /tmp/cloudurl.txt >> /tmp/cloudhttpresp.txt" 

        result= eval $CURL_CMD

	curl_http_code_retry=$(awk -F\" '{print $1}' /tmp/cloudhttpresp.txt)
		
        if [ "$curl_http_code_retry" != "200" ]; then
            echo "Error in establishing communication with xconf server."
			if [ $xconfRetryCount -ne 0 ]; then sleep 30; fi
			rm -f /tmp/cloudhttpresp.txt			
			rm -f /tmp/cloudurl.txt
		else
			echo "After retries...No error in curl command and curl http code is:"$curl_http_code_retry
			break
		fi

        xconfRetryCount=`expr $xconfRetryCount + 1`
    done
    #Added for retry - END
    #echo "Error from cloud exiting,check in upcoming reboot-------------"
    #exit 0
else
      echo "No error in curl command and curl http code is:"$curl_http_code
fi                           

cloudFwVer=`cat /tmp/cloudurl.txt | tr -d '\n' | sed 's/[{}]//g' | awk  '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' | sed 's/\"\:\"/\|/g' | sed -r 's/\"\:(true)($)/\|true/gI' | sed -r 's/\"\:(false)($)/\|false/gI' | sed -r 's/\"\:(null)($)/\|\1/gI' | sed -r 's/\"\:([0-9]+)($)/\|\1/g' | sed 's/[\,]/ /g' | sed 's/\"//g' | grep firmwareVersion | cut -d \| -f2`

cloudfirmwareversion=$cloudFwVer
echo "cloud version is "$cloudfirmwareversion
echo "RPI version is "$currentVersion

activeBankpart=`sed -e "s/.*root=//g" /proc/cmdline | cut -d ' ' -f1 | cut -c14`
echo "Active bank is:"$activeBankpart
rpiimageModel=`cat /version.txt | grep imagename | cut -c11-14`
echo "rpiimageModel in dev is :"$rpiimageModel
cloudimageModel=`cat /tmp/cloudurl.txt | tr -d '\n' | sed 's/[{}]//g' | awk  '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' | sed 's/\"\:\"/\|/g' | sed -r 's/\"\:(true)($)/\|true/gI' | sed -r 's/\"\:(false)($)/\|false/gI' | sed -r 's/\"\:(null)($)/\|\1/gI' | sed -r 's/\"\:([0-9]+)($)/\|\1/g' | sed 's/[\,]/ /g' | sed 's/\"//g' | grep firmwareVersion | cut -d \| -f2 | cut -c1-4`

echo "cloudimageModel  is :"$cloudimageModel
nrparts=`ls -al /dev/mmcblk0p* | wc -l`

echo "no of parts is :"$nrparts
if [ "$nrparts" = "2" ]; then
   sh $RDK_PATH/deviceInitiatedFWDnld.sh 3 1 >> /rdklogs/logs/swupdate.log &
   echo "exiting the script  after additional part creation !!"
   exit 0
fi
if [ "$activeBankpart" = "2" ]; then
   echo "active bank is 0 so fetch info from passive and partition is:"$activeBankpart
   mkdir -p /fbank3
   mount /dev/mmcblk0p3 /fbank3
   rpipassivebankimageModel=`cat /fbank3/version.txt | grep imagename | cut -c11-14`
   passivebankVersion=`grep "^imagename" /fbank3/version.txt | cut -d ':' -f2`
   echo "rpipassivebankimageModel:"$rpipassivebankimageModel
   echo "passivebankVersion:"$passivebankVersion
   umount /fbank3
else
   echo "active bank is 1 and partition is :"$activeBankpart
   mkdir -p /fbank2
   mount /dev/mmcblk0p2 /fbank2
   rpipassivebankimageModel=`cat /fbank2/version.txt | grep imagename | cut -c11-14`
   passivebankVersion=`grep "^imagename" /fbank2/version.txt | cut -d ':' -f2` 
   echo "rpipassivebankimageModel:"$rpipassivebankimageModel
   echo "passivebankVersion:"$passivebankVersion
   umount /fbank2
fi
if [ "$rpipassivebankimageModel" = " " ] && [ "$rpiimageModel" != "rdkb" ] && [ "$cloudimageModel" != "rdkb" ]; then 
       echo "since bank1 p3 is empty and rpiimage model in active bank is video"    
       if [ "$currentVersion" != "$cloudfirmwareversion" ]; then                    
          echo "check video versions and upgrade if mismatches !!"                  
          sh $RDK_PATH/deviceInitiatedFWDnld.sh 3 1 >> /rdklogs/logs/swupdate.log &
       else
          echo "video ver same !!"                  
       fi       
fi                                                              
if [ "$rpipassivebankimageModel" = " " ] && [ "$rpiimageModel" != "rdkb" ] && [ "$cloudimageModel" = "rdkb" ]; then 
       echo "bank1 p3 is empty and active part has video,simply upgrade broadband !!"                  
       sh $RDK_PATH/deviceInitiatedFWDnld.sh 3 1 >> /rdklogs/logs/swupdate.log &
fi
if [ "$rpipassivebankimageModel" = " " ] && [ "$rpiimageModel" = "rdkb" ] && [ "$cloudimageModel" != "rdkb" ]; then
       echo "bank1 p3 is empty and active part has broadband,simply upgrade video"    
       sh $RDK_PATH/deviceInitiatedFWDnld.sh 3 1 >> /rdklogs/logs/swupdate.log &
fi                                                                                                                  
if [ "$rpipassivebankimageModel" = " " ] && [ "$rpiimageModel" = "rdkb" ] && [ "$cloudimageModel" = "rdkb" ]; then 
   echo "bank1 p3 is empty and active part has video,simply upgrade broadband !!"                
   if [ "$currentVersion" != "$cloudfirmwareversion" ]; then    
     echo "check broadband versions and upgrade if mismatches !!"               
     sh $RDK_PATH/deviceInitiatedFWDnld.sh 3 1 >> /rdklogs/logs/swupdate.log &    
   else
     echo "broadband same !!"               
   fi                             
fi 
if [ "$rpipassivebankimageModel" = "rdkb" ] && [ "$rpiimageModel" != "rdkb" ] && [ "$cloudimageModel" != "rdkb" ]; then
       echo "since bank1 p3 is video and pass bank is rdkb cloud is video check video version and upgrade if mismatches"                                    
       if [ "$currentVersion" != "$cloudfirmwareversion" ]; then                                                    
          echo "check video versions and upgrade if mismatches !!"                                                  
          sh $RDK_PATH/deviceInitiatedFWDnld.sh 3 1 >> /rdklogs/logs/swupdate.log &                                
       else
          echo "video versions same !!"                                                  
       fi                                                                                                           
fi    

if [ "$rpipassivebankimageModel" = "rdkb" ] && [ "$rpiimageModel" != "rdkb" ] && [ "$cloudimageModel" = "rdkb" ]; then
       echo "since bank1 p3 is video and pass bank is rdkb cloud is broadand check broadband is passiveversion and upgrade if mismatches"
       if [ "$passivebankVersion" != "$cloudfirmwareversion" ]; then                                                        
          echo "check broadband versions and upgrade if mismatches !!"                                                  
          sh $RDK_PATH/deviceInitiatedFWDnld.sh 3 1 >> /rdklogs/logs/swupdate.log &                               
       else
           echo "cloud version already there in passive bank broadband !!"
       fi                                                                                                          
fi

if [ "$rpipassivebankimageModel" != "rdkb" ] && [ "$rpiimageModel" = "rdkb" ] && [ "$cloudimageModel" != "rdkb" ]; then  
       echo "since bank1 p3 is broadband and pass bank is rdkv cloud is video check video is passiveversion and upgrade if mismatches"
       if [ "$passivebankVersion" != "$cloudfirmwareversion" ]; then                                                                     
          echo "check video versions and upgrade if mismatches !!"                                                                       
         sh $RDK_PATH/deviceInitiatedFWDnld.sh 3 1 >> /rdklogs/logs/swupdate.log &       
       else
         echo "cloud version already there in passive bank video !!"                                              
       fi                                                                                                                                
fi 

if [ "$rpipassivebankimageModel" != "rdkb" ] && [ "$rpiimageModel" = "rdkb" ] && [ "$cloudimageModel" = "rdkb" ]; then                  
       echo "since bank1 p3 is broadband and pass bank is rdkv cloud is broadband check broadband version and upgrade if mismatches"       
       if [ "$currentVersion" != "$cloudfirmwareversion" ]; then                                                             
          echo "check broadband versions and upgrade if mismatches !!"                                                                       
         sh $RDK_PATH/deviceInitiatedFWDnld.sh 3 1 >> /rdklogs/logs/swupdate.log &                                                     
       else
        echo "broadband matches!!" 
       fi                                                                                                                                
fi 

if [ "$rpipassivebankimageModel" = "rdkb" ] && [ "$rpiimageModel" = "rdkb" ] && [ "$cloudimageModel" = "rdkb" ]; then                  
       echo "since both banks has broadband alone and cloud also has broadband-compare versions with cloud"                 
       if [ "$currentVersion" != "$cloudfirmwareversion" ] && [ "$passivebankVersion" != "$cloudfirmwareversion" ]; then                                                                         
          echo "both banks mismatches with cloud broadband mismatches !!"                                                                       
           sh $RDK_PATH/deviceInitiatedFWDnld.sh 3 1 >> /rdklogs/logs/swupdate.log &                                                     
       else
         echo "atleast one bank matches broadband"
       fi                                                                                                                                
fi                                                                                                                                       
                                                                                                                                         
if [ "$rpipassivebankimageModel" = "rdkb" ] && [ "$rpiimageModel" = "rdkb" ] && [ "$cloudimageModel" != "rdkb" ]; then                   
          echo "both banks has broadband and cloud is video simply upgrade !!"                                                                
          sh $RDK_PATH/deviceInitiatedFWDnld.sh 3 1 >> /rdklogs/logs/swupdate.log &                                                  
fi  

if [ "$rpipassivebankimageModel" != "rdkb" ] && [ "$rpiimageModel" != "rdkb" ] && [ "$cloudimageModel" != "rdkb" ]; then                   
       echo "since both banks has video alone and cloud also has video-compare versions with cloud"                              
       if [ "$currentVersion" != "$cloudfirmwareversion" ] && [ "$passivebankVersion" != "$cloudfirmwareversion" ]; then                 
          echo "both banks mismatches with cloud video mismatches !!"                                                                         
          sh $RDK_PATH/deviceInitiatedFWDnld.sh 3 1 >> /rdklogs/logs/swupdate.log &                                                     
       else
          echo "atleast one bank matches video"
       fi                                                                                                                                
fi                                                                                                                                   
                                                                                                                                      
                                                                                                                                    
if [ "$rpipassivebankimageModel" != "rdkb" ] && [ "$rpiimageModel" != "rdkb" ] && [ "$cloudimageModel" = "rdkb" ]; then              
       echo "both banks has video and cloud is broadband simply upgrade !!"
         sh $RDK_PATH/deviceInitiatedFWDnld.sh 3 1 >> /rdklogs/logs/swupdate.log &
fi  


