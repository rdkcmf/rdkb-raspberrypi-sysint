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
##    * Check for every reboot
##########################################################################

. /etc/include.properties
. /etc/device.properties
if [ "$DEVICE_TYPE" == "mediaclient" ]; then
    . /etc/common.properties 
    if [ -f $RDK_PATH/utils.sh ]; then
       . $RDK_PATH/utils.sh
    fi
else
    echo "Device type is broadband !!"
    if [ -f $RDK_PATH/commonUtils.sh ];then
       . $RDK_PATH/commonUtils.sh
    fi
    if [ -f $RDK_PATH/snmpUtils.sh ];then
       . $RDK_PATH/snmpUtils.sh
    fi
    if [ -f $RDK_PATH/utils.sh ]; then
       . $RDK_PATH/utils.sh
    fi
fi

mkdir -p /rdklogs/logs

## RETRY DELAY in secs
RETRY_SHORT_DELAY_XCONF=60
RETRY_LONG_DELAY_XCONF=3600
## RETRY COUNT
RETRY_COUNT=3
## RETRY COUNT FOR XCONF
RETRY_COUNT_XCONF=1


## File to save curl/wget response
FILENAME="/rdklogs/logs/response.txt"
## File to save http code and curl progress
HTTP_CODE="/rdklogs/logs/xconf_curl_httpcode"
CURL_PROGRESS="/rdklogs/logs/curl_progress"

## PDRI image filename
pdriFwVerInfo=""

## File containing common firmware download state variables
STATUS_FILE="/rdklogs/logs/fwdnldstatus.txt"

## Flag to disable STATUS_FILE updates in case of PDRI upgrade
disableStatsUpdate="no"


## curl URL and options
ImageDownloadURL=""
serverUrl=""
CLOUD_URL=""

## Status of each upgrade
pci_upgrade_status=1


## Disable Forced HTTPS
DisableForcedHttps=false

#$ TLS values and timeouts
CURLHTTPRet=""
curl_result=1


## Download in progress flags
DOWNLOAD_IN_PROGRESS="Download In Progress"
UPGRADE_IN_PROGRESS="Flashing In Progress"
dnldInProgressFlag="/tmp/.imageDnldInProgress"

CAPABILITIES='&capabilities=RCDL&capabilities=supportsFullHttpUrl'

if [ -z $LOG_PATH ]; then
    LOG_PATH="/rdklogs/logs/"
fi

