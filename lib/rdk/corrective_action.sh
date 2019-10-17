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

source /etc/log_timestamp.sh    # define 'echo_t' ASAP!
if [ -f /etc/device.properties ];then
source /etc/device.properties
fi

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


TAD_PATH="/usr/ccsp/tad/"
UTOPIA_PATH="/etc/utopia/service.d"
RDKLOGGER_PATH="/rdklogger"

case $SELFHEAL_TYPE in
    "BASE")
        ADVSEC_LAUNCH_SCRIPT=/usr/ccsp/pam/launch_adv_security.sh
        VERSION_FILE="/fss/gw/version.txt"
        source $UTOPIA_PATH/log_env_var.sh
        CM_INTERFACE=erouter0

        if [[ "$MODEL_NUM" = "DPC3939" || "$MODEL_NUM" = "DPC3941" ]]; then
            ADVSEC_PATH="/tmp/cujo_dnld/usr/ccsp/advsec/usr/libexec/advsec.sh"
        else
            ADVSEC_PATH="/usr/ccsp/advsec/usr/libexec/advsec.sh"
        fi

        if [ -f $ADVSEC_PATH ]
        then
            source $ADVSEC_PATH
        fi
    ;;
    "TCCBR")
        VERSION_FILE="/fss/gw/version.txt"
        source $UTOPIA_PATH/log_env_var.sh
        CM_INTERFACE=erouter0
    ;;
    "SYSTEMD")
        VERSION_FILE="/version.txt"
        ADVSEC_PATH="/usr/ccsp/advsec/usr/libexec/advsec.sh"

        if [ -f $ADVSEC_PATH ]
        then
            source $ADVSEC_PATH
        fi

        source $UTOPIA_PATH/log_env_var.sh
        WAN_INTERFACE=wan0
    ;;
esac

exec 3>&1 4>&2 >>$SELFHEALFILE 2>&1

voiceCallCompleted=0
xhsTraffic=0
CMRegComplete=0

level=128

DELAY=1

getstat() {
    grep 'cpu ' /proc/stat | sed -e 's/  */x/g' -e 's/^cpux//'
}

extract() {
    echo $1 | cut -d 'x' -f $2
}

change() {
    local e=$(extract $ENDSTAT $1)
    local b=$(extract $STARTSTAT $1)
    local diff=$(( $e - $b ))
    echo $diff
}

getVendorName()
{
    vendorName=`dmcli eRT getv Device.DeviceInfo.Manufacturer | grep value | awk '{print $5}'`
    if [ "$vendorName" = "" ]
    then
        case $SELFHEAL_TYPE in
            "BASE"|"SYSTEMD")
                if [ "x$WAN_TYPE" == "xEPON" ]
                then
                    vendorName=`cat /etc/device.properties | grep MANUFACTURE | cut -f2 -d=`
                else
                    vendorName=`cat /etc/device.properties | grep MFG_NAME | cut -f2 -d= | tr '[:lower:]' '[:upper:]'`
                fi
            ;;
            "TCCBR")
                #       if [ "x$WAN_TYPE" == "xEPON" ]
                #       then
                vendorName=`cat /etc/device.properties | grep MANUFACTURE | cut -f2 -d=`
                #       else
                #           vendorName=`cat /etc/device.properties | grep MFG_NAME | cut -f2 -d= | tr '[:lower:]' '[:upper:]'`
                #       fi
            ;;
        esac
    fi
    echo "$vendorName"
}

getModelName()
{
    modelName=`dmcli eRT getv Device.DeviceInfo.ModelName | grep value | awk '{print $5}'`
    if [ "$modelName" = "" ]
    then
        modelName=`cat /etc/device.properties | grep MODEL_NUM | cut -f2 -d=`
    fi
    echo "$modelName"
}

getDate()
{
    dandt_now=`date +'%Y:%m:%d:%H:%M:%S'`
    echo "$dandt_now"
}

getDateTime()
{
    dandtwithns_now=`date +'%Y-%m-%d:%H:%M:%S:%6N'`
    echo "$dandtwithns_now"
}

getCMMac()
{
    CMMac=`dmcli eRT getv Device.DeviceInfo.X_CISCO_COM_BaseMacAddress | grep value | awk '{print $5}'`
    case $SELFHEAL_TYPE in
        "BASE")
            if [ "$CMMac" = "" ]
            then
                if [ "x$WAN_TYPE" == "xEPON" ]
                then
                    CMMac=`ifconfig erouter0 | grep HWaddr | cut -d" " -f7`
                else
                    CMMac=`ifconfig erouter0 | grep HWaddr | cut -d" " -f7`
                fi
            fi
        ;;
        "TCCBR")
            if [ "$CMMac" = "" ]
            then
                CMMac=`snmpget -v2c -c public 172.31.255.45 1.3.6.1.2.1.2.2.1.6.2 | grep -o '[^ ]*$'`
            fi
        ;;
        "SYSTEMD")
            ETHWAN_MODE=`syscfg get eth_wan_enabled`
            if [ "$ETHWAN_MODE" = "true" ]; then
                CMMac=`sysevent get eth_wan_mac`
                if [ "$CMMac" = "" ] ; then
                    CMMac=`dmcli eRT getv Device.DeviceInfo.X_COMCAST-COM_CM_MAC | grep value | awk '{print $5}'`
                fi
            fi
        ;;
    esac
    echo "$CMMac"
}

