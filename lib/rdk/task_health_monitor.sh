#!/bin/sh
#######################################################################################
# If not stated otherwise in this file or this component's Licenses.txt file the
# following copyright and licenses apply:

#  Copyright 2019 RDK Management

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

# http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#######################################################################################

UTOPIA_PATH="/etc/utopia/service.d"
TAD_PATH="/usr/ccsp/tad"
RDKLOGGER_PATH="/rdklogger"
PRIVATE_LAN="brlan0"
source $TAD_PATH/corrective_action.sh

# use SELFHEAL_TYPE to handle various code paths below (BOX_TYPE is set in device.properties)
case $BOX_TYPE in
    "XB3") SELFHEAL_TYPE="BASE";;
    "XB6") SELFHEAL_TYPE="SYSTEMD";;
    "XB7") SELFHEAL_TYPE="SYSTEMD";;
    "XF3") SELFHEAL_TYPE="SYSTEMD";;
    "TCCBR") SELFHEAL_TYPE="TCCBR";;
    "CFG3") SELFHEAL_TYPE="BASE";;  # TBD?!
    "pi"|"rpi") SELFHEAL_TYPE="BASE";;  # TBD?!
    "HUB4") SELFHEAL_TYPE="SYSTEMD";;
    *)
        echo_t "RDKB_SELFHEAL : ERROR: Unknown BOX_TYPE '$BOX_TYPE', using SELFHEAL_TYPE='BASE'"
        SELFHEAL_TYPE="BASE";;
esac

case $SELFHEAL_TYPE in
    "BASE")
        grePrefix="gretap0"
        brlanPrefix="brlan"
        l2sd0Prefix="l2sd0"
        #(already done by corrective_action.sh)source /etc/log_timestamp.sh
	if [ "$BOX_TYPE" != "rpi" ]; then
        if [ -f /etc/mount-utils/getConfigFile.sh ];then
            . /etc/mount-utils/getConfigFile.sh
        fi

        if [[ "$MODEL_NUM" = "DPC3939" || "$MODEL_NUM" = "DPC3941" ]]; then
            ADVSEC_PATH="/tmp/cujo_dnld/usr/ccsp/advsec/usr/libexec/advsec.sh"
        else
            ADVSEC_PATH="/usr/ccsp/advsec/usr/libexec/advsec.sh"
        fi
	fi
    ;;
    "TCCBR")
    ;;
    "SYSTEMD")
        ADVSEC_PATH="/usr/ccsp/advsec/usr/libexec/advsec.sh"
    ;;
esac

ping_failed=0
ping_success=0
SyseventdCrashed="/rdklogs/syseventd_crashed"
PARCONNHEALTH_PATH="/tmp/parconnhealth.txt"
PING_PATH="/usr/sbin"

case $SELFHEAL_TYPE in
    "BASE")
        SNMPMASTERCRASHED="/tmp/snmp_cm_crashed"
        WAN_INTERFACE="erouter0"
        PEER_COMM_ID="/tmp/elxrretyt.swr"
	
	if [ "$BOX_TYPE" != "rpi" ]
	then
	echo "selfheal type"
        if [ ! -f /usr/bin/GetConfigFile ];then
            echo "Error: GetConfigFile Not Found"
            exit
        fi
	fi
        IDLE_TIMEOUT=60
    ;;
    "TCCBR")
        WAN_INTERFACE="erouter0"
        PEER_COMM_ID="/tmp/elxrretyt.swr"

        if [ ! -f /usr/bin/GetConfigFile ];then
            echo "Error: GetConfigFile Not Found"
            exit
        fi
        IDLE_TIMEOUT=30
    ;;
    "SYSTEMD")
    ;;
esac


CCSP_ERR_TIMEOUT=191
CCSP_ERR_NOT_EXIST=192

exec 3>&1 4>&2 >>$SELFHEALFILE 2>&1



# set thisREADYFILE for several tests below:
case $SELFHEAL_TYPE in
    "BASE")
    ;;
    "TCCBR")
    ;;
    "SYSTEMD")
        thisREADYFILE="/tmp/.qtn_ready"
        case $MACHINE_IMAGE_NAME in
            *CGM4331COM*) thisREADYFILE="/tmp/.brcm_wifi_ready";;
            *TG4482A*) thisREADYFILE="/tmp/.qtn_ready";; ## This will need to change during integration effort
                       *) ;;
        esac
    ;;
esac

# set thisWAN_TYPE for several tests below:
case $SELFHEAL_TYPE in
    "BASE")
        thisWAN_TYPE="$WAN_TYPE"
    ;;
    "TCCBR")
        thisWAN_TYPE="NOT_EPON" # WAN_TYPE is undefined for TCCBR, so kludge it so that tests fail for "EPON"
    ;;
    "SYSTEMD")
        thisWAN_TYPE="$WAN_TYPE"
    ;;
esac


# set thisIS_BCI for several tests below:
# 'thisIS_BCI' is used where 'IS_BCI' was added in recent changes (c.6/2019)
# 'IS_BCI' is still used when appearing in earlier code.
# TBD: may be able to set 'thisIS_BCI=$IS_BCI' for ALL devices?
case $SELFHEAL_TYPE in
    "BASE")
        thisIS_BCI="$IS_BCI"
    ;;
    "TCCBR")
        thisIS_BCI="no"
    ;;
    "SYSTEMD")
        thisIS_BCI="no"
    ;;
esac

case $SELFHEAL_TYPE in
    "BASE")
        if [ -f $ADVSEC_PATH ] && [ "$BOX_TYPE" != "rpi" ]
        then
            source $ADVSEC_PATH
        fi
        reboot_needed_atom_ro=0
        if [ "$thisIS_BCI" != "yes" ] && [ "$BOX_TYPE" != "rpi" ]; then
            brlan1_firewall="/tmp/brlan1_firewall_rule_validated"
        fi
    ;;
    "TCCBR")
        reb_window=0
    ;;
    "SYSTEMD")
        WAN_INTERFACE="erouter0"

        if [ -f $ADVSEC_PATH ]
        then
            source $ADVSEC_PATH
        fi

        brlan1_firewall="/tmp/brlan1_firewall_rule_validated"
    ;;
esac

rebootDeviceNeeded=0

LIGHTTPD_CONF="/var/lighttpd.conf"

case $SELFHEAL_TYPE in
    "BASE")
        ###########################################
        if [ "$BOX_TYPE" = "XB3" ]; then
            wifi_check=`dmcli eRT getv Device.WiFi.SSID.1.Enable`
            wifi_timeout=`echo $wifi_check | grep "$CCSP_ERR_TIMEOUT"`
            wifi_not_exist=`echo $wifi_check | grep "$CCSP_ERR_NOT_EXIST"`
            WIFI_QUERY_ERROR=0
            if [ "$wifi_timeout" != "" ] || [ "$wifi_not_exist" != "" ]; then
                echo_t "[RDKB_SELFHEAL] : Wifi query timeout"
                echo_t "WIFI_QUERY : $wifi_check"
                WIFI_QUERY_ERROR=1
            fi

	    if [ "$BOX_TYPE" != "rpi" ]; then	
            GetConfigFile $PEER_COMM_ID
            SSH_ATOM_TEST=$(ssh -I $IDLE_TIMEOUT -i $PEER_COMM_ID root@$ATOM_IP exit 2>&1)
            echo_t "SSH_ATOM_TEST : $SSH_ATOM_TEST"
            SSH_ERROR=`echo $SSH_ATOM_TEST | grep "Remote closed the connection"`
            SSH_TIMEOUT=`echo $SSH_ATOM_TEST | grep "Idle timeout"`
            rm -f $PEER_COMM_ID
            ATM_HANG_ERROR=0
            if [ "$SSH_ERROR" != "" ] || [ "$SSH_TIMEOUT" != "" ]; then
                echo_t "[RDKB_SELFHEAL] : ssh to atom failed"
                ATM_HANG_ERROR=1
            fi
		
            if [ "$WIFI_QUERY_ERROR" == "1" ] && [ "$ATM_HANG_ERROR" == "1" ]
            then
                atom_hang_count=`sysevent get atom_hang_count`
                echo_t "[RDKB_SELFHEAL] : Atom is not responding. Count $atom_hang_count"
                if [ $atom_hang_count -ge 2 ]; then
                    CheckRebootCretiriaForAtomHang
                    atom_hang_reboot_count=`syscfg get todays_atom_reboot_count`
                    if [ $atom_hang_reboot_count -eq 0 ]; then
                        echo_t "[RDKB_PLATFORM_ERROR] : Atom is not responding. Rebooting box.."
                        reason="ATOM_HANG"
                        rebootCount=1
                        #setRebootreason $reason $rebootCount
                        rebootNeeded $reason "" $reason $rebootCount
                    else
                        echo_t "[RDKB_SELFHEAL] : Reboot allowed for only one time per day. It will reboot in next 24hrs."
                    fi
                else
                    atom_hang_count=$((atom_hang_count + 1))
                    sysevent set atom_hang_count $atom_hang_count
                fi
            else
                sysevent set atom_hang_count 0
            fi
fi
            ### SNMPv3 master agent self-heal ####
            SNMPv3_PID=`pidof snmpd`
            if [ "$SNMPv3_PID" == "" ] && [ "x$ENABLE_SNMPv3" == "xtrue" ]; then
                # Restart disconnected master and agent
                v3AgentPid=`ps | grep -i snmp_subagent | grep -v grep | grep -i cm_snmp_ma_2  | awk '{print $1}'`
                if [ ! -z "$v3AgentPid" ]; then
                    kill -9 $v3AgentPid
                fi
                pidOfListener=`ps  | grep -i inotify | grep 'run_snmpv3_agent.sh' | awk '{print $1}'`
                if [ ! -z "$pidOfListener" ]; then
                    kill -9 $pidOfListener
                fi
                if [ -f /tmp/snmpd.conf ]; then
                    rm -f /tmp/snmpd.conf
                fi
                if [ -f /lib/rdk/run_snmpv3_master.sh ]; then
                    sh /lib/rdk/run_snmpv3_master.sh &
                fi
            else
                ### SNMPv3 sub agent self-heal ####
                v3AgentPid=`ps | grep -i snmp_subagent | grep -v grep | grep -i cm_snmp_ma_2  | awk '{print $1}'`
                if [ "$v3AgentPid" == "" ] && [ "x$ENABLE_SNMPv3" == "xtrue" ]; then
                    # Restart failed sub agent
                    if [ -f /lib/rdk/run_snmpv3_agent.sh ]; then
                        sh /lib/rdk/run_snmpv3_agent.sh &
                    fi
                fi
            fi

        fi
        ###########################################

        if [ "$MULTI_CORE" = "yes" ]; then
            if [ "$CORE_TYPE" = "arm" ]; then
                # Checking logbackup PID
                LOGBACKUP_PID=`pidof logbackup`
                if [ "$LOGBACKUP_PID" == "" ]; then
                    echo_t "RDKB_PROCESS_CRASHED : logbackup process is not running, need restart"
                    /usr/bin/logbackup &
                fi
            fi
            if [ -f $PING_PATH/ping_peer ]
            then
                ## Check Peer ip is accessible
                loop=1
                while [ "$loop" -le 3 ]
                do
                    PING_RES=`ping_peer`
                    CHECK_PING_RES=`echo $PING_RES | grep "packet loss" | cut -d"," -f3 | cut -d"%" -f1`
                    if [ "$CHECK_PING_RES" != "" ]
                    then
                        if [ "$CHECK_PING_RES" -ne 100 ]
                        then
                            ping_success=1
                            echo_t "RDKB_SELFHEAL : Ping to Peer IP is success"
                            break
                        else
                            echo_t "[RDKB_PLATFORM_ERROR] : ATOM interface is not reachable"
                            ping_failed=1
                        fi
                    else
                        if [ "$DEVICE_MODEL" = "TCHXB3" ]; then
                            check_if_l2sd0_500_up=`ifconfig l2sd0.500 | grep UP `
                            check_if_l2sd0_500_ip=`ifconfig l2sd0.500 | grep inet `
                            if [ "$check_if_l2sd0_500_up" = "" ] || [ "$check_if_l2sd0_500_ip" = "" ]
                            then
                                echo_t "[RDKB_PLATFORM_ERROR] : l2sd0.500 is not up, setting to recreate interface"
                                rpc_ifconfig l2sd0.500 >/dev/null 2>&1
                                sleep 3
                            fi
                            PING_RES=`ping_peer`
                            CHECK_PING_RES=`echo $PING_RES | grep "packet loss" | cut -d"," -f3 | cut -d"%" -f1`
                            if [ "$CHECK_PING_RES" != "" ]
                            then
                                if [ "$CHECK_PING_RES" -ne 100 ]
                                then
                                    echo_t "[RDKB_PLATFORM_ERROR] : l2sd0.500 is up,Ping to Peer IP is success"
                                    break
                                fi
                            fi
                        fi
                        ping_failed=1
                    fi

                    if [ "$ping_failed" -eq 1 ] && [ "$loop" -lt 3 ]
                    then
                        echo_t "RDKB_SELFHEAL : Ping to Peer IP failed in iteration $loop"
                        echo_t "RDKB_SELFHEAL : Ping command output is $PING_RES"
                    else
                        echo_t "RDKB_SELFHEAL : Ping to Peer IP failed after iteration $loop also ,rebooting the device"
                        echo_t "RDKB_SELFHEAL : Ping command output is $PING_RES"
                        echo_t "RDKB_REBOOT : Peer is not up ,Rebooting device "
                        #echo_t " RDKB_SELFHEAL : Setting Last reboot reason as Peer_down"
                        reason="Peer_down"
                        rebootCount=1
                        #setRebootreason $reason $rebootCount
                        rebootNeeded RM "" $reason $rebootCount

                    fi
                    loop=$((loop+1))
                    sleep 5
                done
            else
                echo_t "RDKB_SELFHEAL : ping_peer command not found"
            fi

            if [ -f $PING_PATH/arping_peer ]
            then
                $PING_PATH/arping_peer
            else
                echo_t "RDKB_SELFHEAL : arping_peer command not found"
            fi
        else
            echo_t "RDKB_SELFHEAL : MULTI_CORE is not defined as yes. Define it as yes if it's a multi core device."
        fi
        ########################################
        if [ "$BOX_TYPE" = "XB3" ]; then
            atomOnlyReboot=`dmesg -n 8 && dmesg | grep -i "Atom only"`
            if [ x$atomOnlyReboot = x ];then
                crTestop=`dmcli eRT getv com.cisco.spvtg.ccsp.CR.Name`
                isCRAlive=`echo $crTestop | grep "Can't find destination compo"`
                isCRHung=`echo $crTestop | grep "$CCSP_ERR_TIMEOUT"`

                if [ "$isCRAlive" != "" ]; then
                    # Retest by querying some other parameter
                    crReTestop=`dmcli eRT getv Device.X_CISCO_COM_DeviceControl.DeviceMode`
                    isCRAlive=`echo $crReTestop | grep "Can't find destination compo"`
                    if [ "$isCRAlive" != "" ]; then
                        echo_t "RDKB_PROCESS_CRASHED : CR_process is not running, need to reboot the unit"
                        vendor=`getVendorName`
                        modelName=`getModelName`
                        CMMac=`getCMMac`
                        timestamp=`getDate`
                        #echo "Setting Last reboot reason"
                        reason="CR_crash"
                        rebootCount=1
                        #setRebootreason $reason $rebootCount
                        echo_t "SET succeeded"
                        echo_t "RDKB_SELFHEAL : <$level>CABLEMODEM[$vendor]:<99000007><$timestamp><$CMMac><$modelName> RM CcspCrSsp process died,need reboot"
                        touch $HAVECRASH
                        rebootNeeded RM "CR" $reason $rebootCount
                    fi
                fi

                if [ "$isCRHung" != "" ]; then
                    # Retest by querying some other parameter
                    crReTestop=`dmcli eRT getv Device.X_CISCO_COM_DeviceControl.DeviceMode`
                    isCRHung=`echo $crReTestop | grep "$CCSP_ERR_TIMEOUT"`
                    if [ "$isCRHung" != "" ]; then
                        echo_t "RDKB_PROCESS_CRASHED : CR_process is not responding, need to reboot the unit"
                        vendor=`getVendorName`
                        modelName=`getModelName`
                        CMMac=`getCMMac`
                        timestamp=`getDate`
                        #echo "Setting Last reboot reason"
                        reason="CR_hang"
                        rebootCount=1
                        #setRebootreason $reason $rebootCount
                        echo_t "SET succeeded"
                        echo_t "RDKB_SELFHEAL : <$level>CABLEMODEM[$vendor]:<99000007><$timestamp><$CMMac><$modelName> RM CcspCrSsp process not responding, need reboot"
                        touch $HAVECRASH
                        rebootNeeded RM "CR" $reason $rebootCount
                    fi
                fi

            else
                echo_t "[RDKB_SELFHEAL] : Atom only reboot is triggered"
            fi
        elif [ "$WAN_TYPE" = "EPON" ]; then
            CR_PID=`pidof CcspCrSsp`
            if [ "$CR_PID" = "" ]; then
                echo_t "RDKB_PROCESS_CRASHED : CR_process is not running, need to reboot the unit"
                vendor=`getVendorName`
                modelName=`getModelName`
                CMMac=`getCMMac`
                timestamp=`getDate`
                #echo "Setting Last reboot reason"
                reason="CR_crash"
                rebootCount=1
                #setRebootreason $reason $rebootCount
                echo_t "SET succeeded"
                echo_t "RDKB_SELFHEAL : <$level>CABLEMODEM[$vendor]:<99000007><$timestamp><$CMMac><$modelName> RM CcspCrSsp process died,need reboot"
                touch $HAVECRASH
                rebootNeeded RM "CR" $reason $rebootCount
            fi
        fi




        ###########################################
    ;;
    "TCCBR")
    ;;
    "SYSTEMD")
        if [ "$MODEL_NUM" = "CGM4140COM" ] || [ "$MODEL_NUM" = "CGM4331COM" ]; then
            Check_If_Erouter_Exists=`ifconfig -a | grep $WAN_INTERFACE`
            ifconfig $WAN_INTERFACE > /dev/null
            wan_exists=$?
            if [ "$Check_If_Erouter_Exists" = "" ] && [ $wan_exists -ne 0 ];then
                echo_t "RDKB_REBOOT : Erouter0 interface is not up ,Rebooting device"
                echo_t "Setting Last reboot reason Erouter_Down"
                reason="Erouter_Down"
                rebootCount=1
                rebootNeeded RM "" $reason $rebootCount
            fi

        fi

        #ARRISXB6-9443 temp fix. Need to generalize and improve.
        if [ "$MODEL_NUM" = "TG3482G" ] || [ "$MODEL_NUM" = "TG4482A" ]; then
            brctl show brlan0 | grep nmoca0 >> /dev/null
            if [ $? != 0 ] ; then
                echo_t "Moca is not part of brlan0.. adding it"
                sysevent set multinet-syncMembers 1
            fi
        fi

    ;;