if [ $# -eq 2 ]; then
    RETRY_COUNT_XCONF=$1                       # Set retry count for XCONF
    if [ $RETRY_COUNT_XCONF -lt 3 ]; then
        RETRY_COUNT_XCONF=3
    fi
    triggerType=$2                            ## Set the Image Upgrade trigger Type
else
    echo "Usage: sh <SCRIPT> <failure retry count> <Image trigger Type>"
    echo "     failure retry count: This value from DCM settings file, if not \"0\""
    echo "     Image  trigger Type : Bootup(1)/scheduled(2)/tr69 or SNMP triggered upgrade(3)/App triggered upgrade(4)"
    exit 0
fi

if [ $triggerType -eq 1 ]; then
    echo "Image Upgrade During Bootup ..!"
elif [ $triggerType -eq 2 ]; then
    echo "Scheduled Image Upgrade using cron ..!"
elif [ $triggerType -eq 3 ]; then # Existing SNMP/TR69 upgrades are triggred with type 3
    echo "TR-69/SNMP triggered Image Upgrade ..!"
elif [ $triggerType -eq 4 ]; then
     echo "App triggered Image Upgrade ..!"
else
     echo "Invalid Upgrade request ..!"
     exit 0
fi

if [ -f $CURL_PROGRESS ]; then
    rm $CURL_PROGRESS
fi



updateUpgradeFlag () {
    if [ "$DEVICE_TYPE" == "mediaclient" ] || [ "$DEVICE_TYPE" == "broadband" ]; then
        flag=$dnldInProgressFlag
    fi    
    
    if [ "$1" == "create" ]; then
        touch $flag        
    elif [ "$1" == "remove" ]; then
        if [ -f $flag ]; then rm $flag; fi
    fi
}


## Function to update Firmware download status in log file /opt/fwdnldstatus.txt
## Args : 1] Protocol 2] Upgrade status 3] Reboot immediately flag 4] Failure Reason
## Args : 5] Download File Version 6] Download File Name
## Args : 7] The latest date and time of last execution
## Args : 8] Firmware Update State
updateFWDownloadStatus()
{
    # Disable the update if PDRI upgrade
    if [ "$disableStatsUpdate" == "yes" ]; then
        return 0
    fi

    TEMP_STATUS="/tmp/.fwdnldstatus.txt"
    proto=$1
    status=$2
    reboot=$3
    failureReason=$4
    DnldVersn=$5
    DnldFile=$6
    LastRun=$7
    fwUpdateState=$8
    numberOfArgs=$#

    if [ "$fwUpdateState" == "" ]; then
        fwUpdateState=`cat $STATUS_FILE | grep FwUpdateState | cut -d '|' -f2`
    fi
    # Check to avoid error in status due error in argument count during logging
    if [ "$numberOfArgs" -ne "8" ]; then
        echo "Error in number of args for logging status in fwdnldstatus.txt"
    fi

    echo "Method|xconf" > $TEMP_STATUS
    echo "Proto|$proto" >> $TEMP_STATUS
    echo "Status|$status" >> $TEMP_STATUS
    echo "Reboot|$reboot" >> $TEMP_STATUS
    echo "FailureReason|$failureReason" >> $TEMP_STATUS
    echo "DnldVersn|$DnldVersn" >> $TEMP_STATUS
    echo "DnldFile|$DnldFile" >> $TEMP_STATUS
    echo "DnldURL|$ImageDownloadURL" >> $TEMP_STATUS
    echo "LastRun|$LastRun" >> $TEMP_STATUS
    echo "FwUpdateState|$fwUpdateState" >> $TEMP_STATUS
    mv $TEMP_STATUS $STATUS_FILE
}



getFWVersion()
{
    versionTag1=$FW_VERSION_TAG1
    versionTag2=$FW_VERSION_TAG2
    verStr=`cat /version.txt | grep ^imagename:$versionTag1`
    if [ $? -eq 0 ]; then
        echo $verStr | cut -d ":" -f 2
    else
        version=`cat /version.txt | grep ^imagename:$versionTag2 | cut -d ":" -f 2`
        echo $version
    fi
}


# identifies whether it is a VBN or PROD build
getBuildType()
{
    str=$(getFWVersion)

    echo $str | grep -q 'VBN'
    if [[ $? -eq 0 ]] ; then
        echo 'vbn'
    else
        echo $str | grep -q 'PROD'
        if [[ $? -eq 0 ]] ; then
            echo 'prod'
        else
            echo $str | grep -q 'QA'
            if [[ $? -eq 0 ]] ; then
                echo 'qa'
            else
                echo 'dev'
            fi
        fi
    fi
}


sendTLSRequest()
{
    CURLHTTPRet=1
    echo "000" > $HTTP_CODE     # provide a default value to avoid possibility of an old value remaining
    if [ "$1" == "XCONF" ]; then
        CURL_CMD="curl -w "%{http_code}" '$CLOUD_URL$JSONSTR'  -o /rdklogs/logs/response.txt >> $HTTP_CODE "
        if [ "$BUILD_TYPE" != "prod" ]; then
           echo URL_CMD: $CURL_CMD
        else 
           echo ADDITIONAL_FW_VER_INFO: $pdriFwVerInfo$remoteInfo
        fi
        result= eval $CURL_CMD > $HTTP_CODE
    fi
    http_code=$(awk -F\" '{print $1}' $HTTP_CODE)
    if [ "$http_code" != "200" ]; then    
      echo "CKP: error from cloud exiting,check in upcoming reboot-------------"
      exit 0               
    else                                                   
      echo "CKP: got no error in curl command!!!!!!!!!!!!!"$http_code
    fi                           

    CURLHTTPRet=$?
    if [ -f $CURL_PROGRESS ]; then
        rm $CURL_PROGRESS
    fi
    echo "Curl return code : $CURLHTTPRet"
}




tftpDownload () {
    echo "Inside tftpdownload !!"
    ret=1
    echo  "`Timestamp` Image download with tftp prtocol"
    echo "tftpupgrade location is :"$UPGRADE_LOCATION 
    echo "tftpupgrade file is :"$UPGRADE_FILE 
    mkdir -p /tmp/tftpimage
    cd /tmp/tftpimage
    echo "set IPtable rules for tftp !!"	
    iptables -t raw -I OUTPUT -j CT -p udp -m udp --dport 69 --helper tftp
    tftp -g  -r $UPGRADE_FILE $UPGRADE_LOCATION
    ret=$?
    if [ $ret -ne 0 ] ; then
        echo " `Timestamp` TFTP image download for file $UPGRADE_FILE failed."
    else
        echo "`Timestamp` $UPGRADE_FILE TFTP Download Completed.!"
    fi
    return $ret
}

httpDownload () {
    echo "Inside httpdownlaod !!"
    ret=1
    echo  "`Timestamp` Image download with http prtocol"
    echo "httpupgrade location is :"$UPGRADE_LOCATION 
    echo "httpupgrade file is :"$UPGRADE_FILE 
    mkdir -p /tmp/httpimage
    cd /tmp/httpimage
    echo "HTTP CURL URL is curl -w %{http_code} '$UPGRADE_LOCATION/$UPGRADE_FILE' -o '$UPGRADE_FILE'"
    eval curl -w %{http_code} '$UPGRADE_LOCATION/$UPGRADE_FILE' -o '$UPGRADE_FILE'
    ret=$?
    if [ $ret -ne 0 ] ; then
        echo " `Timestamp` HTTP image download for file $UPGRADE_FILE failed."
    else
        echo "`Timestamp` $UPGRADE_FILE HTTP Download Completed.!"
    fi
    return $ret
}

## trigger image download to the box
imageDownloadToLocalServer () {
    echo " `Timestamp` Triggering the Image Download ..."
    UPGRADE_LOCATION=$1
    UPGRADE_FILE=$2
    REBOOT_FLAG=$3
    UPGRADE_PROTO=$4
    PDRI_UPGRADE=$5
    echo "`Timestamp` Upgrade Location = $UPGRADE_LOCATION"
    echo "`Timestamp` Upgrade File = $UPGRADE_FILE"
    echo "`Timestamp` Upgrade Reboot Flag = $REBOOT_FLAG"
    echo "`Timestamp` Upgrade protocol = $UPGRADE_PROTO"
    echo "`Timestamp` PDRI Flag  = $PDRI_UPGRADE"

    #Delete already existing files from download folder
    model_num=$(getModel)

    status=$DOWNLOAD_IN_PROGRESS

    updateFWDownloadStatus "$cloudProto" "$status" "$cloudImmediateRebootFlag" "" "$dnldVersion" "$cloudFWFile" "$runtime" "Downloading"
    #if [ $UPGRADE_PROTO -eq 1 ]; then
        #tftpDownload
        #ret=$?
    #fi

    if [ $ret -ne 0 ]; then
        updateUpgradeFlag remove
        failureReason="ESTB Download Failure"
        if [ "$DEVICE_TYPE" == "mediaclient" ] || [ "$DEVICE_TYPE" == "broadband" ]; then
            failureReason="Image Download Failed"
        fi    
        updateFWDownloadStatus "$cloudProto" "Failure" "$cloudImmediateRebootFlag" "$failureReason" "$dnldVersion" "$cloudFWFile" "$runtime" "Failed"
        return $ret
    elif [ -f "$UPGRADE_FILE" ]; then
        echo "`Timestamp` $UPGRADE_FILE Local Image Download Completed using TFTP protocol!"
        if [ "$CPU_ARCH" == "x86" ]; then
            status="Triggered ECM download"
        elif [ "$DEVICE_TYPE" == "mediaclient" ] || [ "$DEVICE_TYPE" == "broadband" ]; then
            status=$UPGRADE_IN_PROGRESS
        fi
        updateFWDownloadStatus "$cloudProto" "$status" "$cloudImmediateRebootFlag" "" "$dnldVersion" "$cloudFWFile" "$runtime" "Download complete"
        filesize=`ls -l $UPGRADE_FILE |  awk '{ print $5}'`
        echo "`Timestamp` Downloaded $UPGRADE_FILE of size $filesize"
    fi    
    return $ret
}


invokeImageFlasher () {
    echo " `Timestamp` Starting Image Flashing ..."
    ret=0
    UPGRADE_SERVER=$1
    UPGRADE_FILE=$2
    REBOOT_FLAG=$3
    UPGRADE_PROTO=$4
    PDRI_UPGRADE=$5
    echo "`Timestamp` Upgrade Server = $UPGRADE_SERVER "
    echo "`Timestamp` Upgrade File = $UPGRADE_FILE "
    echo "`Timestamp` Reboot Flag = $REBOOT_FLAG "
    echo "`Timestamp` Upgrade protocol = $UPGRADE_PROTO "
    echo "`Timestamp` PDRI Upgrade = $PDRI_UPGRADE "



    if [ -f /lib/rdk/imageFlasher.sh ];then
        /lib/rdk/imageFlasher.sh $UPGRADE_PROTO $UPGRADE_SERVER $DIFW_PATH $UPGRADE_FILE $REBOOT_FLAG $PDRI_UPGRADE
        ret=$?
    else
        echo "imageFlasher.sh is missing"
    fi

    if [ $ret -ne 0 ]; then
        echo "`Timestamp` Image Flashing failed"
    elif [ "$DEVICE_TYPE" == "mediaclient" ] || [ "$DEVICE_TYPE" == "broadband" ]; then
        echo "`Timestamp` Image Flashing is success"
    fi
    return $ret
}     

## get Server URL
getServURL()
{
    buildType=$(getBuildType)
    CLOUD_URL=$CLOUDURL
    if [ -f $PERSISTENT_PATH/swupdate.conf ] && [ $buildType != "prod" ] ; then
        urlString=`grep -v '^[[:space:]]*#' $PERSISTENT_PATH/swupdate.conf`
        CLOUD_URL=$urlString
    else
        case $buildType in
        "prod" )
	    CLOUD_URL=$CLOUDURL;;
        "vbn" )
            CLOUD_URL=$CLOUDURL;;
        "qa" )
            # QA server URL
            CLOUD_URL=$CLOUDURL;;
        * )
            CLOUD_URL=$CLOUDURL;;
        esac
    fi
    echo $CLOUD_URL
}


