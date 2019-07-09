#!/bin/sh
##########################################################################
# If not stated otherwise in this file or this component's Licenses.txt
# file the following copyright and licenses apply:
#
# Copyright 2018 RDK Management
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
##################################################################
## Script to do Device Configuration Management
## Updates the following information in the settop box 
##    * Check Schedule
##    * Check Log Upload Settings
##    * Check Configuration
## Author: Ajaykumar/Shakeel/Suraj
##################################################################

. /etc/include.properties
. /etc/device.properties
. /etc/dcm.properties

if [ "$DEVICE_TYPE" != "broadband" ]; then
. /lib/rdk/snmpUtils.sh
else
. /lib/rdk/utils.sh
fi

if [ -z $LOG_PATH ]; then
    LOG_PATH="/opt/logs/"
fi
if [ -z $PERSISTENT_PATH ]; then
    PERSISTENT_PATH="/tmp"
fi

export PATH=$PATH:/usr/bin:/bin:/usr/local/bin:/sbin:/usr/local/lighttpd/sbin:/usr/local/sbin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/Qt/lib:/usr/local/lib

reboot_flag=$4


if [ $reboot_flag -eq 1 ] && [ -f /tmp/.standby ]; then
     echo "`/bin/timestamp` Exiting from DCM activities since box is in standby.!"       
     exit 0