checkConditionsbeforeAction()
{

    case $SELFHEAL_TYPE in
        "BASE")
            if [ "$1" != "RM" ] && [ "$WAN_TYPE" != "EPON" ]
            then

                isIPv4=`ifconfig $CM_INTERFACE | grep inet | grep -v inet6`
                if [ "$isIPv4" = "" ]
                then
                    isIPv6=`ifconfig $CM_INTERFACE | grep inet6 | grep "Scope:Global"`
                    if [ "$isIPv6" != "" ] || [ "$BOX_TYPE" == "rpi" ]
                    then
                        CMRegComplete=1
                    else
                        CMRegComplete=0
                        echo_t "RDKB_SELFHEAL : eCM is not fully registered on its CMTS,returning failure"
                        return 1
                    fi
                else
                    CMRegComplete=1
                fi
            fi
            loop=1
        ;;
        "TCCBR")
            if [ "$1" != "RM" ];then
                isIPv4=`ifconfig $CM_INTERFACE | grep inet | grep -v inet6`
                if [ "$isIPv4" = "" ]
                then
                    isIPv6=`ifconfig $CM_INTERFACE | grep inet6 | grep "Scope:Global"`
                    if [ "$isIPv6" != "" ] || [ "$BOX_TYPE" == "rpi" ]
                    then
                        CMRegComplete=1
                    else
                        CMRegComplete=0
                        echo_t "RDKB_SELFHEAL : eCM is not fully registered on its CMTS,returning failure"
                        return 1
                    fi
                else
                    CMRegComplete=1
                fi
            fi
            loop=1
        ;;
        "SYSTEMD")
            if [ "$1" != "RM" ] && [ "$WAN_TYPE" != "EPON" ] && [ "$WAN_TYPE" != "DSL" ];then
                isIPv4=`ifconfig $WAN_INTERFACE | grep inet | grep -v inet6`
                if [ "$isIPv4" = "" ]
                then
                    isIPv6=`ifconfig $WAN_INTERFACE | grep inet6 | grep "Scope:Global"`
                    if [ "$isIPv6" != "" ] || [ "$BOX_TYPE" == "rpi" ]
                    then
                        CMRegComplete=1
                    else
                        CMRegComplete=0
                        echo_t "RDKB_SELFHEAL : eCM is not fully registered on its CMTS,returning failure"
                        return 1
                    fi
                else
                    CMRegComplete=1
                fi
            fi
        ;;
    esac

    printOnce=1
    while : ; do

        #xhs traffic implementation pending
	if [ "$BOX_TYPE" != "rpi" ]
	then
        xhsTraffic=1
        /usr/bin/XconfHttpDl http_reboot_status
        voicecall_status=$?
        if [ "$voicecall_status" -eq 0 ]
        then
            echo_t "RDKB_SELFHEAL : No active voice call traffic currently"
            voiceCallCompleted=1
        else
            if [ "$printOnce" -eq 1 ]
            then
                echo_t "RDKB_SELFHEAL : Currently there is active call, wait for active call to finish"
                voiceCallCompleted=0
                printOnce=0
            fi

        fi

        if [ "$voiceCallCompleted" -eq 1 ] && [ "$xhsTraffic" -eq 1 ]
        then
            return 0
        fi
	fi
        case $SELFHEAL_TYPE in
            "BASE"|"TCCBR")
                if [ "$loop" -ge 60 ]; then
                    echo_t "RDKB_SELFHEAL : Counter reached max, Not taking corrective action"
                    return 1
                fi
                loop=$((loop+1))
                sleep 10
            ;;
            "SYSTEMD")
                sleep 2
            ;;
        esac
    done

}

resetRouter()
{
    #!!! TODO: merge this $SELFHEAL_TYPE block !!!
    case $SELFHEAL_TYPE in
        "BASE")
            if [ "$WAN_TYPE" != "EPON" ]
            then
                isIPv4=`ifconfig $CM_INTERFACE | grep inet | grep -v inet6`
                if [ "$isIPv4" = "" ]
                then
                    isIPv6=`ifconfig $CM_INTERFACE | grep inet6 | grep "Scope:Global"`
                    if [ "$isIPv6" != "" ] || [ "$BOX_TYPE" == "rpi" ]
                    then
                        CMRegComplete=1
                    else
                        CMRegComplete=0
                        echo_t "RDKB_SELFHEAL : eCM is not fully registered on its CMTS,returning failure"
                        return 1
                    fi
                else
                    CMRegComplete=1
                fi
            else
                CMRegComplete=1
            fi
        ;;
        "TCCBR")
            isIPv4=`ifconfig $CM_INTERFACE | grep inet | grep -v inet6`
            if [ "$isIPv4" = "" ]
            then
                isIPv6=`ifconfig $CM_INTERFACE | grep inet6 | grep "Scope:Global"`
                if [ "$isIPv6" != "" ] || [ "$BOX_TYPE" == "rpi" ]
                then
                    CMRegComplete=1
                else
                    CMRegComplete=0
                    echo_t "RDKB_SELFHEAL : eCM is not fully registered on its CMTS,returning failure"
                    return 1
                fi
            else
                CMRegComplete=1
            fi
        ;;
        "SYSTEMD")
            if [ "$WAN_TYPE" != "EPON" ]
            then
                isIPv4=`ifconfig $WAN_INTERFACE | grep inet | grep -v inet6`
                if [ "$isIPv4" = "" ]
                then
                    isIPv6=`ifconfig $WAN_INTERFACE | grep inet6 | grep "Scope:Global"`
                    if [ "$isIPv6" != "" ] || [ "$BOX_TYPE" == "rpi" ]
                    then
                        CMRegComplete=1
                    else
                        CMRegComplete=0
                        echo_t "RDKB_SELFHEAL : eCM is not fully registered on its CMTS,returning failure"
                        return 1
                    fi
                else
                    CMRegComplete=1
                fi
            else
                CMRegComplete=1
            fi
        ;;
    esac

    if [ "$CMRegComplete" -eq 1 ]
    then

        echo_t "RDKB_SELFHEAL : DNS Information :"
        cat /etc/resolv.conf
        echo_t "-------------------------------------------------------"
        echo_t "RDKB_SELFHEAL : IPtable rules:"
        iptables -S
        echo_t "-------------------------------------------------------"
        echo_t "RDKB_SELFHEAL : Ipv4 Route Information:"
        ip route
        echo_t "-------------------------------------------------------"
        echo_t "RDKB_SELFHEAL : IProute Information:"
        route
        echo_t "-------------------------------------------------------"

        echo_t "-------------------------------------------------------"
        echo_t "RDKB_SELFHEAL : IP6table rules:"
        ip6tables -S
        echo_t "-------------------------------------------------------"
        echo_t "RDKB_SELFHEAL : Ipv6 Route Information:"
        ip -6 route
        echo_t "-------------------------------------------------------"

	dmcli eRT setv Device.DeviceInfo.X_RDKCENTRAL-COM_LastRebootReason string PING_Connectivity_Test_Failure

        echo_t "RDKB_REBOOT : Reset router due to PING connectivity test failure"

	
        #dmcli eRT setv Device.X_CISCO_COM_DeviceControl.RebootDevice string Router
	sleep 3
	reboot

    fi

}