triggerPCIUpgrade () {
    if [ "$cloudProto" = "http" ] ; then
        protocol=2
    else
        protocol=1
    fi

    resp=1
    updateUpgradeFlag "create"
    #below code commented and can use for basic flashing during development
    #imageDownloadToLocalServer $cloudFWLocation $cloudFWFile $rebootFlag $protocol
    #resp=$?
    #echo "CKP:------iamge dow to loca se resp---------"$resp
     
    #if [ $resp -eq 0 ];then
         echo "cloudFWLocation"$cloudFWLocation
         echo "cloudfile :"$cloudFWFile
         echo "protocol"$protocol
         
         invokeImageFlasher $cloudFWLocation $cloudFWFile $rebootFlag $protocol
         resp=$?
    #fi  
     
    echo "`Timestamp` upgrade method returned $resp"
    if [ $resp != 0 ] ; then
        echo "`Timestamp` doCDL failed"   
        ret=1
    else
        echo "`Timestamp` doCDL success."
        ret=0
    fi
    return $ret
}

checkForValidPCIUpgrade () {
    upgrade=0
    echo "Xconf image Check"
    rebootFlag=1
    if [ "$cloudImmediateRebootFlag" = "false" ]; then
        rebootFlag=0
    fi

    if [ $triggerType -eq 1 ] ; then
            if [ "$myFWVersion" != "$cloudFWVersion" ]; then
                echo "Firmware versions are different myFWVersion : $myFWVersion cloudFWVersion : $cloudFWVersion"
                upgrade=1
                pci_upgrade=1
            fi
    else
        echo "`Timestamp` FW version of the active image and the image to be upgraded are the same. No upgrade required."
        updateFWDownloadStatus "$cloudProto" "No upgrade needed" "$cloudImmediateRebootFlag" "Versions Match" "$dnldVersion" "$cloudFWFile" "$runtime" "Failed"
        updateUpgradeFlag "remove"
    fi
}

