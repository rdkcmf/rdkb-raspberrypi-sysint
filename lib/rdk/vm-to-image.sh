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

mount /dev/mmcblk0p1 /mnt/
cp /mnt/vm-info.txt /home/root
umount /mnt


port=$(cat /home/root/vm-info.txt | grep Port | cut -d ":" -f2)
echo $port

if [ ${port} = "No" ]
then
    echo "set default port 22"
    port="22"
fi

machine=$(cat /home/root/vm-info.txt | grep Machine | cut -d ":" -f2)
echo $machine

ip=$(cat /home/root/vm-info.txt | grep ip | cut -d ":" -f2)
echo $ip

scp -P ${port} -i  ~/keyfile -o StrictHostKeyChecking=no -r ${machine}@${ip}:~/boot-info.txt /home/root/

source=$(cat /home/root/boot-info.txt | grep Sourcepath | cut -d ":" -f2)
echo $source

while true
do
       echo "Copy file size"
       scp -P ${port} -i  ~/keyfile -o StrictHostKeyChecking=no -r ${machine}@${ip}:${source}/filesize.txt /home/root/ 
       if [ -f /home/root/filesize.txt ]
       then
          actsize=$(cat /home/root/filesize.txt)
          echo $actsize
	  rm /home/root/filesize.txt
          break
       fi
       sleep 10
done

while true
do
       echo "Copy the file"
       if [ ! -f /home/root/*.rootfs.tar.bz2 ]
       then
       scp -P ${port} -i  ~/keyfile -o StrictHostKeyChecking=no -r ${machine}@${ip}:${source}/*.rootfs.tar.bz2 /home/root/ &
       fi
       size=$(stat /home/root/*.rootfs.tar.bz2 | grep "Size" | cut -d " " -f4)	
       echo $size
       if [ "${size}" = "${actsize}" ]
       then
           echo "Rootfs is ready to be loaded on to image"
           ssh  -p ${port} -i ~/keyfile -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${machine}@${ip} rm ${source}/*.bz2
           sh /lib/rdk/flash.sh
           exit
       else
           echo "File is not copied yet "
       fi
       sleep 10
done