esac


# Checking PSM's PID
PSM_PID=`pidof PsmSsp`
if [ "$PSM_PID" = "" ]; then
    case $SELFHEAL_TYPE in
        "BASE"|"TCCBR")
            #       echo "[`getDateTime`] RDKB_PROCESS_CRASHED : PSM_process is not running, need to reboot the unit"
            #       echo "[`getDateTime`] RDKB_PROCESS_CRASHED : PSM_process is not running, need to reboot the unit"
            #       vendor=`getVendorName`
            #       modelName=`getModelName`
            #       CMMac=`getCMMac`
            #       timestamp=`getDate`
            #       echo "[`getDateTime`] Setting Last reboot reason"
            #       dmcli eRT setv Device.DeviceInfo.X_RDKCENTRAL-COM_LastRebootReason string Psm_crash
            #       dmcli eRT setv Device.DeviceInfo.X_RDKCENTRAL-COM_LastRebootCounter int 1
            #       echo "[`getDateTime`] SET succeeded"
            #       echo "[`getDateTime`] RDKB_SELFHEAL : <$level>CABLEMODEM[$vendor]:<99000007><$timestamp><$CMMac><$modelName> RM PsmSsp process died,need reboot"
            #       touch $HAVECRASH
            #       rebootNeeded RM "PSM"
            echo_t "RDKB_PROCESS_CRASHED : PSM_process is not running, need restart"
            resetNeeded psm PsmSsp
        ;;
        "SYSTEMD")
        ;;
    esac
else
    psm_name=`dmcli eRT getv com.cisco.spvtg.ccsp.psm.Name`
    psm_name_timeout=`echo $psm_name | grep "$CCSP_ERR_TIMEOUT"`
    psm_name_notexist=`echo $psm_name | grep "$CCSP_ERR_NOT_EXIST"`
    if [ "$psm_name_timeout" != "" ] || [ "$psm_name_notexist" != "" ]; then
        psm_health=`dmcli eRT getv com.cisco.spvtg.ccsp.psm.Health`
        psm_health_timeout=`echo $psm_health | grep "$CCSP_ERR_TIMEOUT"`
        psm_health_notexist=`echo $psm_health | grep "$CCSP_ERR_NOT_EXIST"`
        if [ "$psm_health_timeout" != "" ] || [ "$psm_health_notexist" != "" ]; then
            echo_t "RDKB_PROCESS_CRASHED : PSM_process is in hung state, need restart"
            case $SELFHEAL_TYPE in
                "BASE"|"TCCBR")
                    kill -9 `pidof PsmSsp`
                    resetNeeded psm PsmSsp
                ;;
                "SYSTEMD")
                    systemctl restart PsmSsp.service
                ;;
            esac
        fi
    fi
fi

case $SELFHEAL_TYPE in
    "BASE")
	WiFi_Flag=false                                                                                                   
        # Checking Wifi's PID                                                                                           
        WIFI_PID=`pidof CcspWifiSsp`                                                                                                           
        if [ "$WIFI_PID" = "" ]; then                                                                             
            # Remove the wifi initialized flag                                                                                                 
            rm -rf /tmp/wifi_initialized                                                                                  
            echo_t "RDKB_PROCESS_CRASHED : WIFI_process is not running, need restart"                                                          
            resetNeeded wifi CcspWifiSsp                                                                                                       
        else                                                                                                      
            radioenable=`dmcli eRT getv Device.WiFi.Radio.1.Enable`                                               
            radioenable_timeout=`echo $radioenable | grep "$CCSP_ERR_TIMEOUT"`                                            
            radioenable_notexist=`echo $radioenable | grep "$CCSP_ERR_NOT_EXIST"`                                                              
            if [ "$radioenable_timeout" != "" ] || [ "$radioenable_notexist" != "" ]; then                                                     
                wifi_name=`dmcli eRT getv com.cisco.spvtg.ccsp.wifi.Name`                                                
                wifi_name_timeout=`echo $wifi_name | grep "$CCSP_ERR_TIMEOUT"`                                       
                wifi_name_notexist=`echo $wifi_name | grep "$CCSP_ERR_NOT_EXIST"`                                         
                if [ "$wifi_name_timeout" != "" ] || [ "$wifi_name_notexist" != "" ]; then                               
                    echo_t "[RDKB_PLATFORM_ERROR] : CcspWifiSsp process is restarting"                                                         
                    # Remove the wifi initialized flag                                                                    
                    rm -rf /tmp/wifi_initialized                                                                  
                    resetNeeded wifi CcspWifiSsp                                                                          
                    WiFi_Flag=true                                                                                        
                fi                                                                                                                             
            fi                                                                                                    
        fi     

        PAM_PID=`pidof CcspPandMSsp`
        if [ "$PAM_PID" = "" ]; then
            # Remove the P&M initialized flag
            rm -rf /tmp/pam_initialized
            echo_t "RDKB_PROCESS_CRASHED : PAM_process is not running, need restart"
            resetNeeded pam CcspPandMSsp
        fi

        # Checking MTA's PID
        if [ "$MODEL_NUM" = "DPC3939B" ] || [ "$MODEL_NUM" = "DPC3941B" ] || [ "$BOX_TYPE" == "rpi" ]; then
                echo_t "BWG doesn't support voice"
        else
            MTA_PID=`pidof CcspMtaAgentSsp`
            if [ "$MTA_PID" = "" ]; then
                #       echo "[`getDateTime`] RDKB_PROCESS_CRASHED : MTA_process is not running, restarting it"
                echo_t "RDKB_PROCESS_CRASHED : MTA_process is not running, need restart"
                resetNeeded mta CcspMtaAgentSsp

            fi
        fi

        # Checking CM's PID
	if [ "$BOX_TYPE" != "rpi" ]; then
        if [ "$WAN_TYPE" != "EPON" ]; then
            CM_PID=`pidof CcspCMAgentSsp`
            if [ "$CM_PID" = "" ]; then
                #           echo "[`getDateTime`] RDKB_PROCESS_CRASHED : CM_process is not running, restarting it"
                echo_t "RDKB_PROCESS_CRASHED : CM_process is not running, need restart"
                resetNeeded cm CcspCMAgentSsp
            fi
        else
            #Checking EPONAgent is running.
            EPON_AGENT_PID=`pidof CcspEPONAgentSsp`
            if [ "$EPON_AGENT_PID" = "" ]; then
                echo_t "RDKB_PROCESS_CRASHED : EPON_process is not running, need restart"
                resetNeeded epon CcspEPONAgentSsp
            fi
        fi
	fi
        # Checking WEBController's PID
        #   WEBC_PID=`pidof CcspWecbController`
        #   if [ "$WEBC_PID" = "" ]; then
        #       echo "[`getDateTime`] RDKB_PROCESS_CRASHED : WECBController_process is not running, restarting it"
        #       echo_t "RDKB_PROCESS_CRASHED : WECBController_process is not running, need restart"
        #       resetNeeded wecb CcspWecbController
        #   fi

        # Checking RebootManager's PID
        #   Rm_PID=`pidof CcspRmSsp`
        #   if [ "$Rm_PID" = "" ]; then
        #   echo "[`getDateTime`] RDKB_PROCESS_CRASHED : RebootManager_process is not running, restarting it"
        #       echo "[`getDateTime`] RDKB_PROCESS_CRASHED : RebootManager_process is not running, need restart"
        #       resetNeeded "rm" CcspRmSsp

        #   fi

        # Checking TR69's PID
        if [ "$MODEL_NUM" = "DPC3939B" ] || [ "$MODEL_NUM" = "DPC3941B" ]; then
            echo_t "BWG doesn't support TR069Pa "
        else
            TR69_PID=`pidof CcspTr069PaSsp`
            if [ "$TR69_PID" = "" ]; then
                echo_t "RDKB_PROCESS_CRASHED : TR69_process is not running, need restart"
                resetNeeded TR69 CcspTr069PaSsp
            fi
        fi

        # Checking Test adn Daignostic's PID
        TandD_PID=`pidof CcspTandDSsp`
        if [ "$TandD_PID" = "" ]; then
            echo_t "RDKB_PROCESS_CRASHED : TandD_process is not running, need restart"
            resetNeeded tad CcspTandDSsp
        fi

        # Checking Lan Manager PID
        LM_PID=`pidof CcspLMLite`
        if [ "$LM_PID" = "" ]; then
            echo_t "RDKB_PROCESS_CRASHED : LanManager_process is not running, need restart"
            resetNeeded lm CcspLMLite
        else
            cr_query=`dmcli eRT getv com.cisco.spvtg.ccsp.lmlite.Name`
            cr_timeout=`echo $cr_query | grep "$CCSP_ERR_TIMEOUT"`
            cr_lmlite_notexist=`echo $cr_query | grep "$CCSP_ERR_NOT_EXIST"`
            if [ "$cr_timeout" != "" ] || [ "$cr_lmlite_notexist" != "" ]; then
                echo_t "[RDKB_PLATFORM_ERROR] : LMlite process is not responding. Restarting it"
                kill -9 `pidof CcspLMLite`
                resetNeeded lm CcspLMLite
            fi
        fi


        # Checking XdnsSsp PID
        XDNS_PID=`pidof CcspXdnsSsp`
        if [ "$XDNS_PID" = "" ] && [ "$BOX_TYPE" != "rpi" ]; then
            echo_t "RDKB_PROCESS_CRASHED : CcspXdnsSsp_process is not running, need restart"
            resetNeeded xdns CcspXdnsSsp

        fi

        # Checking CcspEthAgent PID
        ETHAGENT_PID=`pidof CcspEthAgent`
        if [ "$ETHAGENT_PID" = "" ]; then
            echo_t "RDKB_PROCESS_CRASHED : CcspEthAgent_process is not running, need restart"
            resetNeeded ethagent CcspEthAgent

        fi

        # Checking snmp v2 subagent PID
        SNMP_PID=`ps ww | grep snmp_subagent | grep -v cm_snmp_ma_2 | grep -v grep | awk '{print $1}'`
        if [ "$SNMP_PID" = "" ]; then
            if [ -f /tmp/.snmp_agent_restarting ]; then
                echo_t "[RDKB_SELFHEAL] : snmp process is restarted through maintanance window"
            else
                SNMPv2_RDKB_MIBS_SUPPORT=`syscfg get V2Support`
                if [[ "$SNMPv2_RDKB_MIBS_SUPPORT" = "true" || "$SNMPv2_RDKB_MIBS_SUPPORT" = "" ]];then
                    echo_t "RDKB_PROCESS_CRASHED : snmp process is not running, need restart"
                    resetNeeded snmp snmp_subagent
                fi
            fi
        fi

        # Checking CcspMoCA PID
        MOCA_PID=`pidof CcspMoCA`
        if [ "$MOCA_PID" = "" ] && [ "$BOX_TYPE" != "rpi" ]; then
            echo_t "RDKB_PROCESS_CRASHED : CcspMoCA process is not running, need restart"
            resetNeeded moca CcspMoCA
        fi
    ;;
    "TCCBR")
    ;;
    "SYSTEMD")
    ;;
esac

case $SELFHEAL_TYPE in
    "BASE")
    ;;
    "TCCBR")
    ;;
    "SYSTEMD")
        WiFi_Flag=false
        WiFi_PID=`pidof CcspWifiSsp`
        if [ "$WiFi_PID" != "" ]; then
            radioenable=`dmcli eRT getv Device.WiFi.Radio.1.Enable`
            radioenable_timeout=`echo $radioenable | grep "$CCSP_ERR_TIMEOUT"`
            radioenable_notexist=`echo $radioenable | grep "$CCSP_ERR_NOT_EXIST"`
            if [ "$radioenable_timeout" != "" ] || [ "$radioenable_notexist" != "" ]; then
                wifi_name=`dmcli eRT getv com.cisco.spvtg.ccsp.wifi.Name`
                wifi_name_timeout=`echo $wifi_name | grep "$CCSP_ERR_TIMEOUT"`
                wifi_name_notexist=`echo $wifi_name | grep "$CCSP_ERR_NOT_EXIST"`
                if [ "$wifi_name_timeout" != "" ] || [ "$wifi_name_notexist" != "" ]; then
                    if [ "$BOX_TYPE" = "XB6" ] || [ "$BOX_TYPE" = "XB7" ]; then
                        if [ -f "$thisREADYFILE" ]
                        then
                            echo_t "[RDKB_PLATFORM_ERROR] : CcspWifiSsp process is hung , restarting it"
                            systemctl restart ccspwifiagent
                            WiFi_Flag=true
                        fi
                    else
                        echo_t "[RDKB_PLATFORM_ERROR] : CcspWifiSsp process is hung , restarting it"
                        systemctl restart ccspwifiagent
                        WiFi_Flag=true
                    fi
                fi
            fi
        fi
    ;;
esac

if [ "$BOX_TYPE" != "HUB4" ] && [ "$BOX_TYPE" != "rpi" ]; then

case $SELFHEAL_TYPE in
    "BASE"|"SYSTEMD")

        HOMESEC_PID=`pidof CcspHomeSecurity`
        if [ "$HOMESEC_PID" = "" ]; then
            case $SELFHEAL_TYPE in
                "BASE")
                        echo_t "RDKB_PROCESS_CRASHED : HomeSecurity_process is not running, need restart"
                ;;
                "TCCBR")
                ;;
                "SYSTEMD")
                        echo_t "RDKB_PROCESS_CRASHED : HomeSecurity process is not running, need restart"
                ;;
            esac
            resetNeeded "" CcspHomeSecurity
        fi

        advsec_bridge_mode=`syscfg get bridge_mode`
        DF_ENABLED=`syscfg get Advsecurity_DeviceFingerPrint`
        case $SELFHEAL_TYPE in
            "BASE")
                RABID_ENABLED=`syscfg get Advsecurity_RabidEnable`
            ;;
            "TCCBR")
            ;;
            "SYSTEMD")
                RABID_ENABLED=`syscfg get Advsecurity_RabidEnable`
            ;;
        esac
        if [ "$advsec_bridge_mode" != "2" ] && [ "$BOX_TYPE" != "rpi" ]; then
            if [ "$DF_ENABLED" = "1" ] || [ "$RABID_ENABLED" = "1" ]; then
                if [ -f $ADVSEC_PATH ]
                then
                    isADVPID=0
                    case $SELFHEAL_TYPE in
                        "BASE")
                            # CcspAdvSecurity
                            ADV_PID=`pidof CcspAdvSecuritySsp`
                            if [ "$ADV_PID" = "" ] ; then
                                echo_t "RDKB_PROCESS_CRASHED : CcspAdvSecurity_process is not running, need restart"
                                resetNeeded advsec CcspAdvSecuritySsp
                                isADVPID=1
                            fi
                        ;;
                        "TCCBR")
                        ;;
                        "SYSTEMD")
                        ;;
                    esac
                    if [ $isADVPID -eq 0 ]; then
                        if [ ! -f $ADVSEC_INITIALIZING ]
                        then
                            if [ "$RABID_ENABLED" != "1" ] && [ ! -f ${ADVSEC_RABID_ENABLED_PATH} ]; then
                                ADV_AG_PID=`advsec_is_alive agent`
                                if [ "$ADV_AG_PID" = "" ] ; then
                                    echo_t "RDKB_PROCESS_CRASHED : AdvSecurity Agent process is not running, need restart"
                                    resetNeeded advsec_bin AdvSecurityAgent
                                fi
                                ADV_DHCP_PID=`advsec_is_alive dhcpcap`
                                if [ "$ADV_DHCP_PID" = "" ] ; then
                                    echo_t "RDKB_PROCESS_CRASHED : AdvSecurity Dhcpcap process is not running, need restart"
                                    resetNeeded advsec_bin AdvSecurityDhcp
                                fi
                                if [ ! -f "$DAEMONS_HIBERNATING" ] ; then
                                    ADV_DNS_PID=`advsec_is_alive dnscap`
                                    if [ "$ADV_DNS_PID" = "" ] ; then
                                        echo_t "RDKB_PROCESS_CRASHED : AdvSecurity Dnscap process is not running, need restart"
                                        resetNeeded advsec_bin AdvSecurityDns
                                    fi
                                    ADV_MDNS_PID=`advsec_is_alive mdnscap`
                                    if [ "$ADV_MDNS_PID" = "" ] ; then
                                        echo_t "RDKB_PROCESS_CRASHED : AdvSecurity Mdnscap process is not running, need restart"
                                        resetNeeded advsec_bin AdvSecurityMdns
                                    fi
                                    ADV_P0F_PID=`advsec_is_alive p0f`
                                    if [ "$ADV_P0F_PID" = "" ] ; then
                                        echo_t "RDKB_PROCESS_CRASHED : AdvSecurity PoF process is not running, need restart"
                                        resetNeeded advsec_bin AdvSecurityPof
                                    fi
                                fi
                                ADV_SCAN_PID=`advsec_is_alive scannerd`
                                if [ "$ADV_SCAN_PID" = "" ] ; then
                                    echo_t "RDKB_PROCESS_CRASHED : AdvSecurity Scanner process is not running, need restart"
                                    resetNeeded advsec_bin AdvSecurityScanner
                                fi
                                if [ -e ${SAFEBRO_ENABLE} ] ; then
                                    ADV_SB_PID=`advsec_is_alive threatd`
                                    if [ "$ADV_SB_PID" = "" ] ; then
                                        echo_t "RDKB_PROCESS_CRASHED : AdvSecurity Threat process is not running, need restart"
                                        resetNeeded advsec_bin AdvSecurityThreat
                                    fi
                                fi
                                if [ -e ${SOFTFLOWD_ENABLE} ] ; then
                                    ADV_SF_PID=`advsec_is_alive softflowd`
                                    if [ "$ADV_SF_PID" = "" ] ; then
                                        echo_t "RDKB_PROCESS_CRASHED : AdvSecurity Softflowd process is not running, need restart"
                                        resetNeeded advsec_bin AdvSecuritySoftflowd
                                    fi
                                fi
                            else
                                ADV_RABID_PID=`advsec_is_alive rabid`
                                if [ "$ADV_RABID_PID" = "" ] ; then
                                    echo_t "RDKB_PROCESS_CRASHED : AdvSecurity Rabid process is not running, need restart"
                                    resetNeeded advsec_bin AdvSecurityRabid
                                fi
                            fi
                        fi
                    fi
                else
                    case $SELFHEAL_TYPE in
                        "BASE")
                            if [[ "$MODEL_NUM" = "DPC3939" || "$MODEL_NUM" = "DPC3941" ]]; then
                                /usr/sbin/cujo_download.sh &
                            fi
                        ;;
                        "TCCBR")
                        ;;
                        "SYSTEMD")
                        ;;
                    esac
                fi  # [ -f $ADVSEC_PATH ]
            fi  # [ "$DF_ENABLED" = "1" ] || [ "$RABID_ENABLED" = "1" ]
        fi  # [ "$advsec_bridge_mode" != "2" ]
    ;;
    "TCCBR")
    ;;
