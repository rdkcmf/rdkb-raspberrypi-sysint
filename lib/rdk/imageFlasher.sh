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

. /etc/device.properties

export PATH=$PATH:/usr/bin:/bin:/usr/local/bin:/sbin:/usr/local/lighttpd/sbin:/usr/local/sbin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/Qt/lib:/usr/local/lib


# input arguments
PROTO=$1
CLOUD_LOCATION=$2
DOWNLOAD_LOCATION=$3
UPGRADE_FILE=$4
REBOOT_FLAG=$5
PDRI_UPGRADE=$6


if [ ! $PROTO ];then echo "Missing the upgrade proto..!"; exit -2;fi
if [ ! $CLOUD_LOCATION ];then echo "Missing the cloud image location..!"; exit -2;fi
#if [ ! $DOWNLOAD_LOCATION ];then echo "Missing the local download image location..!"; exit -2;fi
if [ ! $UPGRADE_FILE ];then echo "Missing the image file..!"; exit -2;fi

# Call RPI flashing utility
if [ -f /lib/rdk/rpi_sw_install.sh ]; then 
    echo "CKP !!!!!!!!! calling rpi_sw_install"
   sh /lib/rdk/rpi_sw_install.sh
   sh /lib/rdk/rpi_sw_install1.sh $PROTO $CLOUD_LOCATION $DOWNLOAD_LOCATION
    exit $?
else
   echo "Error !!! Flashing utility /bin/rpi_sw_install not present !!!!"
   exit 1
fi
