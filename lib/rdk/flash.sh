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

if [ ! -b  /dev/mmcblk0p3 ]
then
        echo -e "\nn\np\n3\n"+1024M"\n"+1024M"\np\nw" | fdisk /dev/mmcblk0
        reboot -f
fi

mount /dev/mmcblk0p1 /mnt
CURR=$(awk '"root="{print $3}' /mnt/cmdline.txt | cut -d  "/" -f 3)
echo "$CURR"
umount /mnt

if [ $CURR == "mmcblk0p2" ]
then 
   PART=mmcblk0p3
   echo "$PART"
else
   PART=mmcblk0p2
   echo "$PART"
fi

umount /dev/$PART
mkfs.ext2 -F /dev/$PART

mount /dev/$PART /mnt
tar -xvf /home/root/*.bz2 -C /mnt
umount /mnt
rm /home/root/*.bz2

mount /dev/mmcblk0p1 /mnt
sed -i -e "s/"$CURR"/"$PART"/1" /mnt/cmdline.txt
cp /mnt/keyfile /home/root/
touch /mnt/changed
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

source=$(cat /home/root/boot-info.txt | grep Sourcepath | cut -d ":" -f2)
echo $source

ssh -p ${port} -i ~/keyfile -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${machine}@${ip} rm ${source}/filesize.txt

reboot 