esac

fi #Not HUb4

case $SELFHEAL_TYPE in
    "BASE")
    ;;
    "TCCBR")
        ##################################
        if [ "$BOX_TYPE" = "XB3" ]; then
            wifi_check=`dmcli eRT getv Device.WiFi.SSID.1.Enable`
            wifi_timeout=`echo $wifi_check | grep "$CCSP_ERR_TIMEOUT"`
            if [ "$wifi_timeout" != "" ]; then
                echo_t "[RDKB_SELFHEAL] : Wifi query timeout"
            fi


            GetConfigFile $PEER_COMM_ID
            SSH_ATOM_TEST=$(ssh -i $PEER_COMM_ID root@$ATOM_IP exit 2>&1)
            SSH_ERROR=`echo $SSH_ATOM_TEST | grep "Remote closed the connection"`
            rm -f $PEER_COMM_ID
            if [ "$SSH_ERROR" != "" ]; then
                echo_t "[RDKB_SELFHEAL] : ssh to atom failed"
            fi

            if [ "$wifi_timeout" != "" ] && [ "$SSH_ERROR" != "" ]
            then
                atom_hang_count=`sysevent get atom_hang_count`
                echo_t "[RDKB_SELFHEAL] : Atom is not responding. Count $atom_hang_count"
                if [ $atom_hang_count -ge 2 ]; then
                    CheckRebootCretiriaForAtomHang
                    atom_hang_reboot_count=`syscfg get todays_atom_reboot_count`
                    if [ $atom_hang_reboot_count -eq 0 ]; then
                        echo_t "[RDKB_PLATFORM_ERROR] : Atom is not responding. Rebooting box.."
                        reason="ATOM_HANG"
                        rebootCount=1
                        setRebootreason $reason $rebootCount
                        rebootNeeded $reason ""
                    else
                        echo_t "[RDKB_SELFHEAL] : Reboot allowed for only one time per day. It will reboot in next 24hrs."
                    fi
                else
                    atom_hang_count=$((atom_hang_count + 1))
                    sysevent set atom_hang_count $atom_hang_count
                fi
            else
                sysevent set atom_hang_count 0
            fi
        fi
        ###########################################

        if [ "$MULTI_CORE" = "yes" ]; then
            if [ -f $PING_PATH/ping_peer ]
            then
                ## Check Peer ip is accessible
                loop=1
                while [ "$loop" -le 3 ]
                do
                    PING_RES=`ping_peer`
                    CHECK_PING_RES=`echo $PING_RES | grep "packet loss" | cut -d"," -f3 | cut -d"%" -f1`

                    if [ "$CHECK_PING_RES" != "" ]
                    then
                        if [ "$CHECK_PING_RES" -ne 100 ]
                        then
                            ping_success=1
                            echo_t "RDKB_SELFHEAL : Ping to Peer IP is success"
                            break
                        else
                            ping_failed=1
                        fi
                    else
                        ping_failed=1
                    fi

                    if [ "$ping_failed" -eq 1 ] && [ "$loop" -lt 3 ]
                    then
                        echo_t "RDKB_SELFHEAL : Ping to Peer IP failed in iteration $loop"
                        echo_t "RDKB_SELFHEAL : Ping command output is $PING_RES"
                    else
                        echo_t "RDKB_SELFHEAL : Ping to Peer IP failed after iteration $loop also ,rebooting the device"
                        echo_t "RDKB_SELFHEAL : Ping command output is $PING_RES"
                        echo_t "RDKB_REBOOT : Peer is not up ,Rebooting device "
                        echo_t " RDKB_SELFHEAL : Setting Last reboot reason as Peer_down"
                        reason="Peer_down"
                        rebootCount=1
                        setRebootreason $reason $rebootCount
                        rebootNeeded RM ""

                    fi
                    loop=$((loop+1))
                    sleep 5
                done
            else
                echo_t "RDKB_SELFHEAL : ping_peer command not found"
            fi

            if [ -f $PING_PATH/arping_peer ]
            then
                $PING_PATH/arping_peer
            else
                echo_t "RDKB_SELFHEAL : arping_peer command not found"
            fi
        fi
        ########################################

        atomOnlyReboot=`dmesg -n 8 && dmesg | grep -i "Atom only"`
        if [ x$atomOnlyReboot = x ];then
            crTestop=`dmcli eRT getv com.cisco.spvtg.ccsp.CR.Name`
            isCRAlive=`echo $crTestop | grep "Can't find destination compo"`
            if [ "$isCRAlive" != "" ]; then
                # Retest by querying some other parameter
                crReTestop=`dmcli eRT getv Device.X_CISCO_COM_DeviceControl.DeviceMode`
                isCRAlive=`echo $crReTestop | grep "Can't find destination compo"`
                if [ "$isCRAlive" != "" ]; then
                    #echo "[`getDateTime`] RDKB_PROCESS_CRASHED : CR_process is not running, need to reboot the unit"
                    echo_t "RDKB_PROCESS_CRASHED : CR_process is not running, need to reboot the unit"
                    vendor=`getVendorName`
                    modelName=`getModelName`
                    CMMac=`getCMMac`
                    timestamp=`getDate`
                    echo_t "Setting Last reboot reason"
                    reason="CR_crash"
                    rebootCount=1
                    setRebootreason $reason $rebootCount
                    echo_t "SET succeeded"
                    echo_t "RDKB_SELFHEAL : <$level>CABLEMODEM[$vendor]:<99000007><$timestamp><$CMMac><$modelName> RM CcspCrSsp process died,need reboot"
                    touch $HAVECRASH
                    rebootNeeded RM "CR"
                fi
            fi
        else
            echo_t "[RDKB_SELFHEAL] : Atom only reboot is triggered"
        fi

        ###########################################
	
        WiFi_Flag=false
        # Checking Wifi's PID
        WIFI_PID=`pidof CcspWifiSsp`
        if [ "$WIFI_PID" = "" ]; then
            # Remove the wifi initialized flag
            rm -rf /tmp/wifi_initialized
            echo_t "RDKB_PROCESS_CRASHED : WIFI_process is not running, need restart"
            resetNeeded wifi CcspWifiSsp
        else
            radioenable=`dmcli eRT getv Device.WiFi.Radio.1.Enable`
            radioenable_timeout=`echo $radioenable | grep "$CCSP_ERR_TIMEOUT"`
            radioenable_notexist=`echo $radioenable | grep "$CCSP_ERR_NOT_EXIST"`
            if [ "$radioenable_timeout" != "" ] || [ "$radioenable_notexist" != "" ]; then
                wifi_name=`dmcli eRT getv com.cisco.spvtg.ccsp.wifi.Name`
                wifi_name_timeout=`echo $wifi_name | grep "$CCSP_ERR_TIMEOUT"`
                wifi_name_notexist=`echo $wifi_name | grep "$CCSP_ERR_NOT_EXIST"`
                if [ "$wifi_name_timeout" != "" ] || [ "$wifi_name_notexist" != "" ]; then
                    echo_t "[RDKB_PLATFORM_ERROR] : CcspWifiSsp process is restarting"
                    # Remove the wifi initialized flag
                    rm -rf /tmp/wifi_initialized
                    #resetNeeded wifi CcspWifiSsp
                    WiFi_Flag=true
                fi
            fi
        fi

        PAM_PID=`pidof CcspPandMSsp`
        if [ "$PAM_PID" = "" ]; then
            # Remove the P&M initialized flag
            rm -rf /tmp/pam_initialized
            echo_t "RDKB_PROCESS_CRASHED : PAM_process is not running, need restart"
            resetNeeded pam CcspPandMSsp
        fi

        # Checking MTA's PID
        MTA_PID=`pidof CcspMtaAgentSsp`
        if [ "$MTA_PID" = "" ]; then
            echo_t "RDKB_PROCESS_CRASHED : MTA_process is not running, need restart"
            resetNeeded mta CcspMtaAgentSsp

        fi


        if [ -f /tmp/wifi_eapd_restart_required ] ; then
            echo_t "RDKB_PROCESS_CRASHED : eapd wifi process needs restart"
            killall eapd
            #starting the eapd process
            eapd
            rm -rf /tmp/wifi_eapd_restart_required
        fi

        # Checking CM's PID
        CM_PID=`pidof CcspCMAgentSsp`
        if [ "$CM_PID" = "" ]; then
            echo_t "RDKB_PROCESS_CRASHED : CM_process is not running, need restart"
            resetNeeded cm CcspCMAgentSsp
        fi

        # Checking WEBController's PID
        #   WEBC_PID=`pidof CcspWecbController`
        #   if [ "$WEBC_PID" = "" ]; then
        #       echo "[`getDateTime`] RDKB_PROCESS_CRASHED : WECBController_process is not running, restarting it"
        #       echo_t "RDKB_PROCESS_CRASHED : WECBController_process is not running, need restart"
        #       resetNeeded wecb CcspWecbController
        #   fi

        # Checking RebootManager's PID
        #   Rm_PID=`pidof CcspRmSsp`
        #   if [ "$Rm_PID" = "" ]; then
        #       echo "[`getDateTime`] RDKB_PROCESS_CRASHED : RebootManager_process is not running, restarting it"
        #       echo "[`getDateTime`] RDKB_PROCESS_CRASHED : RebootManager_process is not running, need restart"
        #       resetNeeded "rm" CcspRmSsp

        #   fi

        # Checking Test adn Daignostic's PID
        TandD_PID=`pidof CcspTandDSsp`
        if [ "$TandD_PID" = "" ]; then
            echo_t "RDKB_PROCESS_CRASHED : TandD_process is not running, need restart"
            resetNeeded tad CcspTandDSsp
        fi

        # Checking Lan Manager PID
        LM_PID=`pidof CcspLMLite`
        if [ "$LM_PID" = "" ]; then
            echo_t "RDKB_PROCESS_CRASHED : LanManager_process is not running, need restart"
            resetNeeded lm CcspLMLite

        fi

        # Checking XdnsSsp PID
        XDNS_PID=`pidof CcspXdnsSsp`
        if [ "$XDNS_PID" = "" ]; then
            echo_t "RDKB_PROCESS_CRASHED : CcspXdnsSsp_process is not running, need restart"
            resetNeeded xdns CcspXdnsSsp

        fi

        # Checking CcspEthAgent PID
        ETHAGENT_PID=`pidof CcspEthAgent`
        if [ "$ETHAGENT_PID" = "" ]; then
            echo_t "RDKB_PROCESS_CRASHED : CcspEthAgent_process is not running, need restart"
            resetNeeded ethagent CcspEthAgent

        fi

        # Checking snmp subagent PID
        SNMP_PID=`pidof snmp_subagent`
        if [ "$SNMP_PID" = "" ]; then
            echo_t "RDKB_PROCESS_CRASHED : snmp process is not running, need restart"
            resetNeeded snmp snmp_subagent
        fi
    ;;
    "SYSTEMD")
    ;;
esac

HOTSPOT_ENABLE=`dmcli eRT getv Device.DeviceInfo.X_COMCAST_COM_xfinitywifiEnable | grep value | cut -f3 -d : | cut -f2 -d" "`

if [ "$thisWAN_TYPE" != "EPON" ] && [ "$HOTSPOT_ENABLE" = "true" ]
then
    DHCP_ARP_PID=`pidof hotspot_arpd`
    if [ "$DHCP_ARP_PID" = "" ] && [ -f /tmp/hotspot_arpd_up ]; then
        echo_t "RDKB_PROCESS_CRASHED : DhcpArp_process is not running, need restart"
        resetNeeded "" hotspot_arpd
    fi
    
    HOTSPOT_PID=`pidof CcspHotspot`
	if [ "$HOTSPOT_PID" = "" ]; then
		echo_t "RDKB_PROCESS_CRASHED : CcspHotspot_process is not running, need restart"
		resetNeeded "" CcspHotspot
	fi
fi

case $SELFHEAL_TYPE in
    "BASE")
        if [ "$WAN_TYPE" != "EPON" ] && [ "$HOTSPOT_ENABLE" = "true" ]
        then
            #When Xfinitywifi is enabled, l2sd0.102 and l2sd0.103 should be present.
            #If they are not present below code shall re-create them
            #l2sd0.102 case , also adding a strict rule that they are up, since some
            #devices we observed l2sd0 not up


            ifconfig | grep l2sd0.102
            if [ $? == 1 ]; then
                echo_t "XfinityWifi is enabled, but l2sd0.102 interface is not created try creating it"

                Interface=`psmcli get dmsb.l2net.3.Members.WiFi`
                if [ "$Interface" == "" ]; then
                    echo_t "PSM value(ath4) is missing for l2sd0.102"
                    psmcli set dmsb.l2net.3.Members.WiFi ath4
                fi

                sysevent set multinet_3-status stopped
                $UTOPIA_PATH/service_multinet_exec multinet-start 3
                ifconfig l2sd0.102 up
                ifconfig | grep l2sd0.102
                if [ $? == 1 ]; then
                    echo_t "l2sd0.102 is not created at First Retry, try again after 2 sec"
                    sleep 2
                    sysevent set multinet_3-status stopped
                    $UTOPIA_PATH/service_multinet_exec multinet-start 3
                    ifconfig l2sd0.102 up
                    ifconfig | grep l2sd0.102
                    if [ $? == 1 ]; then
                        echo_t "[RDKB_PLATFORM_ERROR] : l2sd0.102 is not created after Second Retry, no more retries !!!"
                    fi
                else
                    echo_t "[RDKB_PLATFORM_ERROR] : l2sd0.102 created at First Retry itself"
                fi
            else
                echo_t "XfinityWifi is enabled and l2sd0.102 is present"
            fi

            #l2sd0.103 case


            ifconfig | grep l2sd0.103
            if [ $? == 1 ]; then
                echo_t "XfinityWifi is enabled, but l2sd0.103 interface is not created try creatig it"

                Interface=`psmcli get dmsb.l2net.4.Members.WiFi`
                if [ "$Interface" == "" ]; then
                    echo_t "PSM value(ath5) is missing for l2sd0.103"
                    psmcli set dmsb.l2net.4.Members.WiFi ath5
                fi

                sysevent set multinet_4-status stopped
                $UTOPIA_PATH/service_multinet_exec multinet-start 4
                ifconfig l2sd0.103 up
                ifconfig | grep l2sd0.103
                if [ $? == 1 ]; then
                    echo_t "l2sd0.103 is not created at First Retry, try again after 2 sec"
                    sleep 2
                    sysevent set multinet_4-status stopped
                    $UTOPIA_PATH/service_multinet_exec multinet-start 4
                    ifconfig l2sd0.103 up
                    ifconfig | grep l2sd0.103
                    if [ $? == 1 ]; then
                        echo_t "[RDKB_PLATFORM_ERROR] : l2sd0.103 is not created after Second Retry, no more retries !!!"
                    fi
                else
                    echo_t "[RDKB_PLATFORM_ERROR] : l2sd0.103 created at First Retry itself"
                fi
            else
                echo_t "Xfinitywifi is enabled and l2sd0.103 is present"
            fi

            #RDKB-16889: We need to make sure Xfinity hotspot Vlan IDs are attached to the bridges
            #if found not attached , then add the device to bridges
            for index in 2 3 4 5
            do
                grePresent=`ifconfig -a | grep $grePrefix.10$index`
                if [ -n "$grePresent" ]; then
                    vlanAdded=`brctl show $brlanPrefix$index | grep $l2sd0Prefix.10$index`
                    if [ -z "$vlanAdded" ]; then
                        echo_t "[RDKB_PLATFORM_ERROR] : Vlan not added $l2sd0Prefix.10$index"
                        brctl addif $brlanPrefix$index $l2sd0Prefix.10$index
                    fi
                fi
            done

            SECURED_24=`dmcli eRT getv Device.WiFi.SSID.9.Enable | grep value | cut -f3 -d : | cut -f2 -d" "`
            SECURED_5=`dmcli eRT getv Device.WiFi.SSID.10.Enable | grep value | cut -f3 -d : | cut -f2 -d" "`

            #Check for Secured Xfinity hotspot briges and associate them properly if
            #not proper
            #l2sd0.103 case

            #Secured Xfinity 2.4
            grePresent=`ifconfig -a | grep $grePrefix.104`
            if [ -n "$grePresent" ]; then
                ifconfig | grep l2sd0.104
                if [ $? == 1 ]; then
                    echo_t "XfinityWifi is enabled Secured gre created, but l2sd0.104 interface is not created try creatig it"
                    sysevent set multinet_7-status stopped
                    $UTOPIA_PATH/service_multinet_exec multinet-start 7
                    ifconfig l2sd0.104 up
                    ifconfig | grep l2sd0.104
                    if [ $? == 1 ]; then
                        echo_t "l2sd0.104 is not created at First Retry, try again after 2 sec"
                        sleep 2
                        sysevent set multinet_7-status stopped
                        $UTOPIA_PATH/service_multinet_exec multinet-start 7
                        ifconfig l2sd0.104 up
                        ifconfig | grep l2sd0.104
                        if [ $? == 1 ]; then
                            echo_t "[RDKB_PLATFORM_ERROR] : l2sd0.104 is not created after Second Retry, no more retries !!!"
                        fi
                    else
                        echo_t "[RDKB_PLATFORM_ERROR] : l2sd0.104 created at First Retry itself"
                    fi
                else
                    echo_t "Xfinitywifi is enabled and l2sd0.104 is present"
                fi
            else
                #RDKB-17221: In some rare devices we found though Xfinity secured ssid enabled, but it did'nt create the gre tunnels
                #but all secured SSIDs Vaps were up and system remained in this state for long not allowing clients to
                #connect
                if [ "$SECURED_24" = "true" ]; then
                    echo_t "[RDKB_PLATFORM_ERROR] :XfinityWifi: Secured SSID 2.4 is enabled but gre tunnels not present, restoring it"
                    sysevent set multinet_7-status stopped
                    $UTOPIA_PATH/service_multinet_exec multinet-start 7
                fi
            fi

            #Secured Xfinity 5
            grePresent=`ifconfig -a | grep $grePrefix.105`
            if [ -n "$grePresent" ]; then
                ifconfig | grep l2sd0.105
                if [ $? == 1 ]; then
                    echo_t "XfinityWifi is enabled Secured gre created, but l2sd0.105 interface is not created try creatig it"
                    sysevent set multinet_8-status stopped
                    $UTOPIA_PATH/service_multinet_exec multinet-start 8
                    ifconfig l2sd0.105 up
                    ifconfig | grep l2sd0.105
                    if [ $? == 1 ]; then
                        echo_t "l2sd0.105 is not created at First Retry, try again after 2 sec"
                        sleep 2
                        sysevent set multinet_8-status stopped
                        $UTOPIA_PATH/service_multinet_exec multinet-start 8
                        ifconfig l2sd0.105 up
                        ifconfig | grep l2sd0.105
                        if [ $? == 1 ]; then
                            echo_t "[RDKB_PLATFORM_ERROR] : l2sd0.105 is not created after Second Retry, no more retries !!!"
                        fi
                    else
                        echo_t "[RDKB_PLATFORM_ERROR] : l2sd0.105 created at First Retry itself"
                    fi
                else
                    echo_t "Xfinitywifi is enabled and l2sd0.105 is present"
                fi
            else
                if [ "$SECURED_5" = "true" ]; then
                    echo_t "[RDKB_PLATFORM_ERROR] :XfinityWifi: Secured SSID 5GHz is enabled but gre tunnels not present, restoring it"
                    sysevent set multinet_8-status stopped
                    $UTOPIA_PATH/service_multinet_exec multinet-start 8
                fi
            fi
        fi  # [ "$WAN_TYPE" != "EPON" ] && [ "$HOTSPOT_ENABLE" = "true" ]
    ;;
    "TCCBR")
    ;;
    "SYSTEMD")
    ;;