rebootNeeded()
{
    # Check and proceed further action based on diagnostic mode
    # if return value is 1 then box is not in diagnostic mode
    # if return value is 0 then box is in diagnostic mode
    CheckAndProceedFurtherBasedonDiagnosticMode
    return_value=$?

    if [ "$return_value" -eq 0 ]
    then
        return
    fi

    # Check for max subsystem reboot
    # Implement as a indipendent script which can be accessed across both connectivity and resource scripts
    storedTime=`syscfg get lastActiontakentime`


    if [ "$storedTime" != "" ] || [ "$storedTime" -ne 0 ]
    then
        currTime=$(date -u +"%s")
        diff=$(($currTime-$storedTime))
        diff_in_minutes=$(($diff / 60))
        diff_in_hours=$(($diff_in_minutes / 60))
        if [ "$diff_in_hours" -ge 24 ]
        then

            sh $TAD_PATH/selfheal_reset_counts.sh

        fi

    fi
    case $SELFHEAL_TYPE in
        "BASE")
            HIGHLOADAVG_REBOOT_COUNT=`syscfg get highloadavg_reboot_count`
            if [ "$HIGHLOADAVG_REBOOT_COUNT" -ge 1 ] && [ "$2" == "ATOM_HIGH_LOADAVG" ] && [ "$BOX_TYPE" != "rpi" ]
            then
                echo_t "RDKB_SELFHEAL : Today's max reboot count already reached for High load average on Atom"
                return
            fi
        ;;
        "TCCBR")
        ;;
        "SYSTEMD")
        ;;
    esac

    MAX_REBOOT_COUNT=`syscfg get max_reboot_count`
    TODAYS_REBOOT_COUNT=`syscfg get todays_reboot_count`

    if [ "$TODAYS_REBOOT_COUNT" -ge "$MAX_REBOOT_COUNT" ]
    then
        echo_t "RDKB_SELFHEAL : Today's max reboot count already reached, please wait for reboot till next 24 hour window"
    else

        # Wait for Active Voice call,XHS client passing traffic,eCM registrations state completion.
	if [ "$BOX_TYPE" != "rpi" ]; then
        checkConditionsbeforeAction $1   

        return_value=$?
	fi
	return_value=0
        if [ "$return_value" -eq 0 ]
        then
            # Storing Information before corrective action
            storeInformation


            #touch $REBOOTNEEDED
            TODAYS_REBOOT_COUNT=$(($TODAYS_REBOOT_COUNT+1))
            syscfg set todays_reboot_count $TODAYS_REBOOT_COUNT
            syscfg commit
            vendor=`getVendorName`
            modelName=`getModelName`
            CMMac=`getCMMac`
            timestamp=`getDate`

            echo_t "RDKB_SELFHEAL : Today's reboot count is $TODAYS_REBOOT_COUNT "
            echo_t "RDKB_SELFHEAL : <$level>CABLEMODEM[$vendor]:<99000000><$timestamp><$CMMac><$modelName> $1 Rebooting device as part of corrective action"

            if [ "$storedTime" == "" ] || [ "$storedTime" -eq 0 ]
            then
                storedTime=$(date -u +"%s")
                syscfg set lastActiontakentime $storedTime
                syscfg commit
            fi

            case $SELFHEAL_TYPE in
                "BASE"|"TCCBR")
                    if [ "$1" == "ATOM_HANG" ] && [ "$BOX_TYPE" != "rpi" ]
                    then
                        SetRebootConfigForAtomHang
                    fi
                ;;
                "SYSTEMD")
                    # TBD: do same as for BASE,TCCBR?
                ;;
            esac
            case $SELFHEAL_TYPE in
                "BASE"|"SYSTEMD")
                    echo_t "Setting Last reboot reason as $3"
                    setRebootreason $3 $4
                ;;
                "TCCBR")
                    # TBD: do same as for BASE,SYSTEMD?
                ;;
            esac

            if [ "$2" == "CPU" ] || [ "$2" == "MEM" ]
            then
                echo_t "RDKB_REBOOT : Rebooting device due to $2 threshold reached"
            elif [ "$2" == "DS_MANAGER_HIGH_CPU" ]
            then
                echo_t "RDKB_REBOOT : Rebooting due to downstream_manager process having high CPU"
                echo_t "DS_MANAGER_HIGH_CPU : Rebooting due to downstream_manager process having high CPU"
            elif [ "$SELFHEAL_TYPE" = "BASE" ] && [ "$2" == "ATOM_HIGH_LOADAVG" ]
            then
                echo_t "RDKB_REBOOT : Rebooting due to $2 threshold reached"
                syscfg set highloadavg_reboot_count 1
                syscfg commit
            else
                echo_t "RDKB_REBOOT : Rebooting device due to $2"
            fi
            $RDKLOGGER_PATH/backupLogs.sh "true" "$2"
        fi
    fi

}

