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
#

. /etc/include.properties
. /etc/device.properties

. $RDK_PATH/logfiles.sh

if [ ! "$LOG_PATH" ];then LOG_PATH="/opt/logs"; fi
# create log workspace if not there
if [ ! -d "$LOG_PATH" ];then 
     rm -rf $LOG_PATH
     mkdir -p "$LOG_PATH"
fi
# create intermediate log workspace if not there
if [ ! -d $LOG_PATH/PreviousLogs ];then
     rm -rf $LOG_PATH/PreviousLogs
     mkdir -p $LOG_PATH/PreviousLogs
fi
# create log backup workspace if not there
if [ ! -d $LOG_PATH/PreviousLogs_backup ];then
     rm  -rf $LOG_PATH/PreviousLogs_backup
     mkdir -p $LOG_PATH/PreviousLogs_backup
else
     rm  -rf $LOG_PATH/PreviousLogs_backup/*
fi

if [ $APP_PERSISTENT_PATH ];then 
     PERSISTENT_PATH=$APP_PERSISTENT_PATH
else
    PERSISTENT_PATH=/opt/persistent
fi
touch $PERSISTENT_PATH/logFileBackup

PREV_LOG_PATH="$LOG_PATH/PreviousLogs"

# disk size check for recovery if /opt size > 90%
if [ -f /etc/os-release ] && [ -f /lib/rdk/disk_threshold_check.sh ];then
     sh /lib/rdk/disk_threshold_check.sh 0
fi

backupAndRecoverLogs()
{
    source=$1
    destn=$2
    operation=$3
    s_extn=$4
    d_extn=$5
    if [ -f $source/$s_extn$riLog ] ; then $operation $source/$s_extn$riLog $destn/$d_extn$riLog; fi
    if [ -f $source/$s_extn$xreLog ] ; then $operation $source/$s_extn$xreLog $destn/$d_extn$xreLog; fi
    if [ -f $source/$s_extn$cecLog ] ; then $operation $source/$s_extn$cecLog $destn/$d_extn$cecLog; fi
    if [ -f $source/$s_extn$wbLog ] ; then $operation $source/$s_extn$wbLog $destn/$d_extn$wbLog; fi
    if [ -f $source/$s_extn$webpavideoLog ]; then $operation $source/$s_extn$webpavideoLog $destn/$d_extn$webpavideoLog; fi
    if [ -f $source/$s_extn$fogLog ]; then $operation $source/$s_extn$fogLog $destn/$d_extn$fogLog; fi
    if [ -f $source/$s_extn$sysLog ] ; then $operation $source/$s_extn$sysLog $destn/$d_extn$sysLog; fi
    if [ -f $source/$s_extn$uiLog ] ; then $operation $source/$s_extn$uiLog $destn/$d_extn$uiLog; fi
    if [ -f $source/$s_extn$storagemgrLog ] ; then $operation $source/$s_extn$storagemgrLog $destn/$d_extn$storagemgrLog; fi
    if [ -f $source/$s_extn$applicationsLog ] ; then $operation $source/$s_extn$applicationsLog $destn/$d_extn$applicationsLog; fi
    if [ -f $source/$s_extn$systemLog ] ; then $operation $source/$s_extn$systemLog $destn/$d_extn$systemLog; fi
    if [ -f $source/$s_extn$bootUpLog ] ; then $operation $source/$s_extn$bootUpLog $destn/$d_extn$bootUpLog; fi
    if [ -f $source/$s_extn$startupDmesgLog ] ; then $operation $source/$s_extn$startupDmesgLog $destn/$d_extn$startupDmesgLog; fi
    if [ -f $source/$s_extn$ecmLog ]; then $operation $source/$s_extn$ecmLog $destn/$d_extn$ecmLog; fi
    if [ -f $source/$s_extn$vodLog ]; then $operation $source/$s_extn$vodLog $destn/$d_extn$vodLog; fi
    if [ -f $source/$s_extn$mfrLog ]; then $operation $source/$s_extn$mfrLog $destn/$d_extn$mfrLog; fi
    if [ -f $source/$s_extn$rebootLog ]; then $operation $source/$s_extn$rebootLog $destn/$d_extn$rebootLog; fi
    if [ -f $source/$s_extn$rebootInfoLog ]; then $operation $source/$s_extn$rebootInfoLog $destn/$d_extn$rebootInfoLog; fi
    if [ -f $source/$s_extn$diskCleanupLog1 ]; then $operation $source/$s_extn$diskCleanupLog1 $destn/$d_extn$diskCleanupLog1; fi
    if [ -f $source/$s_extn$topLog ]; then $operation $source/$s_extn$topLog $destn/$d_extn$topLog; fi
    if [ -f $source/$s_extn$coreDumpLog ]; then $operation $source/$s_extn$coreDumpLog $destn/$d_extn$coreDumpLog; fi
    if [ -f $source/$s_extn$sysDmesgLog ]; then $operation $source/$s_extn$sysDmesgLog $destn/$d_extn$sysDmesgLog; fi
    if [ -f $source/$s_extn$samhainLog ]; then $operation $source/$s_extn$samhainLog $destn/$d_extn$samhainLog; fi
    if [ -f $source/$s_extn$hddStatusLog ]; then $operation $source/$s_extn$hddStatusLog $destn/$d_extn$hddStatusLog; fi
    if [ -f $source/$s_extn$adobeCleanupLog ]; then $operation $source/$s_extn$adobeCleanupLog $destn/$d_extn$adobeCleanupLog; fi
    if [ -f $source/$s_extn$xiConnectionStatusLog ]; then $operation $source/$s_extn$xiConnectionStatusLog $destn/$d_extn$xiConnectionStatusLog; fi
    if [ -f $source/$s_extn$dropbearLog ]; then $operation $source/$s_extn$dropbearLog $destn/$d_extn$dropbearLog; fi
    if [ -f $source/$s_extn$bluetoothLog ]; then $operation $source/$s_extn$bluetoothLog $destn/$d_extn$bluetoothLog; fi
    if [ -f $source/$s_extn$easPcapFile ]; then $operation $source/$s_extn$easPcapFile $destn/$d_extn$easPcapFile; fi
    if [ -f $source/$s_extn$mocaPcapFile ]; then $operation $source/$s_extn$mocaPcapFile $destn/$d_extn$mocaPcapFile; fi
    if [ -f $source/$s_extn$mountLog ]; then $operation $source/$s_extn$mountLog $destn/$d_extn$mountLog; fi
    if [ -f $source/$s_extn$rbiDaemonLog ]; then $operation $source/$s_extn$rbiDaemonLog $destn/$d_extn$rbiDaemonLog; fi
    if [ -f $source/$s_extn$rfcLog ]; then $operation $source/$s_extn$rfcLog $destn/$d_extn$rfcLog; fi
    if [ -f $source/$s_extn$tlsLog ]; then $operation $source/$s_extn$tlsLog $destn/$d_extn$tlsLog; fi
    if [ -f $source/$s_extn$playreadycdmiLog ]; then $operation $source/$s_extn$playreadycdmiLog $destn/$d_extn$playreadycdmiLog; fi
    if [ -f $source/$s_extn$wpecdmiLog ]; then $operation $source/$s_extn$wpecdmiLog $destn/$d_extn$wpecdmiLog; fi
    if [ -f $source/$s_extn$pingTelemetryLog ]; then $operation $source/$s_extn$pingTelemetryLog $destn/$d_extn$pingTelemetryLog; fi
    if [ -f $source/$s_extn$dnsmasqLog ]; then $operation $source/$s_extn$dnsmasqLog $destn/$d_extn$dnsmasqLog; fi
    if [ -f $source/$s_extn$xDiscoveryLog ]; then $operation $source/$s_extn$xDiscoveryLog $destn/$d_extn$xDiscoveryLog; fi
    if [ -f $source/$s_extn$trmLog ]; then $operation $source/$s_extn$trmLog $destn/$d_extn$trmLog; fi
    if [ -f $source/$s_extn$authServiceLog ]; then $operation $source/$s_extn$authServiceLog $destn/$d_extn$authServiceLog; fi
    if [ -f $source/$s_extn$ctrlmLog ]; then $operation $source/$s_extn$ctrlmLog $destn/$d_extn$ctrlmLog; fi
    if [ -f $source/$s_extn$dcmLog ]; then $operation $source/$s_extn$dcmLog $destn/$d_extn$dcmLog; fi
    if [ -f $source/$s_extn$netsrvLog ]; then $operation $source/$s_extn$netsrvLog $destn/$d_extn$netsrvLog; fi
    if [ -f $source/$s_extn$swUpdateLog ]; then $operation $source/$s_extn$swUpdateLog $destn/$d_extn$swUpdateLog; fi

    if [ -f $source/$s_extn$deviceDetailsLog ]; then $operation $source/$s_extn$tlsLog $destn/$d_extn$deviceDetailsLog; fi
    if [ -f $source/$s_extn$zramLog ]; then $operation $source/$s_extn$zramLog $destn/$d_extn$zramLog; fi
    if [ -f $source/$s_extn$appmanagerLog]; then $operation $source/$s_extn$appmanagerLog $destn/$d_extn$appmanagerLog; fi
    if [ -f $source/$s_extn$nlmonLog ]; then $operation $source/$s_extn$nlmonLog $destn/$d_extn$nlmonLog; fi
    if [ -f $source/$s_extn$hwselfLog ]; then $operation $source/$s_extn$hwselfLog $destn/$d_extn$hwselfLog; fi
    if [ "$CONTAINER_SUPPORT" == "true" ];then
        if [ -f $source/$s_extn$xreLxcLog ] ; then $operation $source/$s_extn$xreLxcLog $destn/$d_extn$xreLxcLog; fi
        if [ -f $source/$s_extn$xreLxcApplicationsLog ] ; then $operation $source/$s_extn$xreLxcApplicationsLog $destn/$d_extn$xreLxcApplicationsLog; fi
    fi


    if [ "$DEVICE_TYPE" != "mediaclient" ]; then
        if [ -f $source/$s_extn$snmpdLog ]; then $operation $source/$s_extn$snmpdLog $destn/$d_extn$snmpdLog; fi
        if [ -f $source/$s_extn$upstreamStatsLog ]; then $operation $source/$s_extn$upstreamStatsLog $destn/$d_extn$upstreamStatsLog; fi
        if [ -f $source/$s_extn$dibblerLog ]; then $operation $source/$s_extn$dibblerLog $destn/$d_extn$dibblerLog; fi
    else
        if [ -f $source/$s_extn$gatewayLog ]; then $operation $source/$s_extn$gatewayLog $destn/$d_extn$gatewayLog; fi
        if [ -f $source/$s_extn$ipSetupLog ]; then $operation $source/$s_extn$ipSetupLog $destn/$d_extn$ipSetupLog; fi
    fi
    if [ "$DEVICE_TYPE" ==  "XHC1" ];then
       if [ -f $source/$s_extn$streamsrvLog ] ; then $operation $source/$s_extn$streamsrvLog $destn/$d_extn$streamsrvLog; fi
       if [ -f $source/$s_extn$stunnelHttpsLog ] ; then $operation $source/$s_extn$stunnelHttpsLog $destn/$d_extn$stunnelHttpsLog; fi
       if [ -f $source/$s_extn$upnpLog ] ; then $operation $source/$s_extn$upnpLog $destn/$d_extn$upnpLog; fi
       if [ -f $source/$s_extn$upnpigdLog ] ; then $operation $source/$s_extn$upnpigdLog $destn/$d_extn$upnpigdLog; fi
       if [ -f $source/$s_extn$cgiLog ] ; then $operation $source/$s_extn$cgiLog $destn/$d_extn$cgiLog; fi
       if [ -f $source/$s_extn$systemLog ] ; then $operation $source/$s_extn$systemLog $destn/$d_extn$systemLog; fi
       if [ -f $source/$s_extn$eventLog ] ; then $operation $source/$s_extn$eventLog $destn/$d_extn$eventLog; fi
       if [ -f $source/$s_extn$xw3MonitorLog ] ; then $operation $source/$s_extn$xw3MonitorLog $destn/$d_extn$xw3MonitorLog; fi
       if [ -f $source/$s_extn$sensorDLog ] ; then $operation $source/$s_extn$sensorDLog $destn/$d_extn$sensorDLog; fi
       if [ -f $source/$s_extn$webpaLog ] ; then $operation $source/$s_extn$webpaLog $destn/$d_extn$webpaLog; fi
       if [ -f $source/$s_extn$userLog ] ; then $operation $source/$s_extn$userLog $destn/$d_extn$userLog; fi
       if [ -f $source/$s_extn$webrtcStreamingLog ] ; then $operation $source/$s_extn$webrtcStreamingLog $destn/$d_extn$webrtcStreamingLog; fi
       if [ -f $source/$s_extn$cvrPollLog ] ; then $operation $source/$s_extn$cvrPollLog $destn/$d_extn$cvrPollLog; fi
       if [ -f $source/$s_extn$ivaDaemonLog ] ; then $operation $source/$s_extn$ivaDaemonLog $destn/$d_extn$ivaDaemonLog; fi
       if [ -f $source/$s_extn$thumbnailUploadLog ] ; then $operation $source/$s_extn$thumbnailUploadLog $destn/$d_extn$thumbnailUploadLog; fi
       if [ -f $source/$s_extn$metricsLog ] ; then $operation $source/$s_extn$metricsLog $destn/$d_extn$metricsLog; fi
       if [ -f $source/$s_extn$wifiLog ] ; then $operation $source/$s_extn$wifiLog $destn/$d_extn$wifiLog; fi
       if [ -f $source/$s_extn$overlayLog ] ; then $operation $source/$s_extn$overlayLog $destn/$d_extn$overlayLog; fi
       if [ -f $source/$s_extn$xvisionLog ] ; then $operation $source/$s_extn$xvisionLog $destn/$d_extn$xvisionLog; fi
       if [ -f $source/$s_extn$evoLog ] ; then $operation $source/$s_extn$evoLog $destn/$d_extn$evoLog; fi
       if [ -f $source/$s_extn$camstreamsrvLog ] ; then $operation $source/$s_extn$camstreamsrvLog $destn/$d_extn$camstreamsrvLog; fi
       if [ -f $source/$s_extn$mongsLog ] ; then $operation $source/$s_extn$mongsLog $destn/$d_extn$mongsLog; fi
    fi
    if [ "$WIFI_SUPPORT" == "true" ];then
        if [ -f $source/$s_extn$wpaSupplicantLog ]; then $operation $source/$s_extn$wpaSupplicantLog $destn/$d_extn$wpaSupplicantLog; fi
        if [ -f $source/$s_extn$dhcpWifiLog ]; then $operation $source/$s_extn$dhcpWifiLog $destn/$d_extn$dhcpWifiLog; fi
    fi
    if [ -f $source/$audiocapturemgrLogs ] ; then $operation $source/$audiocapturemgrLogs $destn; fi

}

# Backup logs not there in backup list for one time
# Backup the logs to /opt/logs/.trashLogs
# Persist the content for one cycle and then cleanup on next backup
backupLogsNotInList()
{
    LOG_TRASH_PATH=$LOG_PATH/.trashLogs
    if [ ! -d $LOG_TRASH_PATH ];then
          mkdir -p $LOG_TRASH_PATH
    else
          rm -rf $LOG_TRASH_PATH/*
    fi
    ret=`ls $LOG_PATH/*.txt | wc -l`
    if [ $ret -gt 0 ];then mv $LOG_PATH/*.txt $LOG_TRASH_PATH/ ; fi
    ret=`ls $LOG_PATH/*.txt.* | wc -l`
    if [ $ret -gt 0 ];then mv $LOG_PATH/*.txt.* $LOG_TRASH_PATH/ ; fi
    ret=`ls $LOG_PATH/*.log | wc -l`
    if [ $ret -gt 0 ];then mv $LOG_PATH/*.log $LOG_TRASH_PATH/ ; fi
    ret=`ls $LOG_PATH/*.log.* | wc -l`
    if [ $ret -gt 0 ];then mv $LOG_PATH/*.log.* $LOG_TRASH_PATH/ ; fi
}

last_bootfile=`find $LOG_PATH/PreviousLogs/ -name last_reboot`
if [ -f "$last_bootfile" ];then
     rm -rf $last_bootfile
fi

if [ "$HDD_ENABLED" = "false" ]; then
	BAK1="bak1_"
	BAK2="bak2_"
	BAK3="bak3_"
    if [ ! `ls $PREV_LOG_PATH/$sysLog` ]; then
        backup "$LOG_PATH/" "$PREV_LOG_PATH/" mv 
        backupSystemLogFiles mv $LOG_PATH $PREV_LOG_PATH
        backupAppBackupLogFiles mv $LOG_PATH $PREV_LOG_PATH
    elif [ ! `ls $PREV_LOG_PATH/$sysLogBAK1` ]; then
        # box reboot within 8 minutes after reboot
        backupAndRecoverLogs "$LOG_PATH/" "$PREV_LOG_PATH/" mv "" $BAK1
    elif [ ! `ls $PREV_LOG_PATH/$sysLogBAK2` ]; then
        # box reboot within 8 minutes after reboot
        backupAndRecoverLogs "$LOG_PATH/" "$PREV_LOG_PATH/" mv "" $BAK2
    elif [ ! `ls $PREV_LOG_PATH/$sysLogBAK3` ]; then
        # box reboot within 8 minutes after reboot
        backupAndRecoverLogs "$LOG_PATH/" "$PREV_LOG_PATH/" mv "" $BAK3
    else
        # box reboot within 8 minutes after reboot
        backupAndRecoverLogs "$PREV_LOG_PATH/" "$PREV_LOG_PATH/" mv "$BAK1" ""
        backupAndRecoverLogs "$PREV_LOG_PATH/" "$PREV_LOG_PATH/" mv "$BAK2" "$BAK1"
        backupAndRecoverLogs "$PREV_LOG_PATH/" "$PREV_LOG_PATH/" mv "$BAK3" "$BAK2"
        backupAndRecoverLogs "$LOG_PATH/" "$PREV_LOG_PATH/" mv "" "$BAK3"
    fi
    if [ -f /etc/os-release ];then
           /bin/touch $LOG_PATH/PreviousLogs/last_reboot
    else
           touch $LOG_PATH/PreviousLogs/last_reboot
    fi
else
    if [ ! `ls $PREV_LOG_PATH/$sysLog` ]; then
       backupSystemLogFiles mv $LOG_PATH $PREV_LOG_PATH
       backupAppBackupLogFiles mv $LOG_PATH $PREV_LOG_PATH
       crashLogsBackup mv $LOG_PATH $PREV_LOG_PATH
       backupLogsNotInList
       if [ -f /etc/os-release ];then
           /bin/touch $LOG_PATH/PreviousLogs/last_reboot
       else
           touch $LOG_PATH/PreviousLogs/last_reboot
       fi
    else
       find $LOG_PATH/PreviousLogs/ -name last_reboot | xargs rm >/dev/null
       timestamp=`date "+%m-%d-%y-%I-%M-%S%p"`
       LogFilePathPerm="$LOG_PATH/PreviousLogs/logbackup-$timestamp"
       mkdir -p $LogFilePathPerm

       backup "$LOG_PATH/" "$LogFilePathPerm" mv
       backupSystemLogFiles mv $LOG_PATH $LogFilePathPerm
       backupAppBackupLogFiles mv $LOG_PATH $LogFilePathPerm
       crashLogsBackup mv "$LOG_PATH/" "$LogFilePathPerm"
       if [ -f /etc/os-release ];then
            /bin/touch "$LogFilePathPerm"/last_reboot 
       else
            touch $LogFilePathPerm/last_reboot
       fi
   fi
fi
if [ -f /tmp/disk_cleanup.log ];then
        mv /tmp/disk_cleanup.log $LOG_PATH
fi
if [ -f /tmp/mount_log.txt ];then
        mv /tmp/mount_log.txt $LOG_PATH
fi

cp /version.txt $LOG_PATH

if [ -f /etc/os-release ];then
    /bin/systemd-notify --ready --status="Logs Backup Done..!"
fi