esac

case $SELFHEAL_TYPE in
    "BASE")
        # TODO: move DROPBEAR BASE code with TCCBR,SYSTEMD code!
    ;;
    "TCCBR")
        #Check dropbear is alive to do rsync/scp to/fro ATOM
        if [ "$ARM_INTERFACE_IP" != "" ]
        then
            DROPBEAR_ENABLE=`ps -ww | grep dropbear | grep $ARM_INTERFACE_IP`
            if [ "$DROPBEAR_ENABLE" == "" ]
            then
                echo_t "RDKB_PROCESS_CRASHED : rsync_dropbear_process is not running, need restart"
                dropbear -E -s -p $ARM_INTERFACE_IP:22 > /dev/null 2>&1
            fi
        fi
    ;;
    "SYSTEMD")
      if [ "$BOX_TYPE" != "HUB4" ]; then
        #Checking dropbear PID
        DROPBEAR_PID=`pidof dropbear`
        if [ "$DROPBEAR_PID" = "" ]; then
            echo_t "RDKB_PROCESS_CRASHED : dropbear_process is not running, restarting it"
            sh /etc/utopia/service.d/service_sshd.sh sshd-restart &
        fi
      fi
    ;;
esac

case $SELFHEAL_TYPE in
    "BASE")
        # TODO: move LIGHTTPD_PID BASE code with TCCBR,SYSTEMD code!
    ;;
    "TCCBR"|"SYSTEMD")
        # Checking lighttpd PID
        LIGHTTPD_PID=`pidof lighttpd`
        WEBGUI_PID=`ps | grep webgui.sh | grep -v grep | awk {'print $1'}`
        if [ "$LIGHTTPD_PID" = "" ]; then
            if [ "$WEBGUI_PID" != "" ]; then
                if [ -f /tmp/WEBGUI_"$WEBGUI_PID" ]; then
                    echo_t "WEBGUI is in hung state, restarting it"
                    kill -9 "$WEBGUI_PID"
                    rm /tmp/WEBGUI_*

                    isPortKilled=`netstat -anp | grep 21515`
                    if [ "$isPortKilled" != "" ]
                    then
                        echo_t "Port 21515 is still alive. Killing processes associated to 21515"
                        fuser -k 21515/tcp
                    fi
                    sh /etc/webgui.sh
                else
                    for f in /tmp/WEBGUI_*; do
                      if [ -f "$f" ]; then  #TODO: file test not needed since we just got list of filenames from shell?
                         rm "$f"
                      fi
                    done
                    touch /tmp/WEBGUI_"$WEBGUI_PID"
                    echo_t "WEBGUI is running with pid $WEBGUI_PID"
                fi
            else
                isPortKilled=`netstat -anp | grep 21515`
                if [ "$isPortKilled" != "" ]
                then
                    echo_t "Port 21515 is still alive. Killing processes associated to 21515"
                    fuser -k 21515/tcp
                fi
                echo_t "RDKB_PROCESS_CRASHED : lighttpd is not running, restarting it"
                #lighttpd -f $LIGHTTPD_CONF
                sh /etc/webgui.sh
            fi
        fi
    ;;
esac

case $SELFHEAL_TYPE in
    "BASE")
	if [ "$BOX_TYPE" != "rpi" ]; then
        _start_parodus_() {
            echo_t "RDKB_PROCESS_CRASHED : parodus process is not running, need restart"
            echo_t "Check parodusCmd.cmd in /tmp"
            if [ -e /tmp/parodusCmd.cmd ]; then
                echo_t "parodusCmd.cmd exists in tmp, but deleting it to recreate and fetch new values"
                rm -rf /tmp/parodusCmd.cmd
                #start parodus
                /usr/bin/parodusStart &
                echo_t "Started parodusStart in background"
            else
                echo_t "parodusCmd.cmd does not exist in tmp, trying to start parodus"
                /usr/bin/parodusStart &
            fi
        }
	fi ## Not rpi 
    ;;
    "TCCBR")
    ;;
    "SYSTEMD")
    ;;
esac

# Checking for parodus connection stuck issue
# Checking parodus PID
PARODUS_PID=`pidof parodus`
case $SELFHEAL_TYPE in
    "BASE")
	if [ "$BOX_TYPE" == "rpi" ]; then
		if [ "$PARODUS_PID" = "" ]; then
			sh /lib/rdk/parodus_start.sh
		fi
	WEBPA_PID=`pidof webpa`
		if [ "$WEBPA_PID" = "" ]; then
			/usr/bin/webpa &
		fi
	else
        PARODUSSTART_PID=`pidof parodusStart`
        if [ "$PARODUS_PID" = "" ] && [ "$PARODUSSTART_PID" = "" ]; then
            _start_parodus_
            thisPARODUS_PID=""    # avoid executing 'already-running' code below
        fi
	fi
    ;;
    "TCCBR"|"SYSTEMD")
        thisPARODUS_PID="$PARODUS_PID"
    ;;
esac
if [ "$thisPARODUS_PID" != "" ] && [ "$BOX_TYPE" != "rpi" ]; then
    # parodus process is running,
    kill_parodus_msg=""
    # check if parodus is stuck in connecting
    if [ "$kill_parodus_msg" = "" ] && [ -f $PARCONNHEALTH_PATH ]; then
        wan_status=`sysevent get wan-status`
        if [ "$wan_status" = "started" ]; then
            time_line=`awk '/^\{START=[0-9]+\}$/' $PARCONNHEALTH_PATH`
        else
            time_line=""
        fi
        start_conn_time=`echo "$time_line" | tr -d "}" | cut -d= -f2`
        if [[ "$start_conn_time" != "" ]]; then
            echo_t "Parodus connecting" 
            time_limit=$(($start_conn_time+900))
            time_now=`date +%s`
            time_now_val=$(($time_now+0))
            if [ $time_now_val -ge $time_limit ]; then
                # parodus connection health file has a recorded
                # time stamp that is > 15 minutes old
                kill_parodus_msg="Parodus Connection TimeStamp Expired."
            fi
        fi
    fi
    if [ "$kill_parodus_msg" != "" ] && [ "$BOX_TYPE" != "rpi" ]; then
        case $SELFHEAL_TYPE in
            "BASE")
                echo_t "$kill_parodus_msg Killing parodus process."
                # want to generate minidump for further analysis hence using signal 11
                kill -11 `pidof parodus`
                sleep 1
                _start_parodus_
            ;;
            "TCCBR"|"SYSTEMD")
                echo "[`getDateTime`] $kill_parodus_msg Killing parodus process."
                # want to generate minidump for further analysis hence using signal 11
                systemctl kill --signal=11 parodus.service
            ;;
        esac
    fi
fi

case $SELFHEAL_TYPE in
    "BASE")
        # TODO: move DROPBEAR BASE code with TCCBR,SYSTEMD code!
        #Check dropbear is alive to do rsync/scp to/fro ATOM
        if [ "$ARM_INTERFACE_IP" != "" ] && [ "$BOX_TYPE" != "rpi" ]
        then
            DROPBEAR_ENABLE=`ps -w | grep dropbear | grep $ARM_INTERFACE_IP`
            if [ "$DROPBEAR_ENABLE" == "" ]
            then
                echo_t "RDKB_PROCESS_CRASHED : rsync_dropbear_process is not running, need restart"
                DROPBEAR_PARAMS_1="/tmp/.dropbear/dropcfg1$$"
                DROPBEAR_PARAMS_2="/tmp/.dropbear/dropcfg2$$"
                if [ ! -d '/tmp/.dropbear' ]; then
                    mkdir -p /tmp/.dropbear
                fi
                getConfigFile $DROPBEAR_PARAMS_1
                getConfigFile $DROPBEAR_PARAMS_2
                dropbear -r $DROPBEAR_PARAMS_1 -r $DROPBEAR_PARAMS_2 -E -s -p $ARM_INTERFACE_IP:22 -P /var/run/dropbear_ipc.pid > /dev/null 2>&1
            fi
            rm -rf /tmp/.dropbear
        fi
    ;;
    "TCCBR")
    ;;
    "SYSTEMD")
    ;;
esac

case $SELFHEAL_TYPE in
    "BASE")
        # TODO: move LIGHTTPD_PID BASE code with TCCBR,SYSTEMD code!
        # Checking lighttpd PID
        LIGHTTPD_PID=`pidof lighttpd`
        WEBGUI_PID=`ps | grep webgui.sh | grep -v grep | awk {'print $1'}`
        if [ "$LIGHTTPD_PID" = "" ]; then
            if [ "$WEBGUI_PID" != "" ]; then
                if [ -f /tmp/WEBGUI_"$WEBGUI_PID" ]; then
                    echo_t "WEBGUI is in hung state, restarting it"
                    kill -9 "$WEBGUI_PID"
                    rm /tmp/WEBGUI_*

                    isPortKilled=`netstat -anp | grep 21515`
                    if [ "$isPortKilled" != "" ]
                    then
                        echo_t "Port 21515 is still alive. Killing processes associated to 21515"
                        fuser -k 21515/tcp
                    fi
                    sh /etc/webgui.sh
                else
                    for f in /tmp/WEBGUI_*; do
                      if [ -f "$f" ]; then  #TODO: file test not needed since we just got list of filenames from shell?
                         rm "$f"
                      fi
                    done
                    touch /tmp/WEBGUI_"$WEBGUI_PID"
                    echo_t "WEBGUI is running with pid $WEBGUI_PID"
                fi
            else
                isPortKilled=`netstat -anp | grep 21515`
                if [ "$isPortKilled" != "" ]
                then
                   echo_t "Port 21515 is still alive. Killing processes associated to 21515"
                   fuser -k 21515/tcp
                fi
                echo_t "RDKB_PROCESS_CRASHED : lighttpd is not running, restarting it"
                #lighttpd -f $LIGHTTPD_CONF
                sh /etc/webgui.sh
            fi
        fi
    ;;
    "TCCBR")
    ;;
    "SYSTEMD")
    ;;
esac

case $SELFHEAL_TYPE in
    "BASE")
        # TODO: move acsd,CORE_TMP BASE code with TCCBR,SYSTEMD code!
    ;;
    "TCCBR")
        #Checking if acsd is running and whether acsd core is generated or not
        if [ "$BOX_TYPE" = "TCCBR" ]; then
            ACSD_PID=`pidof acsd`
            if [ "$ACSD_PID" = ""  ];then
                echo_t "[ACSD_CRASH/RESTART] : ACSD is not running "
            fi

            ACSD_CORE=`ls /tmp | grep core.prog_acsd`
            if [ "$ACSD_CORE" != "" ]; then
                echo_t "[ACSD_CRASH/RESTART] : ACSD core has been generated inside /tmp :  $ACSD_CORE"
                ACSD_CORE_COUNT=`ls /tmp | grep core.prog_acsd | wc -w`
                echo_t "[ACSD_CRASH/RESTART] : Number of ACSD cores created inside /tmp  are : $ACSD_CORE_COUNT"
            fi
        fi

        #Checking Wheteher any core is generated inside /tmp folder
        CORE_TMP=`ls /tmp | grep core.`
        if [ "$CORE_TMP" != "" ]; then
            echo_t "[PROCESS_CRASH] : core has been generated inside /tmp :  $CORE_TMP"
            CORE_COUNT=`ls /tmp | grep core. | wc -w`
            echo_t "[PROCESS_CRASH] : Number of cores created inside /tmp are : $CORE_COUNT"
        fi
    ;;
    "SYSTEMD")
        #Checking if acsd is running and whether acsd core is generated or not
        if [[ "$MODEL_NUM" = "PX5001" || "$MODEL_NUM" = "PX5001B" ]]; then
            ACSD_PID=`pidof acsd`
            if [ "$ACSD_PID" = ""  ];then
                echo_t "[ACSD_CRASH/RESTART] : ACSD is not running "
            fi

            ACSD_CORE=`ls /tmp | grep core.acsd`
            if [ "$ACSD_CORE" != "" ]; then
                echo_t "[ACSD_CRASH/RESTART] : ACSD core has been generated inside /tmp :  $ACSD_CORE"
                ACSD_CORE_COUNT=`ls /tmp | grep core.acsd | wc -w`
                echo_t "[ACSD_CRASH/RESTART] : Number of ACSD cores created inside /tmp  are : $ACSD_CORE_COUNT"
            fi
        fi

        #Checking Wheteher any core is generated inside /tmp folder
        CORE_TMP=`ls /tmp | grep core.`
        if [ "$CORE_TMP" != "" ]; then
            echo_t "[PROCESS_CRASH] : core has been generated inside /tmp :  $CORE_TMP"
            CORE_COUNT=`ls /tmp | grep core. | wc -w`
            echo_t "[PROCESS_CRASH] : Number of cores created inside /tmp are : $CORE_COUNT"
        fi
    ;;
esac

# Checking syseventd PID
SYSEVENT_PID=`pidof syseventd`
if [ "$SYSEVENT_PID" == "" ]
then
    if [ ! -f "$SyseventdCrashed"  ]
    then
        echo_t "[RDKB_PROCESS_CRASHED] : syseventd is crashed, need to reboot the device in maintanance window."
        touch $SyseventdCrashed
        case $SELFHEAL_TYPE in
            "BASE"|"SYSTEMD")
                echo_t "Setting Last reboot reason"
                dmcli eRT setv Device.DeviceInfo.X_RDKCENTRAL-COM_LastRebootReason string Syseventd_crash
                dmcli eRT setv Device.DeviceInfo.X_RDKCENTRAL-COM_LastRebootCounter int 1
            ;;
            "TCCBR")
            ;;
        esac
    fi
    rebootDeviceNeeded=1
    if [ "$BOX_TYPE" == "rpi" ]; then
	reboot
    fi
fi


case $SELFHEAL_TYPE in
    "BASE")
        # Checking snmp master PID
        if [ "$BOX_TYPE" = "XB3" ]; then
            SNMP_MASTER_PID=`pidof snmp_agent_cm`
            if [ "$SNMP_MASTER_PID" == "" ] && [  ! -f "$SNMPMASTERCRASHED"  ];then
                echo_t "[RDKB_PROCESS_CRASHED] : snmp_agent_cm process crashed"
                touch $SNMPMASTERCRASHED
            fi
        fi

        if [ -e /tmp/atom_ro ]; then
            reboot_needed_atom_ro=1
            rebootDeviceNeeded=1
        fi
    ;;
    "TCCBR")
    ;;
    "SYSTEMD")
    ;;
esac