# This function will check if captive portal needs to be enabled or not.
checkCaptivePortal()
{

    # Get all flags from DBs
    isWiFiConfigured=`syscfg get redirection_flag`
    psmNotificationCP=`psmcli get eRT.com.cisco.spvtg.ccsp.Device.WiFi.NotifyWiFiChanges`

    #Read the http response value
    networkResponse=`cat /var/tmp/networkresponse.txt`

    iter=0
    max_iter=2
    case $SELFHEAL_TYPE in
        "BASE"|"TCCBR")
            PandM_wait_timeout=600
            PandM_wait_count=0
        ;;
        "SYSTEMD")
            # Note: original SYSTEMD code would loop forever; should be OK to put some limit on it same as others!!!
            #PandM_wait_timeout=600
            #PandM_wait_count=0
        ;;
    esac
    while [ "$psmNotificationCP" = "" ] && [ "$iter" -le $max_iter ]
    do
        iter=$((iter+1))
        echo "$iter"
        psmNotificationCP=`psmcli get eRT.com.cisco.spvtg.ccsp.Device.WiFi.NotifyWiFiChanges`
    done

    echo_t "RDKB_SELFHEAL : NotifyWiFiChanges is $psmNotificationCP"
    echo_t "RDKB_SELFHEAL : redirection_flag val is $isWiFiConfigured"

    if [ "$isWiFiConfigured" = "true" ]
    then
        if [ "$networkResponse" = "204" ] && [ "$psmNotificationCP" = "true" ]
        then
            # Check if P&M is up and able to find the captive portal parameter
            while : ; do
                echo_t "RDKB_SELFHEAL : Waiting for PandM to initalize completely to set ConfigureWiFi flag"
                CHECK_PAM_INITIALIZED=`find /tmp/ -name "pam_initialized"`
                echo_t "RDKB_SELFHEAL : CHECK_PAM_INITIALIZED is $CHECK_PAM_INITIALIZED"
                if [ "$CHECK_PAM_INITIALIZED" != "" ]
                then
                    echo_t "RDKB_SELFHEAL : WiFi is not configured, setting ConfigureWiFi to true"
                    output=`dmcli eRT setvalues Device.DeviceInfo.X_RDKCENTRAL-COM_ConfigureWiFi bool TRUE`
                    check_success=`echo $output | grep  "Execution succeed."`
                    if [ "$check_success" != "" ]
                    then
                        echo_t "RDKB_SELFHEAL : Setting ConfigureWiFi to true is success"
                    else
                        echo "$output"
                    fi
                    break
                fi
                case $SELFHEAL_TYPE in
                    "BASE"|"TCCBR")
                        PandM_wait_count=$(($PandM_wait_count+2))
                        if [ "$PandM_wait_count" -gt "$PandM_wait_timeout" ]
                        then
                            echo_t "RDKB_SELFHEAL : PandM_wait_count reached timeout value, exiting from checkCaptivePortal function"
                            break
                        fi
                    ;;
                    "SYSTEMD")
                        # Note: original SYSTEMD code would loop forever; should be OK to put some limit on it same as others!!!
                    ;;
                esac
                sleep 2
            done
        else
            echo_t "RDKB_SELFHEAL : We have not received a 204 response or PSM valus is not in sync"
        fi
    else
        echo_t "RDKB_SELFHEAL : Syscfg DB value is : $isWiFiConfigured"
    fi

}