fi
if [ "true" != "$RDK_EMULATOR" ]; then
if [ $# -ne 5 ]
then
    echo "`/bin/timestamp` Argument does not match" >> $LOG_PATH/dcmscript.log
    exit 1
fi
fi

. $RDK_PATH/utils.sh

echo "`/bin/timestamp` Starting execution of DCMscript.sh" >> $LOG_PATH/dcmscript.log
#---------------------------------
# Initialize Variables
#---------------------------------
# URL
URL=$2
tftp_server=$3
checkon_reboot=$5

 echo "`/bin/timestamp` URL: $URL" >> $LOG_PATH/dcmscript.log
 echo "`/bin/timestamp` DCM_TFTP_SERVER: $tftp_server" >> $LOG_PATH/dcmscript.log
 echo "`/bin/timestamp` REBOOT_FLAG: $reboot_flag" >> $LOG_PATH/dcmscript.log
 echo "`/bin/timestamp` CHECK_ON_REBOOT: $checkon_reboot" >> $LOG_PATH/dcmscript.log

 
if [ -f "/tmp/DCMSettings.conf" ]
then
    Check_URL=`grep 'urn:settings:ConfigurationServiceURL' /tmp/DCMSettings.conf | cut -d '=' -f2 | head -n 1`
    if [ -n "$Check_URL" ]
    then
        URL=`grep 'urn:settings:ConfigurationServiceURL' /tmp/DCMSettings.conf | cut -d '=' -f2 | head -n 1`
        #last_char=`echo $URL | sed -e 's/\(^.*\)\(.$\)/\2/'`
        last_char=`echo $URL | awk '$0=$NF' FS=`
        if [ "$last_char" != "?" ]
        then
            URL="$URL?"
        fi
    fi
fi
# File to save curl response 
FILENAME="$PERSISTENT_PATH/DCMresponse.txt"
# File to save http code
HTTP_CODE="$PERSISTENT_PATH/http_code"
rm -rf $HTTP_CODE
# Cron job file name
current_cron_file="$PERSISTENT_PATH/cron_file.txt"
# Tftpboot Server Ip
echo TFTP_SERVER: $tftp_server >> $LOG_PATH/dcmscript.log
# Timeout value
timeout=10
# http header
HTTP_HEADERS='Content-Type: application/json'

## RETRY DELAY in secs
RETRY_DELAY=60
## RETRY COUNT
RETRY_COUNT=3
default_IP=$DEFAULT_IP
upload_protocol='HTTP'
upload_httplink=$HTTP_UPLOAD_LINK

#---------------------------------
# Function declarations
#---------------------------------

## FW version from version.txt 
getFWVersion()
{
    #cat /version.txt | grep ^imagename:PaceX1 | grep -v image
    verStr=`cat /version.txt | grep ^imagename: | cut -d ":" -f 2`
    echo $verStr
}

## Identifies whether it is a VBN or PROD build
getBuildType()
{
   echo $BUILD_TYPE
}

## Get ECM mac address
getECMMacAddress()
{
    address=`getECMMac`
	mac=`echo $address | tr -d ' ' | tr -d '"'`
	echo $mac
}

## Get Receiver Id
getReceiverId()
{
    if [ -f "/opt/www/whitebox/wbdevice.dat" ]
    then
        ReceiverId=`cat /opt/www/whitebox/wbdevice.dat`
        echo "$ReceiverId"
    else
        echo " "
    fi
}

## Get Controller Id
getControllerId()
{
    echo "2504"
}

## Get ChannelMap Id
getChannelMapId()
{
    echo "2345"
}

## Get VOD Id
getVODId()
{
    echo "15660"
}

## Process the responce and update it in a file DCMSettings.conf
processJsonResponse()
{   
    if [ -f "$FILENAME" ]
    then
        OUTFILE='/tmp/DCMSettings.conf'
        sed -i 's/,"urn:/\n"urn:/g' $FILENAME # Updating the file by replacing all ',"urn:' with '\n"urn:'
        sed -i 's/{//g' $FILENAME    # Deleting all '{' from the file 
        sed -i 's/}//g' $FILENAME    # Deleting all '}' from the file
        echo "" >> $FILENAME         # Adding a new line to the file 

        #rm -f $OUTFILE #delete old file
        cat /dev/null > $OUTFILE #empty old file

        while read line
        do  
            
            # Parse the settings  by
            # 1) Replace the '":' with '='
            # 2) Delete all '"' from the value 
            # 3) Updating the result in a output file
            echo "$line" | sed 's/":/=/g' | sed 's/"//g' >> $OUTFILE 
            #echo "$line" | sed 's/":/=/g' | sed 's/"//g' | sed 's,\\/,/,g' >> $OUTFILE

        done < $FILENAME
        
        rm -rf $FILENAME #Delete the /opt/DCMresponse.txt
    else
        echo "$FILENAME not found." >> $LOG_PATH/dcmscript.log
        return 1
    fi
}

## Send Http request to the server
sendHttpRequestToServer()
{
    resp=0
    FILENAME=$1
    URL=$2
    #Create json string
if [ "true" != "$RDK_EMULATOR" ]; then
    if [ "$DEVICE_TYPE" == "broadband" ]; then
        JSONSTR='estbMacAddress='$(getErouterMacAddress)'&firmwareVersion='$(getFWVersion)'&env='$(getBuildType)'&model='$(getModel)'&ecmMacAddress='$(getECMMacAddress)'&controllerId='$(getControllerId)'&channelMapId='$(getChannelMapId)'&vodId='$(getVODId)'&timezone='$zoneValue'&partnerId='comcast'&accountId='Unknown'&version=2'
    else
    JSONSTR='estbMacAddress='$(getEstbMacAddress)'&firmwareVersion='$(getFWVersion)'&env='$(getBuildType)'&model='$(getModel)'&ecmMacAddress='$(getECMMacAddress)'&controllerId='$(getControllerId)'&channelMapId='$(getChannelMapId)'&vodId='$(getVODId)
    fi
fi
    #echo JSONSTR: $JSONSTR
    
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/lib:/usr/local/lib
    # Generate curl command
    #CURL_CMD="curl -w '%{http_code}\n' --connect-timeout $timeout -m $timeout -data -o  \"$FILENAME\" $URL?$JSONSTR"
	
	last_char=`echo $URL | awk '$0=$NF' FS=`
	
	 if [ "$last_char" != "?" ]
        then
            URL="$URL?"
        fi
    CURL_CMD="curl -w '%{http_code}\n' --connect-timeout $timeout -m $timeout -o  \"$FILENAME\" '$URL$JSONSTR'"
    echo "`/bin/timestamp` CURL_CMD: $CURL_CMD" >> $LOG_PATH/dcmscript.log

    # Execute curl command
    result= eval $CURL_CMD > $HTTP_CODE

    #echo "Processing $FILENAME"
    sleep $timeout

    # Get the http_code
    http_code=$(awk -F\" '{print $1}' $HTTP_CODE)
    ret=$?
    echo "`/bin/timestamp` ret = $ret http_code: $http_code" >> $LOG_PATH/dcmscript.log

    if [ $ret -ne 0 -o $http_code -ne 200 ] ; then
        echo "`/bin/timestamp` HTTP request failed" >> $LOG_PATH/dcmscript.log
        rm -rf /tmp/DCMSettings.conf
        resp=1
    else
        echo "`/bin/timestamp` HTTP request success. Processing response.." >> $LOG_PATH/dcmscript.log
        # Process the JSON responce
        processJsonResponse
        stat=$?
        echo "`/bin/timestamp` processJsonResponse returned $stat" >> $LOG_PATH/dcmscript.log
        if [ "$stat" != 0 ] ; then
            echo "`/bin/timestamp` Processing response failed." >> $LOG_PATH/dcmscript.log
            rm -rf /tmp/DCMSettings.conf
            resp=1
        else
            resp=0
        fi
    fi
    
    echo "`/bin/timestamp` resp = $resp" >> $LOG_PATH/dcmscript.log
    
    return $resp
}

#---------------------------------
#        Main App
#---------------------------------
loop=1
while [ $loop -eq 1 ]
do
    if [ "true" != "$RDK_EMULATOR" ]; then
	echo "Device Name is not RDK-EMU"
	echo "Device Name = $DEVICE_NAME"
        estbIp=`getIPAddress`
    else
	echo "Device Name is RDK_EMU"
        estbIp=`ifconfig -a eth0 | grep inet | grep -v inet6 | tr -s " " | cut -d ":" -f2 | cut -d " " -f1`
    fi
    if [ ! $estbIp ] ;then
            #echo "waiting for IP ..."
	        echo "`/bin/timestamp` Waiting for IP" >> $LOG_PATH/dcmscript.log
            sleep 15
    else
            ret=1
            if [ "$DEVICE_TYPE" != "mediclient" ] && [ "$estbIp" == "$default_IP" ] ; then
                  ret=0
            fi
            count=0
            while [ $ret -ne 0 ]
            do
                loop=0
                echo "`/bin/timestamp` --------- box got an ip $estbIp" >> $LOG_PATH/dcmscript.log
                #Checking the value of 'checkon_reboot'
                #The value of 'checkon_reboot' will be 0, if the value of 'urn:settings:CheckOnReboot' is false in DCMSettings.conf
                #The value of 'checkon_reboot' will be always 1, if DCMscript.sh is executing from cronjob
                if [ $checkon_reboot -eq 1 ]
                then
                    sendHttpRequestToServer $FILENAME $URL
                    ret=$?
                    echo "`/bin/timestamp` sendHttpRequestToServer returned $ret" >> $LOG_PATH/dcmscript.log
                else
                    ret=0
                    echo "`/bin/timestamp` sendHttpRequestToServer has not executed since the value of 'checkon_reboot' is $checkon_reboot" >> $LOG_PATH/dcmscript.log
                fi                
                #If sendHttpRequestToServer method fails
                if [ $ret -ne 0 ]
                then
                    echo "`/bin/timestamp` Processing response failed." >> $LOG_PATH/dcmscript.log
                    count=$((count + 1))
                    if [ $count -ge $RETRY_COUNT ]
                    then
                        echo " `/bin/timestamp` $RETRY_COUNT tries failed. Giving up..." >> $LOG_PATH/dcmscript.log
                        rm -rf $FILENAME $HTTP_CODE
						
						
                        if [ "$reboot_flag" == "1" ];then
                            echo "Exiting script." >> $LOG_PATH/dcmscript.log
                            exit 0
                        fi      
                        
                        echo " `/bin/timestamp` Executing $RDK_PATH/uploadSTBLogs.sh." >> $LOG_PATH/dcmscript.log
						echo " `/bin/timestamp` TFTP SERVER = $tftp_server" >> $LOG_PATH/dcmscript.log
                        nice sh $RDK_PATH/uploadSTBLogs.sh $tftp_server 1 0 1 $upload_protocol $upload_httplink &
                        exit 1
                    fi
                    echo "`/bin/timestamp` count = $count. Sleeping $RETRY_DELAY seconds ..." >> $LOG_PATH/dcmscript.log
                    rm -rf $FILENAME $HTTP_CODE
                    if [ "$reboot_flag" == "1" ];then
                        echo "Exiting script." >> $LOG_PATH/dcmscript.log
                        echo 0 > $DCMFLAG
                        exit 0
                    fi
                    echo " `/bin/timestamp` Executing $RDK_PATH/uploadSTBLogs.sh." >> $LOG_PATH/dcmscript.log
                    nice sh $RDK_PATH/uploadSTBLogs.sh $tftp_server 1 0 1 $upload_protocol $upload_httplink &
                    echo 0 > $DCMFLAG
                    exit 1
                else
                    rm -rf $HTTP_CODE
                    if [ -f "/tmp/DCMSettings.conf" ]
                    then
                        #---------------------------------------------------------
                        upload_protocol=`cat /tmp/DCMSettings.conf | grep 'LogUploadSettings:UploadRepository:uploadProtocol' | cut -d '=' -f2`
                        						
						if [ -n "$upload_protocol" ]; then
							echo "`/bin/timestamp` upload_protocol: $upload_protocol" >> $LOG_PATH/dcmscript.log
						else
							upload_protocol='TFTP'
							echo "`/bin/timestamp` 'urn:settings:LogUploadSettings:Protocol' is not found in DCMSettings.conf, upload_protocol is TFTP" >> $LOG_PATH/dcmscript.log
						fi
 
 
						
                        #---------------------------------------------------------
                        if [ "$upload_protocol" = "HTTP" ]; then
							upload_httplink=`cat /tmp/DCMSettings.conf | grep 'LogUploadSettings:UploadRepository:URL' | cut -d '=' -f2`
							if [ -z "$upload_httplink" ]; then
								echo "`/bin/timestamp` 'urn:settings:LogUploadSettings:Location' is not found in DCMSettings.conf, upload_httplink is 'None'" >> $LOG_PATH/dcmscript.log
							else
								echo "`/bin/timestamp` upload_httplink is $upload_httplink" >> $LOG_PATH/dcmscript.log
							fi
						fi
                        #---------------------------------------------------------
                        
                        #Check the value of 'UploadOnReboot' in DCMSettings.conf
			if [ "true" != "$RDK_EMULATOR" ]; then
                        uploadCheck=`cat /tmp/DCMSettings.conf | grep 'urn:settings:LogUploadSettings:UploadOnReboot' | cut -d '=' -f2`
			else
			uploadCheck=true
			fi
                        if [ "$uploadCheck" == "true" ] && [ "$reboot_flag" == "0" ]        
                        then
                            # Execute /sysint/uploadSTBLogs.sh with arguments $tftp_server and 1
                            echo "`/bin/timestamp` The value of 'UploadOnReboot' is 'true', executing script uploadSTBLogs.sh" >> $LOG_PATH/dcmscript.log
    			    if [ "true" != "$RDK_EMULATOR" ]; then
                            nice sh $RDK_PATH/uploadSTBLogs.sh $tftp_server 1 1 1 $upload_protocol $upload_httplink &
			    else
                            sh $RDK_PATH/uploadSTBLogs.sh $tftp_server 1 1 1 $upload_protocol $upload_httplink &
			    fi
                        elif [ "$uploadCheck" == "false" ] && [ "$reboot_flag" == "0" ]
                        then
                            # Execute /sysint/uploadSTBLogs.sh with arguments $tftp_server and 1
                            echo "`/bin/timestamp` The value of 'UploadOnReboot' is 'false', executing script uploadSTBLogs.sh" >> $LOG_PATH/dcmscript.log
                            nice sh $RDK_PATH/uploadSTBLogs.sh $tftp_server 1 1 0 $upload_protocol $upload_httplink &
                        fi
                        cron=`cat /tmp/DCMSettings.conf | grep 'urn:settings:LogUploadSettings:UploadSchedule:cron' | cut -d '=' -f2`
                        if [ -n "$cron" ]
                        then
                            # Dump existing cron jobs to a file
                            crontab -l -c /var/spool/cron/ > $current_cron_file
                            # Check whether any cron jobs are existing or not
                            existing_cron_check=`cat $current_cron_file | tail -n 1`
                            
                            tempfile="$PERSISTENT_PATH/tempfile.txt"
                            rm -rf $tempfile  # Delete temp file if existing
                            if [ -n "$existing_cron_check" ]
                            then
                                dcm_cron_check=`grep -c 'uploadSTBLogs.sh' $current_cron_file`
                                if [ $dcm_cron_check -eq 0 ]
                                then
                                    echo "$cron /bin/sh $RDK_PATH/uploadSTBLogs.sh $tftp_server 0 1 0 $upload_protocol $upload_httplink" >> $tempfile
                                fi
                                
                                while read line
                                do
                                    retval=`echo "$line" | grep 'uploadSTBLogs.sh'`
                                    if [ -n "$retval" ]
                                    then
                                        echo "$cron /bin/sh $RDK_PATH/uploadSTBLogs.sh $tftp_server 0 1 0 $upload_protocol $upload_httplink" >> $tempfile
                                    else
                                        echo "$line" >> $tempfile
                                    fi
                                done < $current_cron_file
                            else
                                # If no cron job exists, create one, with the value from DCMSettings.conf file
                                echo "$cron /bin/sh $RDK_PATH/uploadSTBLogs.sh $tftp_server 0 1 0 $upload_protocol $    " >> $tempfile
                            fi
                            # Set new cron job from the file            
                            crontab $tempfile -c /var/spool/cron/
                            rm -rf $current_cron_file # Delete temp file
                            rm -rf $tempfile          # Delete temp file
                        else
                            echo " `/bin/timestamp` Failed to read 'UploadSchedule:cron' from /tmp/DCMSettings.conf." >> $LOG_PATH/dcmscript.log
                        fi

                        cron=`cat /tmp/DCMSettings.conf | grep 'urn:settings:CheckSchedule:cron' | cut -d '=' -f2`
                        if [ -n "$cron" ]
                        then
                            # Dump existing cron jobs to a file
                            crontab -l -c /var/spool/cron/ > $current_cron_file
                            # Check whether any cron jobs are existing or not
                            existing_cron_check=`cat $current_cron_file | tail -n 1`
                            
                            tempfile="$PERSISTENT_PATH/tempfile.txt"
                            rm -rf $tempfile  # Delete temp file if existing
                            if [ -n "$existing_cron_check" ]
                            then
                                schedule_cron_check=`grep -c 'DCMscript.sh' $current_cron_file`
                                if [ $schedule_cron_check -eq 0 ]
                                then
                                    echo "$cron /bin/sh $RDK_PATH/DCMscript.sh $tftp_server $URL $tftp_server 1 1" >> $tempfile
                                fi
                                
                                while read line
                                do
                                    retval=`echo "$line" | grep 'DCMscript.sh'`
                                    if [ -n "$retval" ]
                                    then
                                        echo "$cron /bin/sh $RDK_PATH/DCMscript.sh $tftp_server $URL $tftp_server 1 1" >> $tempfile
                                    else
                                        echo "$line" >> $tempfile
                                    fi
                                done < $current_cron_file
                            else
                                # If no cron job exists, create one, with the value from DCMSettings.conf file
                                echo "$cron /bin/sh $RDK_PATH/DCMscript.sh  $tftp_server $URL $tftp_server 1 1" >> $tempfile
                            fi
                            # Set new cron job from the file
                            crontab $tempfile -c /var/spool/cron/
                            rm -rf $current_cron_file # Delete temp file
                            rm -rf $tempfile          # Delete temp file
                        else
                            echo " `/bin/timestamp` Failed to read 'CheckSchedule:cron' from DCMSettings.conf." >> $LOG_PATH/dcmscript.log
                        fi
                    else
                        echo "`/bin/timestamp` /tmp/DCMSettings.conf file not found." >> $LOG_PATH/dcmscript.log
                    fi
                fi
            done
    fi	
done