case $SELFHEAL_TYPE in
    "BASE")
        # TODO: move acsd,CORE_TMP BASE code with TCCBR,SYSTEMD code!
        #Checking if acsd is running and whether acsd core is generated or not
        if [ "$BOX_TYPE" = "TCCBR" ]; then
            ACSD_PID=`pidof acsd`
            if [ "$ACSD_PID" = ""  ];then
                echo_t "[ACSD_CRASH/RESTART] : ACSD is not running "
            fi

            ACSD_CORE=`ls /tmp | grep core.prog_acsd`
            if [ "$ACSD_CORE" != "" ]; then
                echo_t "[ACSD_CRASH/RESTART] : ACSD core has been generated inside /tmp :  $ACSD_CORE"
                ACSD_CORE_COUNT=`ls /tmp | grep core.prog_acsd | wc -w`
                echo_t "[ACSD_CRASH/RESTART] : Number of ACSD cores created inside /tmp  are : $ACSD_CORE_COUNT"
            fi
        fi

        #Checking Wheteher any core is generated inside /tmp folder
        CORE_TMP=`ls /tmp | grep core.`
        if [ "$CORE_TMP" != "" ]; then
            echo_t "[PROCESS_CRASH] : core has been generated inside /tmp :  $CORE_TMP"
            CORE_COUNT=`ls /tmp | grep core. | wc -w`
            echo_t "[PROCESS_CRASH] : Number of cores created inside /tmp are : $CORE_COUNT"
        fi
    ;;
    "TCCBR")
    ;;
    "SYSTEMD")
    ;;
esac

case $SELFHEAL_TYPE in
    "BASE")
        # Checking whether brlan0 and l2sd0.100 are created properly , if not recreate it
        if [ "$WAN_TYPE" != "EPON" ]; then
            check_device_mode=`dmcli eRT getv Device.X_CISCO_COM_DeviceControl.LanManagementEntry.1.LanMode`
            check_param_get_succeed=`echo $check_device_mode | grep "Execution succeed"`
            if [ "$check_param_get_succeed" != "" ]
            then
                check_device_in_router_mode=`echo $check_param_get_succeed | grep router`
                if [ "$check_device_in_router_mode" != "" ]
                then
                    check_if_brlan0_created=`ifconfig | grep brlan0`
                    check_if_brlan0_up=`ifconfig brlan0 | grep UP`
                    check_if_brlan0_hasip=`ifconfig brlan0 | grep "inet addr"`
                    check_if_l2sd0_100_created=`ifconfig | grep l2sd0.100`
                    check_if_l2sd0_100_up=`ifconfig l2sd0.100 | grep UP `
                    if [ "$check_if_brlan0_created" = "" ] || [ "$check_if_brlan0_up" = "" ] || [ "$check_if_brlan0_hasip" = "" ] || [ "$check_if_l2sd0_100_created" = "" ] || [ "$check_if_l2sd0_100_up" = "" ]
                    then
                        echo_t "[RDKB_PLATFORM_ERROR] : Either brlan0 or l2sd0.100 is not completely up, setting event to recreate vlan and brlan0 interface"
                        echo_t "[RDKB_SELFHEAL_BOOTUP] : brlan0 and l2sd0.100 o/p "
                        ifconfig brlan0;ifconfig l2sd0.100; brctl show
                        logNetworkInfo

                        ipv4_status=`sysevent get ipv4_4-status`
                        lan_status=`sysevent get lan-status`

                        if [ "$lan_status" != "started" ]
                        then
                            if [ "$ipv4_status" = "" ] || [ "$ipv4_status" = "down" ]
                            then
                                echo_t "[RDKB_SELFHEAL] : ipv4_4-status is not set or lan is not started, setting lan-start event"
                                sysevent set lan-start
                                sleep 5
                            fi
                        fi
			if [ "$BOX_TYPE" != "rpi" ] 
			then
                        if [ "$check_if_brlan0_created" = "" ] && [ "$check_if_l2sd0_100_created" = "" ]; then
                            /etc/utopia/registration.d/02_multinet restart
                        fi

                        sysevent set multinet-down 1
                        sleep 5
                        sysevent set multinet-up 1
                        sleep 30
			fi
                    fi

                fi
            else
                echo_t "[RDKB_PLATFORM_ERROR] : Something went wrong while fetching device mode "
            fi


            # Checking whether brlan1 and l2sd0.101 interface are created properly
            if [ "$thisIS_BCI" != "yes" ] && [ "$BOX_TYPE" != "rpi" ]; then
                check_if_brlan1_created=`ifconfig | grep brlan1`
                check_if_brlan1_up=`ifconfig brlan1 | grep UP`
                check_if_brlan1_hasip=`ifconfig brlan1 | grep "inet addr"`
                check_if_l2sd0_101_created=`ifconfig | grep l2sd0.101`
                check_if_l2sd0_101_up=`ifconfig l2sd0.101 | grep UP `

                if [ "$check_if_brlan1_created" = "" ] || [ "$check_if_brlan1_up" = "" ] || [ "$check_if_brlan1_hasip" = "" ] || [ "$check_if_l2sd0_101_created" = "" ] || [ "$check_if_l2sd0_101_up" = "" ]
                then
                    echo_t "[RDKB_PLATFORM_ERROR] : Either brlan1 or l2sd0.101 is not completely up, setting event to recreate vlan and brlan1 interface"
                    echo_t "[RDKB_SELFHEAL_BOOTUP] : brlan1 and l2sd0.101 o/p "
                    ifconfig brlan1;ifconfig l2sd0.101; brctl show
                    ipv5_status=`sysevent get ipv4_5-status`
                    lan_l3net=`sysevent get homesecurity_lan_l3net`

                    if [ "$lan_l3net" != "" ]
                    then
                        if [ "$ipv5_status" = "" ] || [ "$ipv5_status" = "down" ]
                        then
                            echo_t "[RDKB_SELFHEAL] : ipv5_4-status is not set , setting event to create homesecurity lan"
                            sysevent set ipv4-up $lan_l3net
                            sleep 5
                        fi
                    fi

                    if [ "$check_if_brlan1_created" = "" ] && [ "$check_if_l2sd0_101_created" = "" ] ; then
                        /etc/utopia/registration.d/02_multinet restart
                    fi

                    sysevent set multinet-down 2
                    sleep 5
                    sysevent set multinet-up 2
                    sleep 10
                fi
            fi
        fi
    ;;
    "TCCBR")
        # Checking whether brlan0 created properly , if not recreate it
        lanSelfheal=`sysevent get lan_selfheal`
        echo_t "[RDKB_SELFHEAL] : Value of lanSelfheal : $lanSelfheal"
        if [ "$lanSelfheal" != "done" ]
        then
            check_device_mode=`dmcli eRT getv Device.X_CISCO_COM_DeviceControl.LanManagementEntry.1.LanMode`
            check_param_get_succeed=`echo $check_device_mode | grep "Execution succeed"`
            if [ "$check_param_get_succeed" != "" ]
            then
                check_device_in_router_mode=`echo $check_param_get_succeed | grep router`
                if [ "$check_device_in_router_mode" != "" ]
                then
                    check_if_brlan0_created=`ifconfig | grep brlan0`
                    check_if_brlan0_up=`ifconfig brlan0 | grep UP`
                    check_if_brlan0_hasip=`ifconfig brlan0 | grep "inet addr"`
                    if [ "$check_if_brlan0_created" = "" ] || [ "$check_if_brlan0_up" = "" ] || [ "$check_if_brlan0_hasip" = "" ]
                    then
                        echo_t "[RDKB_PLATFORM_ERROR] : brlan0 is not completely up, setting event to recreate brlan0 interface"
                        logNetworkInfo

                        ipv4_status=`sysevent get ipv4_4-status`
                        lan_status=`sysevent get lan-status`

                        if [ "$lan_status" != "started" ]
                        then
                            if [ "$ipv4_status" = "" ] || [ "$ipv4_status" = "down" ]
                            then
                                echo_t "[RDKB_SELFHEAL] : ipv4_4-status is not set or lan is not started, setting lan-start event"
                                sysevent set lan-start
                                sleep 5
                            fi
                        fi

                        if [ "$check_if_brlan0_created" = "" ]; then
                            /etc/utopia/registration.d/02_multinet restart
                        fi

                        sysevent set multinet-down 1
                        sleep 5
                        sysevent set multinet-up 1
                        sleep 30
                        sysevent set lan_selfheal done
                    fi

                fi
            else
                echo_t "[RDKB_PLATFORM_ERROR] : Something went wrong while fetching device mode "
            fi
        else
            echo_t "[RDKB_SELFHEAL] : brlan0 already restarted. Not restarting again"
        fi
    ;;
    "SYSTEMD")
      if [ "$BOX_TYPE" != "HUB4" ] && [ "$BOX_TYPE" != "rpi" ]; then
        # Checking whether brlan0 is created properly , if not recreate it
        lanSelfheal=`sysevent get lan_selfheal`
        echo_t "[RDKB_SELFHEAL] : Value of lanSelfheal : $lanSelfheal"
        if [ "$lanSelfheal" != "done" ]
        then
            # Check device is in router mode
            # Get from syscfg instead of dmcli for performance reasons
            check_device_in_bridge_mode=`syscfg get bridge_mode`
            if [ "$check_device_in_bridge_mode" == "0" ]
            then
                check_if_brlan0_created=`ifconfig | grep brlan0`
                check_if_brlan0_up=`ifconfig brlan0 | grep UP`
                check_if_brlan0_hasip=`ifconfig brlan0 | grep "inet addr"`
                if [ "$check_if_brlan0_created" = "" ] || [ "$check_if_brlan0_up" = "" ] || [ "$check_if_brlan0_hasip" = "" ]
                then
                    echo_t "[RDKB_PLATFORM_ERROR] : brlan0 is not completely up, setting event to recreate vlan and brlan0 interface"
                    logNetworkInfo

                    ipv4_status=`sysevent get ipv4_4-status`
                    lan_status=`sysevent get lan-status`

                    if [ "$lan_status" != "started" ]
                    then
                        if [ "$ipv4_status" = "" ] || [ "$ipv4_status" = "down" ]
                        then
                            echo_t "[RDKB_SELFHEAL] : ipv4_4-status is not set or lan is not started, setting lan-start event"
                            sysevent set lan-start
                            sleep 5
                        fi
                    fi

                    if [ "$check_if_brlan0_created" = "" ]; then
                        /etc/utopia/registration.d/02_multinet restart
                    fi

                    sysevent set multinet-down 1
                    sleep 5
                    sysevent set multinet-up 1
                    sleep 30
                    sysevent set lan_selfheal done
                fi

            fi
        else
            echo_t "[RDKB_SELFHEAL] : brlan0 already restarted. Not restarting again"
        fi

        # Checking whether brlan1 interface is created properly

        l3netRestart=`sysevent get l3net_selfheal`
        echo_t "[RDKB_SELFHEAL] : Value of l3net_selfheal : $l3netRestart"

        if [ "$l3netRestart" != "done" ]
        then

            check_if_brlan1_created=`ifconfig | grep brlan1`
            check_if_brlan1_up=`ifconfig brlan1 | grep UP`
            check_if_brlan1_hasip=`ifconfig brlan1 | grep "inet addr"`

            if [ "$check_if_brlan1_created" = "" ] || [ "$check_if_brlan1_up" = "" ] || [ "$check_if_brlan1_hasip" = "" ]
            then
                echo_t "[RDKB_PLATFORM_ERROR] : brlan1 is not completely up, setting event to recreate vlan and brlan1 interface"

                ipv5_status=`sysevent get ipv4_5-status`
                lan_l3net=`sysevent get homesecurity_lan_l3net`

                if [ "$lan_l3net" != "" ]
                then
                    if [ "$ipv5_status" = "" ] || [ "$ipv5_status" = "down" ]
                    then
                        echo_t "[RDKB_SELFHEAL] : ipv5_4-status is not set , setting event to create homesecurity lan"
                        sysevent set ipv4-up $lan_l3net
                        sleep 5
                    fi
                fi

                if [ "$check_if_brlan1_created" = "" ]; then
                    /etc/utopia/registration.d/02_multinet restart
                fi

                sysevent set multinet-down 2
                sleep 5
                sysevent set multinet-up 2
                sleep 10
                sysevent set l3net_selfheal done
            fi
        else
            echo_t "[RDKB_SELFHEAL] : brlan1 already restarted. Not restarting again"
        fi

        # Test to make sure that if mesh is enabled the backhaul tunnels are attached to the bridges
        MESH_ENABLE=`dmcli eRT getv Device.DeviceInfo.X_RDKCENTRAL-COM_xOpsDeviceMgmt.Mesh.Enable | grep value | cut -f3 -d : | cut -f2 -d" "`
        if [ "$MESH_ENABLE" = "true" ]
        then
            echo_t "[RDKB_SELFHEAL] : Mesh is enabled, test if tunnels are attached to bridges"

            # Fetch mesh tunnels from the brlan0 bridge if they exist
            brctl0_ifaces=`brctl show brlan0 | egrep "pgd"`
            br0_ifaces=`ifconfig | egrep "^pgd" | egrep "\.100" | awk '{print $1}'`

            for ifn in $br0_ifaces; do
                brFound="false"

                for br in $brctl0_ifaces; do
                    if [ "$br" == "$ifn" ]; then
                        brFound="true"
                    fi
                done
                if [ "$brFound" == "false" ]; then
                    echo_t "[RDKB_SELFHEAL] : Mesh bridge $ifn missing, adding iface to brlan0"
                    brctl addif brlan0 $ifn;
                fi
            done

            # Fetch mesh tunnels from the brlan1 bridge if they exist
            if [ "$thisIS_BCI" != "yes" ]; then
                brctl1_ifaces=`brctl show brlan1 | egrep "pgd"`
                br1_ifaces=`ifconfig | egrep "^pgd" | egrep "\.101" | awk '{print $1}'`

                for ifn in $br1_ifaces; do
                    brFound="false"

                    for br in $brctl1_ifaces; do
                        if [ "$br" == "$ifn" ]; then
                            brFound="true"
                        fi
                    done
                    if [ "$brFound" == "false" ]; then
                        echo_t "[RDKB_SELFHEAL] : Mesh bridge $ifn missing, adding iface to brlan1"
                        brctl addif brlan1 $ifn;
                    fi
                done
            fi
        fi
     fi #Not HUB4
    ;;
esac


#!!! TODO: merge this $SELFHEAL_TYPE block !!!
case $SELFHEAL_TYPE in
    "BASE")
        SSID_DISABLED=0
        BR_MODE=0
        ssidEnable=`dmcli eRT getv Device.WiFi.SSID.2.Enable`
        ssidExecution=`echo $ssidEnable | grep "Execution succeed"`
        if [ "$ssidExecution" != "" ]
        then
            isEnabled=`echo $ssidEnable | grep "false"`
            if [ "$isEnabled" != "" ]
            then
                SSID_DISABLED=1
                echo_t "[RDKB_SELFHEAL] : SSID 5GHZ is disabled"
            fi
        else
            destinationError=`echo $ssidEnable | grep "Can't find destination component"`
            if [ "$destinationError" != "" ]
            then
                echo_t "[RDKB_PLATFORM_ERROR] : Parameter cannot be found on WiFi subsystem"
            else
                echo_t "[RDKB_PLATFORM_ERROR] : Something went wrong while checking 5G Enable"
                echo "$ssidEnable"
            fi
        fi
    ;;
    "TCCBR")
        if [ "$WiFi_Flag" == "false" ]; then
            SSID_DISABLED=0
            BR_MODE=0
            ssidEnable=`dmcli eRT getv Device.WiFi.SSID.2.Enable`
            ssidExecution=`echo $ssidEnable | grep "Execution succeed"`
            if [ "$ssidExecution" != "" ]
            then
                isEnabled=`echo $ssidEnable | grep "false"`
                if [ "$isEnabled" != "" ]
                then
                    SSID_DISABLED=1
                    echo_t "[RDKB_SELFHEAL] : SSID 5GHZ is disabled"
                fi
            else
                destinationError=`echo $ssidEnable | grep "Can't find destination component"`
                if [ "$destinationError" != "" ]
                then
                    echo_t "[RDKB_PLATFORM_ERROR] : Parameter cannot be found on WiFi subsystem"
                else
                    echo_t "[RDKB_PLATFORM_ERROR] : Something went wrong while checking 5G Enable"
                    echo "$ssidEnable"
                fi
            fi
        fi
    ;;
    "SYSTEMD")
        #Selfheal will run after 15mins of bootup, then by now the WIFI initialization must have
        #completed, so if still wifi_initilization not done, we have to recover the WIFI
        #Restart the WIFI if initialization is not done with in 15mins of poweron.
        if [ "$WiFi_Flag" == "false" ]; then
            SSID_DISABLED=0
            BR_MODE=0
            if [ -f "/tmp/wifi_initialized" ]
            then
                echo_t "[RDKB_SELFHEAL] : WiFi Initialization done"
                ssidEnable=`dmcli eRT getv Device.WiFi.SSID.2.Enable`
                ssidExecution=`echo $ssidEnable | grep "Execution succeed"`
                if [ "$ssidExecution" != "" ]
                then
                    isEnabled=`echo $ssidEnable | grep "false"`
                    if [ "$isEnabled" != "" ]
                    then
                        SSID_DISABLED=1
                        echo_t "[RDKB_SELFHEAL] : SSID 5GHZ is disabled"
                    fi
                else
                    destinationError=`echo $ssidEnable | grep "Can't find destination component"`
                    if [ "$destinationError" != "" ]
                    then
                        echo_t "[RDKB_PLATFORM_ERROR] : Parameter cannot be found on WiFi subsystem"
                    else
                        echo_t "[RDKB_PLATFORM_ERROR] : Something went wrong while checking 5G Enable"
                        echo "$ssidEnable"
                    fi
                fi
            else
                echo_t  "[RDKB_PLATFORM_ERROR] : WiFi initialization not done"
                if ( [ "$BOX_TYPE" = "XB6" ] || [ "$BOX_TYPE" = "XB7" ] ) && [ "$MANUFACTURE" = "Technicolor" ]; then
                    if [ -f "$thisREADYFILE" ]
                    then
                        echo_t  "[RDKB_PLATFORM_ERROR] : restarting the CcspWifiSsp"
                        systemctl stop ccspwifiagent
                        systemctl start ccspwifiagent
                    fi
                fi
            fi
        fi
    ;;