resetNeeded()
{
    # Check and proceed further action based on diagnostic mode
    # if return value is 1 then box is not in diagnostic mode
    # if return value is 0 then box is in diagnostic mode
    CheckAndProceedFurtherBasedonDiagnosticMode
    return_value=$?

    if [ "$return_value" -eq 0 ]
    then
        return
    fi

    folderName=$1
    ProcessName=$2

    BASEQUEUE=1
    keepalive_args="-n `sysevent get wan_ifname` -e 1"

    export LD_LIBRARY_PATH=$PWD:.:$PWD/../../lib:$PWD/../../.:/lib:/usr/lib:$LD_LIBRARY_PATH
    export DBUS_SYSTEM_BUS_ADDRESS=unix:path=/var/run/dbus/system_bus_socket

    BINPATH="/usr/bin"

    if [ -f /tmp/cp_subsys_ert ]; then
        Subsys="eRT."
        elif [ -e ./cp_subsys_emg ]; then
        Subsys="eMG."
    else
        Subsys=""
    fi

    storedTime=`syscfg get lastActiontakentime`

    if [ "$storedTime" != "" ] || [ "$storedTime" -ne 0 ]
    then
        currTime=$(date -u +"%s")
        diff=$(($currTime-$storedTime))
        diff_in_minutes=$(($diff / 60))
        diff_in_hours=$(($diff_in_minutes / 60))

        if [ "$diff_in_hours" -ge 24 ]
        then
            sh $TAD_PATH/selfheal_reset_counts.sh

        fi

    fi


    MAX_RESET_COUNT=`syscfg get max_reset_count`
    TODAYS_RESET_COUNT=`syscfg get todays_reset_count`

    # RDKB-6012: No need to validate today's reset count
    if [ "$ProcessName" != "PING" ]
    then
        TODAYS_RESET_COUNT=0
    fi

    if [ "$TODAYS_RESET_COUNT" -ge "$MAX_RESET_COUNT" ] && [ "$ProcessName" == "PING" ]
    then
        echo_t "RDKB_SELFHEAL : Today's max reset count already reached, please wait for reset till next 24 hour window"
    else
        #touch $RESETNEEDED

        case $SELFHEAL_TYPE in
            "BASE"|"TCCBR")
                #checkConditionsbeforeAction
                #return_value=$?
                return_value=0  # HACK, to execute next 'if'
            ;;
            "SYSTEMD")
                checkConditionsbeforeAction
                return_value=$?
            ;;
        esac

        if [ "$return_value" -eq 0 ]
        then
            # RDKB-6012: No need to validate today's reset count
            #TODAYS_RESET_COUNT=$(($TODAYS_RESET_COUNT+1))

            #syscfg set todays_reset_count $TODAYS_RESET_COUNT
            #syscfg commit

            timestamp=`getDate`

            # Storing Information before corrective action
            case $SELFHEAL_TYPE in
                "BASE"|"TCCBR")
                    if [ "$ProcessName" == "CcspMoCA" ]; then
                        storeInformation "moca"
                    else
                        storeInformation
                    fi
                ;;
                "SYSTEMD")
                    storeInformation
                ;;
            esac

            vendor=`getVendorName`
            modelName=`getModelName`
            CMMac=`getCMMac`
            echo_t "RDKB_SELFHEAL : <$level>CABLEMODEM[$vendor]:<99000007><$timestamp><$CMMac><$modelName> RM $ProcessName process not running , restarting it"

            case $SELFHEAL_TYPE in
                "BASE"|"TCCBR")
                ;;
                "SYSTEMD")
                    cd /usr/ccsp
                ;;
            esac
            if [ "$storedTime" == "" ] || [ "$storedTime" -eq 0 ]
            then
                storedTime=$(date -u +"%s")
                syscfg set lastActiontakentime $storedTime
                syscfg commit
            fi

            if [ "$SELFHEAL_TYPE" = "BASE" -o "$SELFHEAL_TYPE" = "TCCBR" ] && [ "$ProcessName" == "snmp_subagent" ]
            then
                case $SELFHEAL_TYPE in
                    "BASE")
                        echo_t "RDKB_SELFHEAL : Resetting process $ProcessName"
                        cd /fss/gw/usr/ccsp/snmp/
                        if [ "$DEVICE_MODEL" = "TCHXB3" ]; then
                            sh run_subagent.sh tcp:127.0.0.1:705 &
                        else
                            sh run_subagent.sh /var/tmp/cm_snmp_ma &
                        fi
                        cd -
                    ;;
                    "TCCBR")
                        echo_t "RDKB_SELFHEAL : Resetting process $ProcessName"
                        cd /usr/ccsp/snmp/
                        sh run_subagent.sh /var/tmp/cm_snmp_ma &
                        cd -
                    ;;
                    "SYSTEMD")
                    ;;
                esac
            elif [ "$SELFHEAL_TYPE" = "BASE" -o "$SELFHEAL_TYPE" = "TCCBR" ] && [ "$ProcessName" == "CcspPandMSsp" ]
            then
                echo_t "RDKB_SELFHEAL : Resetting process $ProcessName"
                cd /usr/ccsp/pam/
		killall CcspWifiSsp  ### for temp fix
                $BINPATH/CcspPandMSsp -subsys $Subsys
                cd -
                # We need to check whether to enable captive portal flag
                checkCaptivePortal
            elif [ "$SELFHEAL_TYPE" = "BASE" -o "$SELFHEAL_TYPE" = "SYSTEMD" ] && [ "$ProcessName" == "CcspHomeSecurity" ]
            then
                echo_t "RDKB_SELFHEAL : Resetting process $ProcessName"
                CcspHomeSecurity 8081&

            elif [ "$ProcessName" == "CcspWifiSsp" ] && [ "$BOX_TYPE" == "rpi" ]
            then
                echo_t "RDKB_SELFHEAL : Resetting process $ProcessName"
                cd /usr/ccsp/wifi/
                $BINPATH/CcspWifiSsp -subsys $Subsys
                cd -
            
            elif [ "$ProcessName" == "CcspHotspot" ]
			then
				echo_t "RDKB_SELFHEAL : Resetting process $ProcessName"
				cd /usr/ccsp/hotspot
				$BINPATH/CcspHotspot -subsys $Subsys > /dev/null &
				cd -

            elif [ "$ProcessName" == "hotspotfd" ]
            then
                echo_t "RDKB_SELFHEAL : Resetting process $ProcessName"
                hotspotfd $keepalive_args  > /dev/null &
            elif [ "$ProcessName" == "dhcp_snooperd" ]
            then
                echo_t "RDKB_SELFHEAL : Resetting process $ProcessName"
                dhcp_snooperd -q $BASEQUEUE -n 2 -e 1  > /dev/null &

            elif [ "$ProcessName" == "hotspot_arpd" ]
            then
                echo_t "RDKB_SELFHEAL : Resetting process $ProcessName"
                hotspot_arpd -q 0  > /dev/null &

            elif [ "$SELFHEAL_TYPE" = "BASE" -o "$SELFHEAL_TYPE" = "TCCBR" ] && [ "$ProcessName" == "CcspLMLite" ]
            then
                echo_t "RDKB_SELFHEAL : Resetting process $ProcessName"
                cd /usr/ccsp/lm
                $BINPATH/$ProcessName -subsys $Subsys
                cd -

            elif [ "$SELFHEAL_TYPE" = "BASE" -o "$SELFHEAL_TYPE" = "TCCBR" ] && [ "$ProcessName" == "CcspXdnsSsp" ]
            then
                echo_t "RDKB_SELFHEAL : Resetting process $ProcessName"
                cd /usr/ccsp/xdns
                $BINPATH/$ProcessName -subsys $Subsys
                cd -

            elif [ "$SELFHEAL_TYPE" = "BASE" -o "$SELFHEAL_TYPE" = "TCCBR" ] && [ "$ProcessName" == "CcspEthAgent" ]
            then
                echo_t "RDKB_SELFHEAL : Resetting process $ProcessName"
                cd /usr/ccsp/ethagent
                $BINPATH/$ProcessName -subsys $Subsys
                cd -

            elif [ "$SELFHEAL_TYPE" = "BASE" -o "$SELFHEAL_TYPE" = "TCCBR" ] && [ "$ProcessName" == "PsmSsp" ]
            then
                echo_t "RDKB_SELFHEAL : Resetting process $ProcessName"
                cd /usr/ccsp
                $BINPATH/PsmSsp -subsys $Subsys
                cd -

            elif [ "$SELFHEAL_TYPE" = "BASE" ] && [ "$ProcessName" == "CcspTr069PaSsp" ]
            then
                echo_t "RDKB_SELFHEAL : Resetting process $ProcessName"
                cd /usr/ccsp/tr069pa
                $BINPATH/CcspTr069PaSsp -subsys $Subsys
                cd -

            elif [ "$SELFHEAL_TYPE" = "BASE" -o "$SELFHEAL_TYPE" = "TCCBR" ] && [ "$ProcessName" == "CcspCMAgentSsp" ]
            then
                echo_t "RDKB_SELFHEAL : Resetting process $ProcessName"
                cd /usr/ccsp/cm
                $BINPATH/CcspCMAgentSsp -subsys $Subsys
                cd -

            elif [ "$SELFHEAL_TYPE" = "BASE" ] && [ "$ProcessName" == "CcspEPONAgentSsp" ]
            then
                echo_t "RDKB_SELFHEAL : Resetting process $ProcessName"
                cd /usr/ccsp/$folderName
                $BINPATH/$ProcessName -subsys $Subsys
                cd -

            elif [ "$SELFHEAL_TYPE" = "BASE" -o "$SELFHEAL_TYPE" = "TCCBR" ] && [ "$ProcessName" == "CcspMtaAgentSsp" ]
            then
                echo_t "RDKB_SELFHEAL : Resetting process $ProcessName"
                cd /usr/ccsp/mta
                $BINPATH/CcspMtaAgentSsp -subsys $Subsys
                cd -

            elif [ "$SELFHEAL_TYPE" = "BASE" ] && [ "$ProcessName" == "CcspMoCA" ]
            then
                echo_t "RDKB_SELFHEAL : Resetting process $ProcessName"
                cd /usr/ccsp/moca
                $BINPATH/CcspMoCA -subsys $Subsys
                cd -

            elif [ "$SELFHEAL_TYPE" = "BASE" -o "$SELFHEAL_TYPE" = "TCCBR" ] && [ "$ProcessName" == "CcspTandDSsp" ]
            then
                echo_t "RDKB_SELFHEAL : Resetting process $ProcessName"
                SelfHealScript_PID=`pidof self_heal_connectivity_test.sh`
                if [ "$SelfHealScript_PID" != "" ]; then
                    kill -9 $SelfHealScript_PID
                fi

                SelfHealScript_PID=`pidof resource_monitor.sh`
                if [ "$SelfHealScript_PID" != "" ]; then
                    kill -9 $SelfHealScript_PID
                fi

                cd /usr/ccsp/tad
                $BINPATH/CcspTandDSsp -subsys $Subsys
                cd -

            elif [ "$SELFHEAL_TYPE" = "BASE" ] && [ "$ProcessName" = "CcspAdvSecuritySsp" ]
            then
                if [ -f $ADVSEC_AGENT_SHUTDOWN ]; then
                    rm $ADVSEC_AGENT_SHUTDOWN
                else
                    echo_t "RDKB_SELFHEAL : Resetting process $ProcessName"
                fi
                if [ -f $ADVSEC_LAUNCH_SCRIPT ]; then
                    $ADVSEC_LAUNCH_SCRIPT -start &
                fi

            elif [ "$SELFHEAL_TYPE" = "BASE" -o "$SELFHEAL_TYPE" = "SYSTEMD" ] && [ "$folderName" = "advsec_bin" ]
            then
                if [ "$ProcessName" = "AdvSecurityAgent" ] || [ "$ProcessName" = "AdvSecurityRabid" ]
                then
                    if [ -f $ADVSEC_AGENT_SHUTDOWN ]; then
                        rm $ADVSEC_AGENT_SHUTDOWN
                    else
                        echo_t "RDKB_SELFHEAL : Resetting process CcspAdvSecuritySsp $ProcessName"
                    fi
                    if [ "$ProcessName" = "AdvSecurityAgent" ]; then
                        advsec_restart_agent
                    else
                        advsec_restart_rabid
                    fi
                elif [ "$ProcessName" = "AdvSecurityDns" ]
                then
                    advsec_start_process dnscap
                elif [ "$ProcessName" = "AdvSecurityDhcp" ]
                then
                    advsec_start_process dhcpcap
                elif [ "$ProcessName" = "AdvSecurityMdns" ]
                then
                    advsec_start_process mdnscap
                elif [ "$ProcessName" = "AdvSecurityPof" ]
                then
                    advsec_start_process p0f
                elif [ "$ProcessName" = "AdvSecuritySoftflowd" ]
                then
                    advsec_start_process softflowd
                elif [ "$ProcessName" = "AdvSecurityScanner" ]
                then
                    advsec_start_process scannerd
                elif [ "$ProcessName" = "AdvSecurityThreat" ]
                then
                    advsec_start_process threatd
                fi

            elif [ "$ProcessName" == "PING" ]
            then
                REBOOTINTERVAL=`syscfg get router_reboot_Interval`
                LAST_REBOOT=`syscfg get last_router_reboot_time`
                currTime=$(date -u +"%s")
                diff=$(($currTime-$LAST_REBOOT))
		echo "diff and last_reboot $diff and $REBOOTINTERVAL"
                if [ $diff -ge $REBOOTINTERVAL ]
                then
                    TODAYS_RESET_COUNT=$(($TODAYS_RESET_COUNT+1))
                    syscfg set todays_reset_count $TODAYS_RESET_COUNT
                    syscfg commit
                    syscfg set last_router_reboot_time $currTime
                    syscfg commit
		    echo "Ping reset Router"
                    resetRouter
                fi

            elif [ "$3" == "noSubsys" ]
            then
                echo_t "RDKB_SELFHEAL : Resetting process $ProcessName"
                cd $BINPATH
                ./$ProcessName &
                cd -

            else
                echo_t "RDKB_SELFHEAL : Resetting process $ProcessName"
                cd $BINPATH
                ./$ProcessName -subsys $Subsys
                cd -
            fi
        fi  # $return_value

    fi  # [ "$TODAYS_RESET_COUNT" -ge "$MAX_RESET_COUNT" ] && [ "$ProcessName" == "PING" ]

}