checkForUpgrades () {
    ret=0
    # PCI Upgrades
    pci_upgrade=0
    if [ $pci_upgrade_status -ne 0 ]; then
        pci_upgrade_status=0  
        if [[ ! -n "$cloudFWVersion" ]] ; then
            echo "`Timestamp` cloudFWVersion is empty. Do Nothing"
            updateFWDownloadStatus "$cloudProto" "Failure" "$cloudImmediateRebootFlag" "Cloud FW Version is empty" "$dnldVersion" "$cloudFWFile" "$runtime" "Failed"
        else
            checkForValidPCIUpgrade
            if [ $pci_upgrade -eq 1 ]; then
                triggerPCIUpgrade
                pci_upgrade_status=$?
            fi
        fi
    fi

   
    if [ $pci_upgrade_status -ne 0 ]; then   
        ret=1
    fi
    return $ret
}

processJsonResponse()
{
    FILENAME=$1
    OUTPUT="$PERSISTENT_PATH/output.txt"
    OUTPUT1=`cat $FILENAME | tr -d '\n' | sed 's/[{}]//g' | awk  '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' | sed 's/\"\:\"/\|/g' | sed -r 's/\"\:(true)($)/\|true/gI' | sed -r 's/\"\:(false)($)/\|false/gI' | sed -r 's/\"\:(null)($)/\|\1/gI' | sed -r 's/\"\:([0-9]+)($)/\|\1/g' | sed 's/[\,]/ /g' | sed 's/\"//g' > $OUTPUT`
    echo OUTPUT1 : $OUTPUT1

    cloudFWFile=`grep firmwareFilename $OUTPUT | cut -d \| -f2`
    cloudFWLocation=`grep firmwareLocation $OUTPUT | cut -d \| -f2 | tr -d ' '`
    echo "$cloudFWLocation" > /tmp/.xconfssrdownloadurl
    ipv4cloudFWLocation=$cloudFWLocation
    ipv6cloudFWLocation=`grep ipv6FirmwareLocation  $OUTPUT | cut -d \| -f2 | tr -d ' '`
    cloudFWVersion=`grep firmwareVersion $OUTPUT | cut -d \| -f2`
    cloudUpGrDelay=`grep upgradeDelay $OUTPUT | cut -d \| -f2`
    cloudProto=`grep firmwareDownloadProtocol $OUTPUT | cut -d \| -f2`          # Get download protocol to be used
    cloudImmediateRebootFlag=`grep rebootImmediately $OUTPUT | cut -d \| -f2`    # immediate reboot flag
    peripheralFirmwares=`grep remCtrl $OUTPUT | cut -d "|" -f2 | tr '\n' ','`    # peripheral firmwares

    echo "`Timestamp` cloudFWFile: $cloudFWFile"
    echo "`Timestamp` cloudFWLocation: $cloudFWLocation"
    echo "`Timestamp` cloudFWVersion: $cloudFWVersion"
    echo "`Timestamp` cloudProto: $cloudProto"
    echo "`Timestamp` cloudImmediateRebootFlag: $cloudImmediateRebootFlag"

    cloudfile_model=`echo $cloudFWFile | cut -d '_' -f1`

    myFWVersion=$(getFWVersion)
    currentVersion=$myFWVersion
    myFWVersion=`echo $myFWVersion | tr '[A-Z]' '[a-z]'`
    dnldVersion=$cloudFWVersion
    cloudFWVersion=`echo $cloudFWVersion | tr '[A-Z]' '[a-z]'`
    dnldFile=`echo $cloudFWFile | tr '[A-Z]' '[a-z]'`
    echo "`Timestamp` myFWVersion = $myFWVersion"
    echo "`Timestamp` myFWFile = $myFWFile"
    echo "`Timestamp` lastDnldFile: $lastDnldFile"
    echo "`Timestamp` cloudFWVersion: $cloudFWVersion"
    echo "`Timestamp` cloudFWFile: $dnldFile"

    checkForUpgrades    
    return $?
}