esac

bridgeMode=`dmcli eRT getv Device.X_CISCO_COM_DeviceControl.LanManagementEntry.1.LanMode`
# RDKB-6895
bridgeSucceed=`echo $bridgeMode | grep "Execution succeed"`
if [ "$bridgeSucceed" != "" ]
then
    isBridging=`echo $bridgeMode | grep router`
    if [ "$isBridging" = "" ]
    then
        BR_MODE=1
        echo_t "[RDKB_SELFHEAL] : Device in bridge mode"
    fi
else
    echo_t "[RDKB_PLATFORM_ERROR] : Something went wrong while checking bridge mode."
    echo_t "LanMode dmcli called failed with error $bridgeMode"
    isBridging=`syscfg get bridge_mode`
    if [ "$isBridging" != "0" ]
    then
        BR_MODE=1
        echo_t "[RDKB_SELFHEAL] : Device in bridge mode"
    fi

    case $SELFHEAL_TYPE in
        "BASE"|"TCCBR")
            pandm_timeout=`echo $bridgeMode | grep "$CCSP_ERR_TIMEOUT"`
            pandm_notexist=`echo $bridgeMode | grep "$CCSP_ERR_NOT_EXIST"`
            if [ "$pandm_timeout" != "" ] || [ "$pandm_notexist" != "" ]
            then
                echo_t "[RDKB_PLATFORM_ERROR] : pandm parameter timed out or failed to return"
                cr_query=`dmcli eRT getv com.cisco.spvtg.ccsp.pam.Name`
                cr_timeout=`echo $cr_query | grep "$CCSP_ERR_TIMEOUT"`
                cr_pam_notexist=`echo $cr_query | grep "$CCSP_ERR_NOT_EXIST"`
                if [ "$cr_timeout" != "" ] || [ "$cr_pam_notexist" != "" ]
                then
                    echo_t "[RDKB_PLATFORM_ERROR] : pandm process is not responding. Restarting it"
                    PANDM_PID=`pidof CcspPandMSsp`
                    if [ "$PANDM_PID" != "" ]; then
                        kill -9 $PANDM_PID
                    fi
                    case $SELFHEAL_TYPE in
                        "BASE"|"TCCBR")
                            rm -rf /tmp/pam_initialized
                            resetNeeded pam CcspPandMSsp
                        ;;
                        "SYSTEMD")
                        ;;
                    esac
                fi  # [ "$cr_timeout" != "" ] || [ "$cr_pam_notexist" != "" ]
            fi  # [ "$pandm_timeout" != "" ] || [ "$pandm_notexist" != "" ]
        ;;
        "SYSTEMD")
            pandm_timeout=`echo $bridgeMode | grep "$CCSP_ERR_TIMEOUT"`
            if [ "$pandm_timeout" != "" ]; then
                echo_t "[RDKB_PLATFORM_ERROR] : pandm parameter time out"
                cr_query=`dmcli eRT getv com.cisco.spvtg.ccsp.pam.Name`
                cr_timeout=`echo $cr_query | grep "$CCSP_ERR_TIMEOUT"`
                if [ "$cr_timeout" != "" ]; then
                    echo_t "[RDKB_PLATFORM_ERROR] : pandm process is not responding. Restarting it"
                    PANDM_PID=`pidof CcspPandMSsp`
                    rm -rf /tmp/pam_initialized
                    systemctl restart CcspPandMSsp.service
                fi
            else
                echo "$bridgeMode"
            fi
        ;;
    esac
fi  # [ "$bridgeSucceed" != "" ]

case $SELFHEAL_TYPE in
    "BASE")
        #check for PandM response
        bridgeMode=`dmcli eRT getv Device.X_CISCO_COM_DeviceControl.LanManagementEntry.1.LanMode`
        bridgeSucceed=`echo $bridgeMode | grep "Execution succeed"`
        if [ "$bridgeSucceed" == "" ]
        then
            echo_t "[RDKB_SELFHEAL_DEBUG] : bridge mode = $bridgeMode"
            serialNumber=`dmcli eRT getv Device.DeviceInfo.SerialNumber`
            echo_t "[RDKB_SELFHEAL_DEBUG] : SerialNumber = $serialNumber"
            modelName=`dmcli eRT getv Device.DeviceInfo.ModelName`
            echo_t "[RDKB_SELFHEAL_DEBUG] : modelName = $modelName"

            pandm_timeout=`echo $bridgeMode | grep "CCSP_ERR_TIMEOUT"`
            pandm_notexist=`echo $bridgeMode | grep "CCSP_ERR_NOT_EXIST"`
            if [ "$pandm_timeout" != "" ] || [ "$pandm_notexist" != "" ]
            then
                echo_t "[RDKB_PLATFORM_ERROR] : pandm parameter timed out or failed to return"
                cr_query=`dmcli eRT getv com.cisco.spvtg.ccsp.pam.Name`
                cr_timeout=`echo $cr_query | grep "CCSP_ERR_TIMEOUT"`
                cr_pam_notexist=`echo $cr_query | grep "CCSP_ERR_NOT_EXIST"`
                if [ "$cr_timeout" != "" ] || [ "$cr_pam_notexist" != "" ]
                then
                    echo_t "[RDKB_PLATFORM_ERROR] : pandm process is not responding. Restarting it"
                    PANDM_PID=`pidof CcspPandMSsp`
                    if [ "$PANDM_PID" != "" ]; then
                        kill -9 $PANDM_PID
                    fi
                    rm -rf /tmp/pam_initialized
                    resetNeeded pam CcspPandMSsp
                fi
            fi
        fi
    ;;
    "TCCBR")
    ;;
    "SYSTEMD")
    ;;
esac

if [ "$SELFHEAL_TYPE" = "BASE" ] || [ "$WiFi_Flag" == "false" ]; then
    # If bridge mode is not set and WiFI is not disabled by user,
    # check the status of SSID
    if [ $BR_MODE -eq 0 ] && [ $SSID_DISABLED -eq 0 ]
    then
        ssidStatus_5=`dmcli eRT getv Device.WiFi.SSID.2.Status`
        isExecutionSucceed=`echo $ssidStatus_5 | grep "Execution succeed"`
        if [ "$isExecutionSucceed" != "" ]
        then

            isUp=`echo $ssidStatus_5 | grep "Up"`
            if [ "$isUp" = "" ]
            then
                # We need to verify if it was a dmcli crash or is WiFi really down
                isDown=`echo $ssidStatus_5 | grep "Down"`
                if [ "$isDown" != "" ]; then
                    case $SELFHEAL_TYPE in
                        "BASE"|"SYSTEMD")
                            echo_t "[RDKB_PLATFORM_ERROR] : 5G private SSID (ath1) is off."
                        ;;
                        "TCCBR")
                            echo_t "[RDKB_PLATFORM_ERROR] : 5G private SSID is off."
                        ;;
                    esac
                else
                    echo_t "[RDKB_PLATFORM_ERROR] : Something went wrong while checking 5G status."
                    echo "$ssidStatus_5"
                fi
            fi
        else
            echo_t "[RDKB_PLATFORM_ERROR] : dmcli crashed or something went wrong while checking 5G status."
            echo "$ssidStatus_5"
        fi
    fi

    # Check the status if 2.4GHz Wifi SSID
    SSID_DISABLED_2G=0
    ssidEnable_2=`dmcli eRT getv Device.WiFi.SSID.1.Enable`
    ssidExecution_2=`echo $ssidEnable_2 | grep "Execution succeed"`

    if [ "$ssidExecution_2" != "" ]
    then
        isEnabled_2=`echo $ssidEnable_2 | grep "false"`
        if [ "$isEnabled_2" != "" ]
        then
            SSID_DISABLED_2G=1
            echo_t "[RDKB_SELFHEAL] : SSID 2.4GHZ is disabled"
        fi
    else
        echo_t "[RDKB_PLATFORM_ERROR] : Something went wrong while checking 2.4G Enable"
        echo "$ssidEnable_2"
    fi

    # If bridge mode is not set and WiFI is not disabled by user,
    # check the status of SSID
    if [ $BR_MODE -eq 0 ] && [ $SSID_DISABLED_2G -eq 0 ]
    then
        ssidStatus_2=`dmcli eRT getv Device.WiFi.SSID.1.Status`
        isExecutionSucceed_2=`echo $ssidStatus_2 | grep "Execution succeed"`
        if [ "$isExecutionSucceed_2" != "" ]
        then

            isUp=`echo $ssidStatus_2 | grep "Up"`
            if [ "$isUp" = "" ]
            then
                # We need to verify if it was a dmcli crash or is WiFi really down
                isDown=`echo $ssidStatus_2 | grep "Down"`
                if [ "$isDown" != "" ]; then
                    echo_t "[RDKB_PLATFORM_ERROR] : 2.4G private SSID (ath0) is off."
                else
                    echo_t "[RDKB_PLATFORM_ERROR] : Something went wrong while checking 2.4G status."
                    echo "$ssidStatus_2"
                fi
            fi
        else
            echo_t "[RDKB_PLATFORM_ERROR] : dmcli crashed or something went wrong while checking 2.4G status."
            echo "$ssidStatus_2"
        fi
    fi
fi

FIREWALL_ENABLED=`syscfg get firewall_enabled`

echo_t "[RDKB_SELFHEAL] : BRIDGE_MODE is $BR_MODE"
echo_t "[RDKB_SELFHEAL] : FIREWALL_ENABLED is $FIREWALL_ENABLED"

#Check whether private SSID's are broadcasting during bridge-mode or not
#if broadcasting then we need to disable that SSID's for pseduo mode(2)
#if device is in full bridge-mode(3) then we need to disable both radio and SSID's
if [ $BR_MODE -eq 1 ]; then

    isBridging=`syscfg get bridge_mode`
    echo_t "[RDKB_SELFHEAL] : BR_MODE:$isBridging"

    #full bridge-mode(3)
    if [ "$isBridging" == "3" ]
    then
        # Check the status if 2.4GHz Wifi Radio
        RADIO_ENABLED_2G=0
        RadioEnable_2=`dmcli eRT getv Device.WiFi.Radio.1.Enable`
        RadioExecution_2=`echo $RadioEnable_2 | grep "Execution succeed"`

        if [ "$RadioExecution_2" != "" ]
        then
            isEnabled_2=`echo $RadioEnable_2 | grep "true"`
            if [ "$isEnabled_2" != "" ]
            then
                RADIO_ENABLED_2G=1
                echo_t "[RDKB_SELFHEAL] : Radio 2.4GHZ is Enabled"
            fi
        else
            echo_t "[RDKB_PLATFORM_ERROR] : Something went wrong while checking 2.4G radio Enable"
            echo "$RadioEnable_2"
        fi

        # Check the status if 5GHz Wifi Radio
        RADIO_ENABLED_5G=0
        RadioEnable_5=`dmcli eRT getv Device.WiFi.Radio.2.Enable`
        RadioExecution_5=`echo $RadioEnable_5 | grep "Execution succeed"`

        if [ "$RadioExecution_5" != "" ]
        then
            isEnabled_5=`echo $RadioEnable_5 | grep "true"`
            if [ "$isEnabled_5" != "" ]
            then
                RADIO_ENABLED_5G=1
                echo_t "[RDKB_SELFHEAL] : Radio 5GHZ is Enabled"
            fi
        else
            echo_t "[RDKB_PLATFORM_ERROR] : Something went wrong while checking 5G radio Enable"
            echo "$RadioEnable_5"
        fi

        if [ $RADIO_ENABLED_5G -eq 1 ] || [ $RADIO_ENABLED_2G -eq 1 ]; then
            dmcli eRT setv Device.WiFi.Radio.1.Enable bool false
            sleep 2
            dmcli eRT setv Device.WiFi.Radio.2.Enable bool false
            sleep 2
            dmcli eRT setv Device.WiFi.SSID.3.Enable bool false
            sleep 2
            IsNeedtoDoApplySetting=1
        fi
    fi

    if [ $SSID_DISABLED_2G -eq 0 ] || [ $SSID_DISABLED -eq 0 ]; then
        dmcli eRT setv Device.WiFi.SSID.1.Enable bool false
        sleep 2
        dmcli eRT setv Device.WiFi.SSID.2.Enable bool false
        sleep 2
        IsNeedtoDoApplySetting=1
    fi

    if [ "$IsNeedtoDoApplySetting" == "1" ]
    then
        dmcli eRT setv Device.WiFi.Radio.1.X_CISCO_COM_ApplySetting bool true
        sleep 3
        dmcli eRT setv Device.WiFi.Radio.2.X_CISCO_COM_ApplySetting bool true
        sleep 3
        dmcli eRT setv Device.WiFi.X_CISCO_COM_ResetRadios bool true
    fi
fi

if [ $BR_MODE -eq 0 ]
then
    iptables-save -t nat | grep "A PREROUTING -i"
    if [ $? == 1 ]; then
        echo_t "[RDKB_PLATFORM_ERROR] : iptable corrupted."
        #sysevent set firewall-restart
    fi
fi

case $SELFHEAL_TYPE in
    "BASE"|"SYSTEMD")
        if [ "$BOX_TYPE" != "HUB4" ] && [ "$thisIS_BCI" != "yes" ] && [ $BR_MODE -eq 0 ] && [ ! -f "$brlan1_firewall" ]
        then
            firewall_rules=`iptables-save`
            check_if_brlan1=`echo $firewall_rules | grep brlan1`
            if [ "$check_if_brlan1" == "" ]; then
                echo_t "[RDKB_PLATFORM_ERROR]:brlan1_firewall_rules_missing,restarting firewall"
                sysevent set firewall-restart
            fi
            touch $brlan1_firewall
        fi
    ;;
    "TCCBR")
    ;;
esac

#Logging to check the DHCP range corruption
lan_ipaddr=`syscfg get lan_ipaddr`
lan_netmask=`syscfg get lan_netmask`
echo_t "[RDKB_SELFHEAL] [DHCPCORRUPT_TRACE] : lan_ipaddr = $lan_ipaddr lan_netmask = $lan_netmask"

lost_and_found_enable=`syscfg get lost_and_found_enable`
echo_t "[RDKB_SELFHEAL] [DHCPCORRUPT_TRACE] :  lost_and_found_enable = $lost_and_found_enable"
if [ "$lost_and_found_enable" == "true" ]
then
    iot_ifname=`syscfg get iot_ifname`
    iot_dhcp_start=`syscfg get iot_dhcp_start`
    iot_dhcp_end=`syscfg get iot_dhcp_end`
    iot_netmask=`syscfg get iot_netmask`
    echo_t "[RDKB_SELFHEAL] [DHCPCORRUPT_TRACE] : DHCP server configuring for IOT iot_ifname = $iot_ifname "
    echo_t "[RDKB_SELFHEAL] [DHCPCORRUPT_TRACE] : iot_dhcp_start = $iot_dhcp_start iot_dhcp_end=$iot_dhcp_end iot_netmask=$iot_netmask"
fi


#Checking whether dnsmasq is running or not and if zombie for XF3
if [ "$thisWAN_TYPE" == "EPON" ]; then
    DNS_PID=`pidof dnsmasq`
    if [ "$DNS_PID" == "" ];then
        echo_t "[RDKB_SELFHEAL] : dnsmasq is not running"
    fi
    checkIfDnsmasqIsZombie=`ps | grep dnsmasq | grep "Z" | awk '{ print $1 }'`
    if [ "$checkIfDnsmasqIsZombie" != "" ] ; then
        for zombiepid in $checkIfDnsmasqIsZombie
        do
            confirmZombie=`grep "State:" /proc/$zombiepid/status | grep -i "zombie"`
            if [ "$confirmZombie" != "" ] ; then
                case $SELFHEAL_TYPE in
                    "BASE")
                    ;;
                    "TCCBR")
                    ;;
                    "SYSTEMD")
                        echo_t "[RDKB_SELFHEAL] : Zombie instance of dnsmasq is present, stopping CcspXdns"
                        systemctl stop CcspXdnsSsp.service
                    ;;
                esac
                echo_t "[RDKB_SELFHEAL] : Zombie instance of dnsmasq is present, restarting dnsmasq"
                kill -9 `pidof dnsmasq`
                systemctl stop dnsmasq
                systemctl start dnsmasq
                case $SELFHEAL_TYPE in
                    "BASE")
                    ;;
                    "TCCBR")
                    ;;
                    "SYSTEMD")
                        echo_t "[RDKB_SELFHEAL] : Zombie instance of dnsmasq is present, restarting CcspXdns"
                        systemctl start CcspXdnsSsp.service
                    ;;
                esac
                break
            fi
        done
    fi

fi