storeInformation()
{

    case $SELFHEAL_TYPE in
        "BASE")
            # Check if request is for P&M Reset
            isMOCA=0    # if non-MoCA crash, get MoCA parameters
            if [ "$1" = "moca" ]
            then
                isMOCA=1    # If the crashed process is MoCA, we cannot get MoCA parameters
            fi
        ;;
        "TCCBR")
            isMOCA=1    # (BUGGY?)original TCCBR code never showed MoCA parameters (TBD: but now show alternative?!)
        ;;
        "SYSTEMD")
            isMOCA=0    # (BUGGY?)original SYSTEMD code always showed MoCA parameters
        ;;
    esac
    totalMemSys=`free | awk 'FNR == 2 {print $2}'`
    usedMemSys=`free | awk 'FNR == 2 {print $3}'`
    freeMemSys=`free | awk 'FNR == 2 {print $4}'`

    # AvgCpuUsed=`grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print usage "%"}'`

    #   echo "[`getDateTime`] RDKB_SYS_MEM_INFO_SYS : Total memory in system is $totalMemSys"
    #   echo "[`getDateTime`] RDKB_SYS_MEM_INFO_SYS : Used memory in system is $usedMemSys"
    #   echo "[`getDateTime`] RDKB_SYS_MEM_INFO_SYS : Free memory in system is $freeMemSys"

    echo_t "RDKB_SELFHEAL : Total memory in system is $totalMemSys"
    echo_t "RDKB_SELFHEAL : Used memory in system is $usedMemSys"
    echo_t "RDKB_SELFHEAL : Free memory in system is $freeMemSys"

    #Record the start statistics
    STARTSTAT=$(getstat)

    sleep $DELAY

    #Record the end statistics
    ENDSTAT=$(getstat)

    USR=$(change 1)
    SYS=$(change 3)
    IDLE=$(change 4)
    IOW=$(change 5)
    case $SELFHEAL_TYPE in
        "BASE"|"SYSTEMD")
            IRQ=$(change 6)
            SIRQ=$(change 7)
            STEAL=$(change 8)
        ;;
        "TCCBR")
            IRQ=0   # TODO?: $(change 6)
            SIRQ=0   # TODO?: $(change 7)
            STEAL=0   # TODO?: $(change 8)
        ;;
    esac

    ACTIVE=$(( $USR + $SYS + $IOW + $IRQ + $SIRQ + $STEAL))

    TOTAL=$(($ACTIVE + $IDLE))

    Curr_CPULoad=$(( $ACTIVE * 100 / $TOTAL ))

    echo_t "RDKB_SELFHEAL : Current CPU load is $Curr_CPULoad"

    echo_t "RDKB_SELFHEAL : Top 5 tasks running on device with resource usage are below"
    top -bn1 | head -n10 | tail -6

    for index in 1 2 3 5 6
    do

        numberOfEntries=`dmcli eRT getv Device.WiFi.AccessPoint.$index.AssociatedDeviceNumberOfEntries | grep value | awk '{print $5}'`

        if [ 0$numberOfEntries -ne 0 ]
        then
            assocDev=1
            while [ $assocDev -le 0$numberOfEntries ]
            do
                MACADDRESS=`dmcli eRT getv Device.WiFi.AccessPoint.$index.AssociatedDevice.$assocDev.MACAddress | grep value | awk '{print $5}'`
                RSSI=`dmcli eRT getv Device.WiFi.AccessPoint.$index.AssociatedDevice.$assocDev.SignalStrength | grep value | awk '{print $5}'`
                echo_t "RDKB_SELFHEAL : Device $MACADDRESS connected on AccessPoint $index and RSSI is $RSSI dBm"
                assocDev=$(($assocDev+1))
            done
        fi
    done

    for radio_index in 1 2
    do
        channel=`dmcli eRT getv Device.WiFi.Radio.$radio_index.Channel | grep value | awk '{print $5}'`
        if [ "$radio_index" -eq 1 ]
        then
            echo_t "RDKB_SELFHEAL : 2.4GHz radio is operating on $channel channel"
        else
            echo_t "RDKB_SELFHEAL : 5GHz radio is operating on $channel channel"
        fi
    done

    # If the crashed process is MoCA, we cannot get MoCA parameters
    if [ $isMOCA -eq 0 ] && [ "$BOX_TYPE" != "rpi" ]
    then
        # Need to capture MoCA stats

        PacketsSent=`dmcli eRT getv Device.MoCA.Interface.1.Stats.PacketsSent | grep value | awk '{print $5}'`
        PacketsReceived=`dmcli eRT getv Device.MoCA.Interface.1.Stats.PacketsReceived | grep value | awk '{print $5}'`
        ErrorsSent=`dmcli eRT getv Device.MoCA.Interface.1.Stats.ErrorsSent | grep value | awk '{print $5}'`
        ErrorsReceived=`dmcli eRT getv Device.MoCA.Interface.1.Stats.ErrorsReceived | grep value | awk '{print $5}'`
        DiscardPacketsSent=`dmcli eRT getv Device.MoCA.Interface.1.Stats.DiscardPacketsSent | grep value | awk '{print $5}'`
        DiscardPacketsReceived=`dmcli eRT getv Device.MoCA.Interface.1.Stats.DiscardPacketsReceived | grep value | awk '{print $5}'`

        EgressNumFlows=`dmcli eRT getv Device.MoCA.Interface.1.QoS.EgressNumFlows | grep value | awk '{print $5}'`
        IngressNumFlows=`dmcli eRT getv Device.MoCA.Interface.1.QoS.IngressNumFlows | grep value | awk '{print $5}'`

        echo_t "RDKB_SELFHEAL : MoCA Statistics info is below"
        echo_t "RDKB_SELFHEAL : PacketsSent=$PacketsSent PacketsReceived=$PacketsReceived ErrorsSent=$ErrorsSent ErrorsReceived=$ErrorsReceived"

        echo_t "RDKB_SELFHEAL : DiscardPacketsSent=$DiscardPacketsSent DiscardPacketsReceived=$DiscardPacketsReceived"
        echo_t "RDKB_SELFHEAL : EgressNumFlows=$EgressNumFlows IngressNumFlows=$IngressNumFlows"
    else
        case $SELFHEAL_TYPE in
            "BASE")
                echo_t "RDKB_SELFHEAL : MoCA stats are not available due to MoCA crash"
                isMOCA=0
            ;;
            "TCCBR")
                #TODO: enable:        echo_t "RDKB_SELFHEAL : MoCA stats are not available due to MoCA crash"
                #TODO: enable:        isMOCA=0
            ;;
            "SYSTEMD")
            ;;
        esac
    fi

}

