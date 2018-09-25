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

RUNAT="Wednesday:12:00"

source=$(cat ~/boot-info.txt | grep Sourcepath | cut -d ":" -f2)
echo $source

imagepath=$(cat ~/boot-info.txt | grep Imagepath | cut -d ":" -f2)
echo $imagepath

while [ 1 ]
do
    DATE=`/bin/date +%A:%H:%M`
    if [ $DATE. = $RUNAT. ]
    then
        rm -rf daily-build
        mkdir daily-build
        cd daily-build
        repo init -u https://code.rdkcentral.com/r/manifests -m rdkb-raspberrypi.xml -b morty
        repo sync -j4 --no-clone-bundle
        MACHINE=raspberrypi-rdk-boot-time-broadband source meta-cmf-raspberrypi/setup-environment
        cd build-raspberrypi-rdk-boot-time-broadband
        bitbake rdk-generic-broadband-boot-image -f
   fi


   if [ -f  ${imagepath}/*.rootfs.tar.bz2 ]
   then
        echo " Build is been initiated and completed "
        cp ${imagepath}/*.rootfs.tar.bz2 ${source}
        sleep 10
        stat ${source}/*.rootfs.tar.bz2 | grep "Size" | cut -d " " -f4 > ${source}/filesize.txt
        sleep 30
        rm ${imagepath}/*.rootfs.tar.bz2    
   fi
done