#Checking whether dnsmasq is running or not
if [ "$thisWAN_TYPE" != "EPON" ]; then
    DNS_PID=`pidof dnsmasq`
    if [ "$DNS_PID" == "" ]
    then
        echo_t "[RDKB_SELFHEAL] : dnsmasq is not running"
    else
        brlan0up=`cat /var/dnsmasq.conf | grep brlan0`
        case $SELFHEAL_TYPE in
            "BASE")
                brlan1up=`cat /var/dnsmasq.conf | grep brlan1`
                lnf_ifname=`syscfg get iot_ifname`
                if [ "$lnf_ifname" != "" ] && [ "$BOX_TYPE" != "rpi" ]
                then
                    echo_t "[RDKB_SELFHEAL] : LnF interface is: $lnf_ifname"
                    infup=`cat /var/dnsmasq.conf | grep $lnf_ifname`
                else
                    echo_t "[RDKB_SELFHEAL] : LnF interface not available in DB"
                    #Set some value so that dnsmasq won't restart
                    infup="NA"
                fi
            ;;
            "TCCBR")
            ;;
            "SYSTEMD")
                brlan1up=`cat /var/dnsmasq.conf | grep brlan1`
            ;;
        esac

        IsAnyOneInfFailtoUp=0

        if [ $BR_MODE -eq 0 ]
        then
            if [ "$brlan0up" == "" ]
            then
                echo_t "[RDKB_SELFHEAL] : brlan0 info is not availble in dnsmasq.conf"
                IsAnyOneInfFailtoUp=1
            fi
        fi

        case $SELFHEAL_TYPE in
            "BASE"|"SYSTEMD")
                if [ "$thisIS_BCI" != "yes" ] && [ "$brlan1up" == "" ] && [ "$BOX_TYPE" != "rpi" ]
                then
                    echo_t "[RDKB_SELFHEAL] : brlan1 info is not availble in dnsmasq.conf"
                    IsAnyOneInfFailtoUp=1
                fi
            ;;
            "TCCBR")
            ;;
        esac

        case $SELFHEAL_TYPE in
            "BASE")
                if [ "$infup" == "" ] && [ "$BOX_TYPE" != "rpi" ]
                then
                    echo_t "[RDKB_SELFHEAL] : $lnf_ifname info is not availble in dnsmasq.conf"
                    IsAnyOneInfFailtoUp=1
                fi
            ;;
            "TCCBR")
            ;;
            "SYSTEMD")
            ;;
        esac

        if [ ! -f /tmp/dnsmasq_restarted_via_selfheal ]
        then
            if [ $IsAnyOneInfFailtoUp -eq 1 ]
            then
                touch /tmp/dnsmasq_restarted_via_selfheal

                echo_t "[RDKB_SELFHEAL] : dnsmasq.conf is."
                echo "`cat /var/dnsmasq.conf`"

                echo_t "[RDKB_SELFHEAL] : Setting an event to restart dnsmasq"
                sysevent set dhcp_server-stop
                sysevent set dhcp_server-start
            fi
        fi

        case $SELFHEAL_TYPE in
            "BASE"|"SYSTEMD")
                checkIfDnsmasqIsZombie=`ps | grep dnsmasq | grep "Z" | awk '{ print $1 }'`
                if [ "$checkIfDnsmasqIsZombie" != "" ] ; then
                    for zombiepid in $checkIfDnsmasqIsZombie
                    do
                        confirmZombie=`grep "State:" /proc/$zombiepid/status | grep -i "zombie"`
                        if [ "$confirmZombie" != "" ] ; then
                            echo_t "[RDKB_SELFHEAL] : Zombie instance of dnsmasq is present, restarting dnsmasq"
                            kill -9 `pidof dnsmasq`
                            sysevent set dhcp_server-stop
                            sysevent set dhcp_server-start
                            break
                        fi
                    done
                fi
            ;;
            "TCCBR")
            ;;
        esac
    fi   # [ "$DNS_PID" == "" ]
fi  # [ "$thisWAN_TYPE" != "EPON" ]

case $SELFHEAL_TYPE in
    "BASE")
    ;;
    "TCCBR")
    ;;
    "SYSTEMD")
        #Checking ipv6 dad failure and restart dibbler client [TCXB6-5169]
        CHKIPV6_DAD_FAILED=`ip -6 addr show dev erouter0 | grep "scope link tentative dadfailed"`
        if [ "$CHKIPV6_DAD_FAILED" != "" ]; then
            echo_t "link Local DAD failed"
            if ([ "$BOX_TYPE" = "XB6" ] || [ "$BOX_TYPE" = "XB7" ]) && [ "$MANUFACTURE" = "Technicolor" ] ; then
                partner_id=`syscfg get PartnerID`
                if [ "$partner_id" != "comcast" ]; then
                    dibbler-client stop
                    sysctl -w net.ipv6.conf.erouter0.disable_ipv6=1
                    sysctl -w net.ipv6.conf.erouter0.accept_dad=0
                    sysctl -w net.ipv6.conf.erouter0.disable_ipv6=0
                    sysctl -w net.ipv6.conf.erouter0.accept_dad=1
                    dibbler-client start
                    echo_t "IPV6_DAD_FAILURE : successfully recovered for partner id $partner_id"
                fi
            fi
        fi
    ;;
esac

#Checking dibbler server is running or not RDKB_10683
DIBBLER_PID=`pidof dibbler-server`
if [ "$DIBBLER_PID" = "" ] && [ "$BOX_TYPE" != "rpi" ]; then

    DHCPV6C_ENABLED=`sysevent get dhcpv6c_enabled`
    if [ "$BR_MODE" == "0" ] && [ "$DHCPV6C_ENABLED" == "1" ]; then
        case $SELFHEAL_TYPE in
            "BASE"|"TCCBR")
                DHCPv6EnableStatus=`syscfg get dhcpv6s00::serverenable`
                if [ "$IS_BCI" = "yes" ] && [ "0" = "$DHCPv6EnableStatus" ]; then
                    echo_t "DHCPv6 Disabled. Restart of Dibbler process not Required"
                else
                    echo_t "RDKB_PROCESS_CRASHED : Dibbler is not running, restarting the dibbler"
                    if [ -f "/etc/dibbler/server.conf" ]
                    then
                        BRLAN_CHKIPV6_DAD_FAILED=`ip -6 addr show dev $PRIVATE_LAN | grep "scope link tentative dadfailed"`
                        if [ "$BRLAN_CHKIPV6_DAD_FAILED" != "" ]; then
                            echo "DADFAILED : BRLAN0_DADFAILED"
                            
                            if ([ "$BOX_TYPE" = "XB6" ] || [ "$BOX_TYPE" = "XB7" ]) && [ "$MANUFACTURE" = "Technicolor" ] ; then
                                echo "DADFAILED : Recovering device from DADFAILED state"
                                echo 1 > /proc/sys/net/ipv6/conf/$PRIVATE_LAN/disable_ipv6
                                sleep 1
                                echo 0 > /proc/sys/net/ipv6/conf/$PRIVATE_LAN/disable_ipv6

                                sleep 1 

                                dibbler-client stop 
                                sleep 1
                                dibbler-client start            
                                sleep 5
                            elif [ "$MODEL_NUM" = "TG3482G" ] || [ "$MODEL_NUM" = "TG4482A" ]; then
                                echo "DADFAILED : Recovering device from DADFAILED state"
                                sh $DHCPV6_HANDLER disable
                                sysctl -w net.ipv6.conf.$PRIVATE_LAN.disable_ipv6=1
                                sysctl -w net.ipv6.conf.$PRIVATE_LAN.accept_dad=0
                                sleep 1
                                sysctl -w net.ipv6.conf.$PRIVATE_LAN.disable_ipv6=0
                                sysctl -w net.ipv6.conf.$PRIVATE_LAN.accept_dad=1
                                sleep 1
                                sh $DHCPV6_HANDLER enable
                                sleep 5
                            fi
                        elif [ ! -s  "/etc/dibbler/server.conf" ]; then
                            echo "DIBBLER : Dibbler Server Config is empty"
                        else
                            dibbler-server stop
                            sleep 2
                            dibbler-server start
                        fi
                    else
                        echo_t "RDKB_PROCESS_CRASHED : Server.conf file not present, Cannot restart dibbler"
                    fi
                fi
            ;;
            "SYSTEMD")
                #ARRISXB6-7776 .. check if IANAEnable is set to 0
                IANAEnable=`syscfg show | grep dhcpv6spool00::IANAEnable | cut -d "=" -f2`
                if [ "$IANAEnable" = "0" ] ; then
                    echo "[`getDateTime`] IANAEnable disabled, enable and restart dhcp6 client and dibbler"
                    syscfg set dhcpv6spool00::IANAEnable 1
                    syscfg commit
                    sleep 2
                    #need to restart dhcp client to generate dibbler conf
                    sh $DHCPV6_HANDLER disable
                    sleep 2
                    sh $DHCPV6_HANDLER enable
                else
                    echo_t "RDKB_PROCESS_CRASHED : Dibbler is not running, restarting the dibbler"
                    if [ -f "/etc/dibbler/server.conf" ]
                    then
                        BRLAN_CHKIPV6_DAD_FAILED=`ip -6 addr show dev $PRIVATE_LAN | grep "scope link tentative dadfailed"`
                        if [ "$BRLAN_CHKIPV6_DAD_FAILED" != "" ]; then
                            echo "DADFAILED : BRLAN0_DADFAILED"
                        elif [ ! -s  "/etc/dibbler/server.conf" ]; then
                            echo "DIBBLER : Dibbler Server Config is empty"
                        else
                            dibbler-server stop
                            sleep 2
                            dibbler-server start
                        fi
                    else
                        echo_t "RDKB_PROCESS_CRASHED : Server.conf file not present, Cannot restart dibbler"
                    fi
                fi
            ;;
        esac
    fi
fi

#Checking the zebra is running or not
WAN_STATUS=`sysevent get wan-status`
ZEBRA_PID=`pidof zebra`
if [ "$ZEBRA_PID" = "" ] && [ "$WAN_STATUS" = "started" ] && [ "$BOX_TYPE" != "rpi" ]; then
    if [ "$BR_MODE" == "0" ]; then

        echo_t "RDKB_PROCESS_CRASHED : zebra is not running, restarting the zebra"
        /etc/utopia/registration.d/20_routing restart
        sysevent set zebra-restart
    fi
fi

case $SELFHEAL_TYPE in
    "BASE")
        #Checking the ntpd is running or not
        if [ "$WAN_TYPE" != "EPON" ] && [ "$BOX_TYPE" != "rpi" ]; then
            NTPD_PID=`pidof ntpd`
            if [ "$NTPD_PID" = "" ]; then
                echo_t "RDKB_PROCESS_CRASHED : NTPD is not running, restarting the NTPD"
                sysevent set ntpd-restart
            fi


            #Checking if rpcserver is running
            RPCSERVER_PID=`pidof rpcserver`
            if [ "$RPCSERVER_PID" = "" ] && [ -f /usr/bin/rpcserver ]; then
                echo_t "RDKB_PROCESS_CRASHED : RPCSERVER is not running on ARM side, restarting "
                /usr/bin/rpcserver &
            fi
        fi
    ;;
    "TCCBR")
    ;;
    "SYSTEMD")
        #All CCSP Processes Now running on Single Processor. Add those Processes to Test & Diagnostic
    ;;
esac

# Checking for WAN_INTERFACE ipv6 address
DHCPV6_ERROR_FILE="/tmp/.dhcpv6SolicitLoopError"
WAN_STATUS=`sysevent get wan-status`
WAN_IPv4_Addr=`ifconfig $WAN_INTERFACE | grep inet | grep -v inet6`
DHCPV6_HANDLER="/etc/utopia/service.d/service_dhcpv6_client.sh"

case $SELFHEAL_TYPE in
    "BASE"|"SYSTEMD")
        if [ "$WAN_STATUS" != "started" ]
        then
            echo_t "WAN_STATUS : wan-status is $WAN_STATUS"
        fi
    ;;
    "TCCBR")
    ;;
esac

if [ "$BOX_TYPE" != "HUB4" ] && [ -f "$DHCPV6_ERROR_FILE" ] && [ "$WAN_STATUS" = "started" ] && [ "$WAN_IPv4_Addr" != "" ] && [ "$BOX_TYPE" != "rpi" ]
then
    isIPv6=`ifconfig $WAN_INTERFACE | grep inet6 | grep "Scope:Global"`
    echo_t "isIPv6 = $isIPv6"
    if [ "$isIPv6" == "" ]
    then
        case $SELFHEAL_TYPE in
            "BASE"|"SYSTEMD")
                echo_t "[RDKB_SELFHEAL] : $DHCPV6_ERROR_FILE file present and $WAN_INTERFACE ipv6 address is empty, restarting dhcpv6 client"
            ;;
            "TCCBR")
                echo_t "[RDKB_SELFHEAL] : $DHCPV6_ERROR_FILE file present and $WAN_INTERFACE ipv6 address is empty, restarting ti_dhcp6c"
            ;;
        esac
        rm -rf $DHCPV6_ERROR_FILE
        sh $DHCPV6_HANDLER disable
        sleep 2
        sh $DHCPV6_HANDLER enable
    fi
fi

if [ "$BOX_TYPE" != "HUB4" ] && [ "$WAN_STATUS" = "started" ] && [ "$BOX_TYPE" != "rpi" ];then
    wan_dhcp_client_v4=1
    wan_dhcp_client_v6=1
    case $SELFHEAL_TYPE in
        "BASE"|"SYSTEMD")
            UDHCPC_Enable=`syscfg get UDHCPEnable`
            dibbler_client_enable=`syscfg get dibbler_client_enable`

            if ( [ "$MANUFACTURE" = "Technicolor" ] && [ "$BOX_TYPE" != "XB3" ] ) || [ "$WAN_TYPE" = "EPON" ]; then
                check_wan_dhcp_client_v4=`ps w | grep udhcpc | grep erouter`
                check_wan_dhcp_client_v6=`ps w | grep dibbler-client | grep -v grep`
            else
                if [ "$MODEL_NUM" = "TG3482G" ] || [ "$MODEL_NUM" = "TG4482A" ] || [ "$SELFHEAL_TYPE" = "BASE" -a "$BOX_TYPE" = "XB3" ]; then
                    dhcp_cli_output=`ps w | grep ti_ | grep erouter0`

                    if [ "$UDHCPC_Enable" = "true" ]
                    then
                        check_wan_dhcp_client_v4=`ps w | grep sbin/udhcpc | grep erouter`
                    else
                        check_wan_dhcp_client_v4=`echo $dhcp_cli_output | grep ti_udhcpc`
                    fi
                    if [ "$dibbler_client_enable" = "true" ]; then
                        check_wan_dhcp_client_v6=`ps w | grep dibbler-client | grep -v grep`
                    else
                        check_wan_dhcp_client_v6=`echo $dhcp_cli_output | grep ti_dhcp6c`
                    fi
                else
                    dhcp_cli_output=`ps w | grep ti_ | grep erouter0`
                    check_wan_dhcp_client_v4=`echo $dhcp_cli_output | grep ti_udhcpc`
                    check_wan_dhcp_client_v6=`echo $dhcp_cli_output | grep ti_dhcp6c`
                fi
            fi
        ;;
        "TCCBR")
            check_wan_dhcp_client_v4=`ps w | grep udhcpc | grep erouter`
            check_wan_dhcp_client_v6=`ps w | grep dibbler-client | grep -v grep`
        ;;
    esac

    case $SELFHEAL_TYPE in
        "BASE")
            if [ "$BOX_TYPE" = "XB3" ] && [ "$BOX_TYPE" != "rpi" ]; then

                if [ "x$check_wan_dhcp_client_v4" != "x" ] && [ "x$check_wan_dhcp_client_v6" != "x" ];then
                    if [ `cat /proc/net/dbrctl/mode`  = "standbay" ]
                    then
                        echo_t "RDKB_SELFHEAL : dbrctl mode is standbay, changing mode to registered"
                        echo "registered" > /proc/net/dbrctl/mode
                    fi
                fi
            fi

            if [ "x$check_wan_dhcp_client_v4" = "x" ] && [ "$BOX_TYPE" != "rpi" ]; then
                echo_t "RDKB_PROCESS_CRASHED : DHCP Client for v4 is not running, need restart "
                wan_dhcp_client_v4=0
            fi
        ;;
        "TCCBR")
            if [ "x$check_wan_dhcp_client_v4" = "x" ]; then
                echo_t "RDKB_PROCESS_CRASHED : DHCP Client for v4 is not running, need restart "
                wan_dhcp_client_v4=0
            fi
        ;;
        "SYSTEMD")
            if [ "$MODEL_NUM" = "TG3482G" ] || [ "$MODEL_NUM" = "TG4482A" ] || [ "$MODEL_NUM" = "INTEL_PUMA" ] ; then
                #Intel Proposed RDKB Generic Bug Fix from XB6 SDK
                LAST_EROUTER_MODE=`syscfg get last_erouter_mode`
            fi

            if [ "$MODEL_NUM" = "TG3482G" ] || [ "$MODEL_NUM" = "TG4482A" ] || [ "$MODEL_NUM" = "INTEL_PUMA" ] ; then
                #Intel Proposed RDKB Generic Bug Fix from XB6 SDK
                if [ "x$check_wan_dhcp_client_v4" = "x" ] && [ "x$LAST_EROUTER_MODE" != "x2" ]; then
                    echo_t "RDKB_PROCESS_CRASHED : DHCP Client for v4 is not running, need restart "
                    wan_dhcp_client_v4=0
                fi
            else
                if [ "x$check_wan_dhcp_client_v4" = "x" ]; then
                    echo_t "RDKB_PROCESS_CRASHED : DHCP Client for v4 is not running, need restart "
                    wan_dhcp_client_v4=0
                fi
            fi
        ;;
    esac


    if [ "$thisWAN_TYPE" != "EPON" ] && [ "$BOX_TYPE" != "rpi" ]; then
        case $SELFHEAL_TYPE in
            "BASE"|"TCCBR")
                if [ "x$check_wan_dhcp_client_v6" = "x" ]; then
                    echo_t "RDKB_PROCESS_CRASHED : DHCP Client for v6 is not running, need restart"
                    wan_dhcp_client_v6=0
                fi
            ;;
            "SYSTEMD")
                if [ "$MODEL_NUM" = "TG3482G" ] || [ "$MODEL_NUM" = "TG4482A" ] || [ "$MODEL_NUM" = "INTEL_PUMA" ] ; then
                    #Intel Proposed RDKB Generic Bug Fix from XB6 SDK
                    if [ "x$check_wan_dhcp_client_v6" = "x" ] && [ "x$LAST_EROUTER_MODE" != "x1" ]; then
                        echo_t "RDKB_PROCESS_CRASHED : DHCP Client for v6 is not running, need restart"
                        wan_dhcp_client_v6=0
                    fi
                else
                    if [ "x$check_wan_dhcp_client_v6" = "x" ]; then
                        echo_t "RDKB_PROCESS_CRASHED : DHCP Client for v6 is not running, need restart"
                        wan_dhcp_client_v6=0
                    fi
                fi
            ;;
        esac

        DHCP_STATUS_query=`dmcli eRT getv Device.DHCPv4.Client.1.DHCPStatus`
        DHCP_STATUS_execution=`echo $DHCP_STATUS_query | grep "Execution succeed"`
        DHCP_STATUS=`echo "$DHCP_STATUS_query" | grep value | cut -f3 -d : | awk '{print $1}'`

        if [ "$DHCP_STATUS_execution" != "" ] && [ "$DHCP_STATUS" != "Bound" ] ; then

            echo_t "DHCP_CLIENT : DHCPStatusValue is $DHCP_STATUS"
            if [ $wan_dhcp_client_v4 -eq 0 ] || [ $wan_dhcp_client_v6 -eq 0 ]; then
                case $SELFHEAL_TYPE in
                    "BASE"|"TCCBR")
                        echo_t "DHCP_CLIENT : DHCPStatus is not Bound, restarting WAN"
                    ;;
                    "SYSTEMD")
                        echo_t "DHCP_CLIENT : DHCPStatus is $DHCP_STATUS, restarting WAN"
                    ;;
                esac
                sh /etc/utopia/service.d/service_wan.sh wan-stop
                sh /etc/utopia/service.d/service_wan.sh wan-start
                wan_dhcp_client_v4=1
                wan_dhcp_client_v6=1
            fi
        fi
    fi

    case $SELFHEAL_TYPE in
        "BASE")
            if [ $wan_dhcp_client_v4 -eq 0 ] && [ "$BOX_TYPE" != "rpi" ];
            then
                if [ "$MANUFACTURE" = "Technicolor" ] && [ "$BOX_TYPE" != "XB3" ]; then
                    V4_EXEC_CMD="/sbin/udhcpc -i erouter0 -p /tmp/udhcpc.erouter0.pid -s /etc/udhcpc.script"
                elif [ "$WAN_TYPE" = "EPON" ];then
                    echo "Calling epon_utility.sh to restart udhcpc "
                    sh /usr/ccsp/epon_utility.sh
                else
                    if ( ( [ "$BOX_TYPE" = "XB6" ] || [ "$BOX_TYPE" = "XB7" ] ) && [ "$MANUFACTURE" = "Arris" ] ) || [ "$BOX_TYPE" = "XB3" ]; then

                        if [ "$UDHCPC_Enable" = "true" ]
                        then
                            V4_EXEC_CMD="/sbin/udhcpc -i erouter0 -p /tmp/udhcpc.erouter0.pid -s /usr/bin/service_udhcpc"
                        else
                            DHCPC_PID_FILE="/var/run/eRT_ti_udhcpc.pid"
                            V4_EXEC_CMD="ti_udhcpc -plugin /lib/libert_dhcpv4_plugin.so -i $WAN_INTERFACE -H DocsisGateway -p $DHCPC_PID_FILE -B -b 1"
                        fi
                    else
                        DHCPC_PID_FILE="/var/run/eRT_ti_udhcpc.pid"
                        V4_EXEC_CMD="ti_udhcpc -plugin /lib/libert_dhcpv4_plugin.so -i $WAN_INTERFACE -H DocsisGateway -p $DHCPC_PID_FILE -B -b 1"
                    fi
                fi
                echo_t "DHCP_CLIENT : Restarting DHCP Client for v4"
                eval "$V4_EXEC_CMD"
                sleep 5
                wan_dhcp_client_v4=1
            fi

            if [ $wan_dhcp_client_v6 -eq 0 ] && [ "$BOX_TYPE" != "rpi" ];
            then
                echo_t "DHCP_CLIENT : Restarting DHCP Client for v6"
                if [ "$MANUFACTURE" = "Technicolor" ] && [ "$BOX_TYPE" != "XB3" ]; then
                    /etc/dibbler/dibbler-init.sh
                    sleep 2
                    /usr/sbin/dibbler-client start
                elif [ "$WAN_TYPE" = "EPON" ];then
                    echo "Calling dibbler_starter.sh to restart dibbler-client "
                    sh /usr/ccsp/dibbler_starter.sh
                else
                    sh $DHCPV6_HANDLER disable
                    sleep 2
                    sh $DHCPV6_HANDLER enable
                fi
                wan_dhcp_client_v6=1
            fi
        ;;
        "TCCBR")
            if [ $wan_dhcp_client_v4 -eq 0 ];
            then
                V4_EXEC_CMD="/sbin/udhcpc -i erouter0 -p /tmp/udhcpc.erouter0.pid -s /etc/udhcpc.script"
                echo_t "DHCP_CLIENT : Restarting DHCP Client for v4"
                eval "$V4_EXEC_CMD"
                sleep 5
                wan_dhcp_client_v4=1
            fi

            if [ $wan_dhcp_client_v6 -eq 0 ];
            then
                echo_t "DHCP_CLIENT : Restarting DHCP Client for v6"
                /etc/dibbler/dibbler-init.sh
                sleep 2
                /usr/sbin/dibbler-client start
                wan_dhcp_client_v6=1
            fi
        ;;
        "SYSTEMD")
        ;;
    esac