logNetworkInfo()
{
    case $SELFHEAL_TYPE in
        "BASE")
            echo_t "RDKB_SELFHEAL : interface l2sd0 :"
            ifconfig l2sd0;
            echo_t "-------------------------------------------------------"
            echo_t "RDKB_SELFHEAL : interface l2sd0.100 :"
            ifconfig l2sd0.100;
            echo_t "-------------------------------------------------------"
            echo_t "RDKB_SELFHEAL : interface l2sd0.101 :"
            ifconfig l2sd0.101;
            echo_t "-------------------------------------------------------"
            echo_t "RDKB_SELFHEAL : ip link :"
            ip link | grep l2sd0
            echo_t "-------------------------------------------------------"
        ;;
        "TCCBR")
        ;;
        "SYSTEMD")
        ;;
    esac
    echo_t "RDKB_SELFHEAL : brctl o/p :"
    brctl show
    echo_t "-------------------------------------------------------"
    echo_t "RDKB_SELFHEAL : ip route list o/p :"
    ip route list
    echo_t "-------------------------------------------------------"
    echo_t "RDKB_SELFHEAL : ip route list table 15 o/p :"
    ip route list table 15
    echo_t "-------------------------------------------------------"
    echo_t "RDKB_SELFHEAL : ip route list table 14 o/p :"
    ip route list table 14
    echo_t "-------------------------------------------------------"
    echo_t "RDKB_SELFHEAL : ip route list table all_lans o/p :"
    ip route list table all_lans
    echo_t "-------------------------------------------------------"

    case $SELFHEAL_TYPE in
        "BASE"|"TCCBR")
            #   /rdklogger/backupLogs.sh "false" "l2sd0"
        ;;
        "SYSTEMD")
            #The Parameter l2sd0 in this instance is telling the script that it's being called
            # for information and not due to a crashed process. This should be refactored
            /rdklogger/backupLogs.sh "false" "l2sd0"
        ;;
    esac

}