exitForXconf404response () {
    echo "`Timestamp` Received HTTP 404 Response from Xconf Server. Retry logic not needed"
    echo "`Timestamp` Exiting from Image Upgrade process..!"
    updateFWDownloadStatus "" "Failure" "" "Invalid Request" "" "" "$runtime" "Failed"
    rm -f $FILENAME $HTTP_CODE
    exit 0
}


createJsonString () {
        
   if [ "$DEVICE_TYPE" == "hybrid" ] || [ "$DEVICE_TYPE" == "mediaclient" ] ; then
     estbMac=`ifconfig eth0 | grep HWaddr | cut -c39-55`
   elif [ "$DEVICE_TYPE" == "broadband" ]; then     
     estbMac=`ifconfig erouter0 | grep HWaddr | cut -c39-55`
   fi
   #Included additionalFwVerInfo and partnerId
   #JSONSTR=$estbMac
   JSONSTR=''$estbMac'&model='$(getModel)''$CAPABILITIES''
   echo "Mac in jsonstr:"$JSONSTR
}
sendXCONFTLSRequest () {

    ret=1
    xconfRetryCount=0
    http_code="000"
    while [ "$http_code" = "000" -a $xconfRetryCount -ne 10 ]
    do
        echo "Trying to communicate with XCONF server"
        if [ $xconfRetryCount -ne 0 ]; then sleep 60; fi

        sendTLSRequest "XCONF"
        curl_result=$CURLHTTPRet
        if [ $curl_result -ne 0 ]; then
            updateFWDownloadStatus "" "Failure" "" "Network Communication Error" "" "" "$runtime" ""
        fi
        http_code=$(awk -F\" '{print $1}' $HTTP_CODE)
        ret=$?
        echo "ret = $curl_result, http_code: $http_code for XCONF communication"
        xconfRetryCount=`expr $xconfRetryCount + 1`
    done
    return $curl_result
}


sendXCONFRequest() {
        sendXCONFTLSRequest
        ret=$?
        curl_result=$CURLHTTPRet
        return $curl_result
}

sendJsonRequestToCloud()
{
    resp=0
    FILENAME=$1
    JSONSTR=""
    createJsonString
    echo "`Timestamp` JSONSTR: $JSONSTR"
    runtime=`date -u +%F' '%T`    
    CLOUD_URL=$(getServURL)
    sendXCONFRequest 
    ret=$?    

    resp=1
    if [ $ret -ne 0 ] ; then
        echo "`Timestamp` HTTP request failed"
        if [ $curl_result -eq 0 ]; then
            updateFWDownloadStatus "" "Failure" "" "Invalid Request" "" "" "$runtime" "Failed"
        fi
    else
        echo "`Timestamp` HTTP request success. Processing response.."
        processJsonResponse "/rdklogs/logs/response.txt"
        resp=$?
        echo "`Timestamp` processJsonResponse returned $resp"
        if [ $resp -ne 0 ] ; then
            echo "`Timestamp` processing response failed"    
        fi
    fi
    return $resp    
} 

echo "Main APP of devinitFWDNLD---"
### main app
# current FW version from version
echo "`Timestamp` version = $(getFWVersion)"
echo "`Timestamp` buildtype = $(getBuildType)"
# Send query to the cloud - retry 3 times in case of failure
ret=1
retryCount=0
retryDelay=$RETRY_SHORT_DELAY_XCONF
LONG_RETRY_COUNT_XCONF=6
while [ $ret -ne 0 ]
do
    sendJsonRequestToCloud $FILENAME
    ret=$?
    echo "`Timestamp` sendJsonRequestToCloud returned $ret"
    if [ $ret != 0 ] ; then
        echo "`Timestamp` request failed"
        if [ $retryCount -eq $RETRY_COUNT_XCONF ] ; then
            retryDelay=$RETRY_LONG_DELAY_XCONF
        elif [ $retryCount -ge $LONG_RETRY_COUNT_XCONF ]; then
            echo "`Timestamp` Giving up..."
            rm -f $FILENAME $HTTP_CODE
            exit 1
        fi
        echo "`Timestamp` retryCount = $retryCount. Sleeping $retryDelay seconds ..."
        rm -f $FILENAME $HTTP_CODE
        sleep $retryDelay
        retryCount=$((retryCount + 1))
    else
        rm -f $FILENAME $HTTP_CODE
        echo "success"
    fi
done