fi # [ "$WAN_STATUS" = "started" ]

case $SELFHEAL_TYPE in
    "BASE")
        # Test to make sure that if mesh is enabled the backhaul tunnels are attached to the bridges
        MESH_ENABLE=`dmcli eRT getv Device.DeviceInfo.X_RDKCENTRAL-COM_xOpsDeviceMgmt.Mesh.Enable | grep value | cut -f3 -d : | cut -f2 -d" "`
        if [ "$MESH_ENABLE" = "true" ] && [ "$BOX_TYPE" != "rpi" ]
        then
            echo_t "[RDKB_SELFHEAL] : Mesh is enabled, test if tunnels are attached to bridges"

            # Fetch mesh tunnels from the brlan0 bridge if they exist
            brctl0_ifaces=`brctl show brlan0 | egrep "pgd"`
            br0_ifaces=`ifconfig | egrep "^pgd" | egrep "\.100" | awk '{print $1}'`

            for ifn in $br0_ifaces; do
                brFound="false"

                for br in $brctl0_ifaces; do
                    if [ "$br" == "$ifn" ]; then
                        brFound="true"
                    fi
                done
                if [ "$brFound" == "false" ]; then
                    echo_t "[RDKB_SELFHEAL] : Mesh bridge $ifn missing, adding iface to brlan0"
                    brctl addif brlan0 $ifn;
                fi
            done

            # Fetch mesh tunnels from the brlan1 bridge if they exist
            if [ "$thisIS_BCI" != "yes" ]; then
                brctl1_ifaces=`brctl show brlan1 | egrep "pgd"`
                br1_ifaces=`ifconfig | egrep "^pgd" | egrep "\.101" | awk '{print $1}'`

                for ifn in $br1_ifaces; do
                    brFound="false"

                    for br in $brctl1_ifaces; do
                        if [ "$br" == "$ifn" ]; then
                            brFound="true"
                        fi
                    done
                    if [ "$brFound" == "false" ]; then
                        echo_t "[RDKB_SELFHEAL] : Mesh bridge $ifn missing, adding iface to brlan1"
                        brctl addif brlan1 $ifn;
                    fi
                done
            fi
        fi
    ;;
    "TCCBR")
    ;;
    "SYSTEMD")
      if [ "$BOX_TYPE" != "HUB4" ]; then
        if [ $wan_dhcp_client_v4 -eq 0 ];
        then
            if [ "$MANUFACTURE" = "Technicolor" ]; then
                V4_EXEC_CMD="/sbin/udhcpc -i erouter0 -p /tmp/udhcpc.erouter0.pid -s /etc/udhcpc.script"
            elif [ "$WAN_TYPE" = "EPON" ];then
                echo "Calling epon_utility.sh to restart udhcpc "
                sh /usr/ccsp/epon_utility.sh
            else
                if [ "$MODEL_NUM" = "TG3482G" ] || [ "$MODEL_NUM" = "TG4482A" ]; then

                    if [ "$UDHCPC_Enable" = "true" ]
                    then
                        V4_EXEC_CMD="/sbin/udhcpc -i erouter0 -p /tmp/udhcpc.erouter0.pid -s /usr/bin/service_udhcpc"
                    else
                        #For AXB6 b -4 option is added to avoid timeout.
                        DHCPC_PID_FILE="/var/run/eRT_ti_udhcpc.pid"
                        V4_EXEC_CMD="ti_udhcpc -plugin /lib/libert_dhcpv4_plugin.so -i $WAN_INTERFACE -H DocsisGateway -p $DHCPC_PID_FILE -B -b 4"
                    fi
                else
                    DHCPC_PID_FILE="/var/run/eRT_ti_udhcpc.pid"
                    V4_EXEC_CMD="ti_udhcpc -plugin /lib/libert_dhcpv4_plugin.so -i $WAN_INTERFACE -H DocsisGateway -p $DHCPC_PID_FILE -B -b 1"
                fi
            fi

            echo_t "DHCP_CLIENT : Restarting DHCP Client for v4"
            eval "$V4_EXEC_CMD"
            sleep 5
            wan_dhcp_client_v4=1
        fi

        #ARRISXB6-8319
        #check if interface is down or default route is missing.
        if [ "$MODEL_NUM" = "TG3482G" ] || [ "$MODEL_NUM" = "TG4482A" ] && [ "$BOX_TYPE" != "rpi" ]; then
            ip route show default | grep default
            if [ $? -ne 0 ] ; then
                ifconfig $WAN_INTERFACE up
                sleep 2



                if [ "$UDHCPC_Enable" = "true" ]
                then
                    echo_t "restart udhcp"
                    DHCPC_PID_FILE="/tmp/udhcpc.erouter0.pid"
                else
                    echo_t "restart ti_udhcp"
                    DHCPC_PID_FILE="/var/run/eRT_ti_udhcpc.pid"
                fi


                if [ -f $DHCPC_PID_FILE ]
                then
                    echo_t "SERVICE_DHCP : Killing `cat $DHCPC_PID_FILE`"
                    kill -9 `cat $DHCPC_PID_FILE`
                    rm -f $DHCPC_PID_FILE
                fi


                if [ "$UDHCPC_Enable" = "true" ]
                then
                    V4_EXEC_CMD="/sbin/udhcpc -i erouter0 -p /tmp/udhcpc.erouter0.pid -s /etc/udhcpc.script"
                else
                    #For AXB6 b -4 option is added to avoid timeout.
                    V4_EXEC_CMD="ti_udhcpc -plugin /lib/libert_dhcpv4_plugin.so -i $WAN_INTERFACE -H DocsisGateway -p $DHCPC_PID_FILE -B -b 4"
                fi


                echo_t "DHCP_CLIENT : Restarting DHCP Client for v4"
                eval "$V4_EXEC_CMD"
                sleep 5
                wan_dhcp_client_v4=1
            fi
        fi

        if [ $wan_dhcp_client_v6 -eq 0 ] && [ "$BOX_TYPE" != "rpi" ];
        then
            echo_t "DHCP_CLIENT : Restarting DHCP Client for v6"
            if [ "$MANUFACTURE" = "Technicolor" ] && [ "$BOX_TYPE" != "XB3" ]; then
                /etc/dibbler/dibbler-init.sh
                sleep 2
                /usr/sbin/dibbler-client start
            elif [ "$WAN_TYPE" = "EPON" ];then
                echo "Calling dibbler_starter.sh to restart dibbler-client "
                sh /usr/ccsp/dibbler_starter.sh
            else
                sh $DHCPV6_HANDLER disable
                sleep 2
                sh $DHCPV6_HANDLER enable
            fi
            wan_dhcp_client_v6=1
        fi
     fi #Not HUB4
    ;;
esac

case $SELFHEAL_TYPE in
    "BASE")
    ;;
    "TCCBR")
    ;;
    "SYSTEMD")
        if [ "$MULTI_CORE" = "yes" ]; then
            if [ -f $PING_PATH/ping_peer ]
            then
                ## Check Peer ip is accessible
                loop=1
                while [ "$loop" -le 3 ]
                do
                    PING_RES=`ping_peer`
                    CHECK_PING_RES=`echo $PING_RES | grep "packet loss" | cut -d"," -f3 | cut -d"%" -f1`

                    if [ "$CHECK_PING_RES" != "" ]
                    then
                        if [ "$CHECK_PING_RES" -ne 100 ]
                        then
                            ping_success=1
                            echo_t "RDKB_SELFHEAL : Ping to Peer IP is success"
                            break
                        else
                            ping_failed=1
                        fi
                    else
                        ping_failed=1
                    fi

                    if [ "$ping_failed" -eq 1 ] && [ "$loop" -lt 3 ]
                    then
                        echo_t "RDKB_SELFHEAL : Ping to Peer IP failed in iteration $loop"
                    else
                        echo_t "RDKB_SELFHEAL : Ping to Peer IP failed after iteration $loop also ,rebooting the device"
                        echo_t "RDKB_REBOOT : Peer is not up ,Rebooting device "
                        echo_t "Setting Last reboot reason Peer_down"
                        reason="Peer_down"
                        rebootCount=1
                        rebootNeeded RM "" $reason $rebootCount

                    fi
                    loop=$((loop+1))
                    sleep 5
                done
            else
                echo_t "RDKB_SELFHEAL : ping_peer command not found"
            fi

            if [ -f $PING_PATH/arping_peer ]
            then
                $PING_PATH/arping_peer
            else
                echo_t "RDKB_SELFHEAL : arping_peer command not found"
            fi
        fi
    ;;
esac


if [ "$rebootDeviceNeeded" -eq 1 ]
then

    inMaintWindow=0
    doMaintReboot=1
    case $SELFHEAL_TYPE in
        "BASE"|"SYSTEMD")
            if [ "$UTC_ENABLE" == "true" ]
            then
                cur_hr=`LTime H`
                cur_min=`LTime M`
            else
                cur_hr=`date +"%H"`
                cur_min=`date +"%M"`
            fi
            if [ $cur_hr -ge 02 ] && [ $cur_hr -le 03 ]
            then
                inMaintWindow=1
                if [ $cur_hr -eq 03 ] && [ $cur_min -ne 00 ]
                then
                    doMaintReboot=0
                fi
            fi
        ;;
        "TCCBR")
            inMaintWindow=1
            checkMaintenanceWindow
            if [ $reb_window -eq 0 ]; then
                doMaintReboot=0
            fi
        ;;
    esac
    if [ $inMaintWindow -eq 1 ]
    then
        if [ $doMaintReboot -eq 0 ]
        then
            echo_t "Maintanance window for the current day is over , unit will be rebooted in next Maintanance window "
        else
            #Check if we have already flagged reboot is needed
            if [ ! -e $FLAG_REBOOT ]
            then
                if [ "$SELFHEAL_TYPE" = "BASE" ] && [ "$reboot_needed_atom_ro" -eq 1 ] && [ "$BOX_TYPE" != "rpi" ]; then
                    echo_t "RDKB_REBOOT : atom is read only, rebooting the device."
                    dmcli eRT setv Device.DeviceInfo.X_RDKCENTRAL-COM_LastRebootReason string atom_read_only
                    sh /etc/calc_random_time_to_reboot_dev.sh "ATOM_RO" &
                elif [ "$SELFHEAL_TYPE" = "BASE" -o "$SELFHEAL_TYPE" = "SYSTEMD" ] && [ "$thisIS_BCI" != "yes" ] && [ "$rebootNeededforbrlan1" -eq 1 ]
                then
                    echo_t "rebootNeededforbrlan1"
                    echo_t "RDKB_REBOOT : brlan1 interface is not up, rebooting the device."
                    echo_t "Setting Last reboot reason"
                    dmcli eRT setv Device.DeviceInfo.X_RDKCENTRAL-COM_LastRebootReason string brlan1_down
                    case $SELFHEAL_TYPE in
                        "BASE")
                            dmcli eRT setv Device.DeviceInfo.X_RDKCENTRAL-COM_LastRebootCounter int 1  #TBD: not in original DEVICE code
                        ;;
                        "TCCBR")
                        ;;
                        "SYSTEMD")
                        ;;
                    esac
                    echo_t "SET succeeded"
                    sh /etc/calc_random_time_to_reboot_dev.sh "" &
                else
                    echo_t "rebootDeviceNeeded"
                    sh /etc/calc_random_time_to_reboot_dev.sh "" &
                fi
                touch $FLAG_REBOOT
            else
                echo_t "Already waiting for reboot"
            fi
        fi  # [ $doMaintReboot -eq 0 ]
    fi  # [ $inMaintWindow -eq 1 ]
fi  # [ "$rebootDeviceNeeded" -eq 1 ]

#check firmware download script is running.
case $SELFHEAL_TYPE in
    "BASE")
        isPeriodicFWCheckEnable=`syscfg get PeriodicFWCheck_Enable`
        if [ "$isPeriodicFWCheckEnable" == "false" ]; then

            if [ "$BOX_TYPE" = "XB3" ]; then
                firmDwnldPid=`ps w | grep -w xb3_firmwareDwnld.sh | grep -v grep | awk '{print $1}'`
                if [ "$firmDwnldPid" == "" ]; then
                    echo_t "Restarting XB3 firmwareDwnld script"
                    exec  /etc/xb3_firmwareDwnld.sh &
                fi
            fi

        fi
    ;;
    "TCCBR")
        if [ "$BOX_TYPE" = "TCCBR" ]; then
            fDwnldPid=`ps w | grep -w cbr_firmwareDwnld.sh | grep -v grep | awk '{print $1}'`
            if [ "$fDwnldPid" == "" ]; then
                echo_t "Restarting CBR firmwareDwnld script"
                exec  /etc/cbr_firmwareDwnld.sh &
            fi
        fi
    ;;
    "SYSTEMD")
        if [ "$WAN_TYPE" = "EPON" ]; then
            fDwnldPid=`ps w | grep -w xf3_firmwareDwnld.sh | grep -v grep | awk '{print $1}'`
	elif [ "$BOX_TYPE" = "HUB4" ]; then
	    fDwnldPid=`ps w | grep -w Hub4_firmwareDwnld.sh | grep -v grep | awk '{print $1}'`
        else
            fDwnldPid=`ps w | grep -w xb6_firmwareDwnld.sh | grep -v grep | awk '{print $1}'`
        fi

        if [ "$fDwnldPid" == "" ]; then
            echo_t "Restarting firmwareDwnld script"
            systemctl stop CcspXconf.service
            systemctl start CcspXconf.service
        fi
    ;;
esac