case $SELFHEAL_TYPE in
    "BASE"|"TCCBR")
        # NOTE: 'CheckRebootCretiriaForAtomHang' was originally defined only for 'BASE' and 'TCCBR' mode!
        # NOTE: 'SetRebootConfigForAtomHang' was originally defined only for 'BASE' and 'TCCBR' mode!
        CheckRebootCretiriaForAtomHang()
        {
            # As per requirement we need to reboot one time because of this case
            storedRebootTime=`syscfg get lastActiontakentimeforAtomHang`

            if [ "$storedRebootTime" != "" ] || [ "$storedRebootTime" -ne 0 ]
            then
                currSysTime=$(date -u +"%s")
                total_diff=$(($currSysTime-$storedRebootTime))
                total_diff_in_minutes=$(($total_diff / 60))
                total_diff_in_hours=$(($total_diff_in_minutes / 60))
                if [ "$total_diff_in_hours" -ge 24 ]
                then
                    # Reset the stored DB values
                    syscfg set todays_atom_reboot_count 0
                    syscfg set lastActiontakentimeforAtomHang 0

                    syscfg commit
                fi
            fi
        }

        SetRebootConfigForAtomHang()
        {
            # Set the reboot configuration for atom hang
            storedRebootTime=$(date -u +"%s")
            syscfg set lastActiontakentimeforAtomHang $storedRebootTime

            TODAYS_ATOM_REBOOT_COUNT=$(($TODAYS_ATOM_REBOOT_COUNT+1))
            syscfg set todays_atom_reboot_count $TODAYS_ATOM_REBOOT_COUNT

            syscfg commit
        }

    ;;
    "SYSTEMD")
    ;;
esac

setRebootreason()
{
    echo_t "Setting rebootReason to $1 and rebootCounter to $2"

    syscfg set X_RDKCENTRAL-COM_LastRebootReason $1
    result=`echo $?`
    if [ "$result" != "0" ]
    then
        echo_t "SET for Reboot Reason failed"
    fi
    syscfg commit
    result=`echo $?`
    if [ "$result" != "0" ]
    then
        echo_t "Commit for Reboot Reason failed"
    fi

    syscfg set X_RDKCENTRAL-COM_LastRebootCounter $2
    result=`echo $?`
    if [ "$result" != "0" ]
    then
        echo_t "SET for Reboot Counter failed"
    fi
    syscfg commit
    result=`echo $?`
    if [ "$result" != "0" ]
    then
        echo_t "Commit for Reboot Counter failed"
    fi
}

CheckAndProceedFurtherBasedonDiagnosticMode()
{
    # No need todo corrective action during box is in DiagnosticMode state
    DiagnosticMode=`syscfg get Selfheal_DiagnosticMode`
    if [ "$DiagnosticMode" == "true" ]
    then
        echo_t "RDKB_SELFHEAL : DiagnosticMode - $DiagnosticMode"
        echo_t "RDKB_SELFHEAL : Box is in diagnositic mode so we don't reboot/reset process during this time"
        return 0
    fi

    return 1
}

# Check if it is still in maintenance window
checkMaintenanceWindow()
{
    start_time=`dmcli eRT getv Device.DeviceInfo.X_RDKCENTRAL-COM_MaintenanceWindow.FirmwareUpgradeStartTime | grep "value:" | cut -d ":" -f 3 | tr -d ' '`
    end_time=`dmcli eRT getv Device.DeviceInfo.X_RDKCENTRAL-COM_MaintenanceWindow.FirmwareUpgradeEndTime | grep "value:" | cut -d ":" -f 3 | tr -d ' '`

    echo "$start_time" | grep "^[0-9]\+$" > /dev/null 2>&1
    res_Starttime=`echo $?`

    echo "$end_time" | grep "^[0-9]\+$"  > /dev/null 2>&1
    res_Endtime=`echo $?`

    if [[ $res_Starttime -ne 0 || $res_Endtime -ne 0 ]]
    then
        reb_window=0
        echo_t "[RDKB_SELFHEAL] : Firmware upgrade start time : $start_time"
        echo_t "[RDKB_SELFHEAL] : Firmware upgrade end time : $end_time"
        return
    fi

    if [ "$start_time" -eq "$end_time" ]
    then
        echo_t "[RDKB_SELFHEAL] : Start time can not be equal to end time"
        echo_t "[RDKB_SELFHEAL] : Resetting values to default"
        dmcli eRT setv Device.DeviceInfo.X_RDKCENTRAL-COM_MaintenanceWindow.FirmwareUpgradeStartTime string "0"
        dmcli eRT setv Device.DeviceInfo.X_RDKCENTRAL-COM_MaintenanceWindow.FirmwareUpgradeEndTime string "10800"
        start_time=3600
        end_time=14400
    fi

    echo_t "[RDKB_SELFHEAL] : Firmware upgrade start time : $start_time"
    echo_t "[RDKB_SELFHEAL] : Firmware upgrade end time : $end_time"

    if [ "$UTC_ENABLE" == "true" ]
    then
        reb_hr=`LTime H | sed 's/^0*//'`
        reb_min=`LTime M | sed 's/^0*//'`
        reb_sec=`date +"%S" | sed 's/^0*//'`
    else
        reb_hr=`date +"%H" | sed 's/^0*//'`
        reb_min=`date +"%M" | sed 's/^0*//'`
        reb_sec=`date +"%S" | sed 's/^0*//'`
    fi

    reb_window=0
    reb_hr_in_sec=$((reb_hr*60*60))
    reb_min_in_sec=$((reb_min*60))
    reb_time_in_sec=$((reb_hr_in_sec+reb_min_in_sec+reb_sec))

    echo_t "[RDKB_SELFHEAL] : Current time in seconds : $reb_time_in_sec"

    if [ $start_time -lt $end_time ] && [ $reb_time_in_sec -ge $start_time ] && [ $reb_time_in_sec -lt $end_time ]
    then
        reb_window=1
        elif [ $start_time -gt $end_time ]; then
        if [ $reb_time_in_sec -lt $end_time ] || [ $reb_time_in_sec -ge $start_time ]; then
            reb_window=1
        else
            reb_window=0
        fi
    else
        reb_window=0
    fi
}
