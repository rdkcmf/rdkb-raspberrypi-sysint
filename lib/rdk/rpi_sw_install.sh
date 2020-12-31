#!bin/sh
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


##--------------------------------------------------------------------------------------------------
# Partition Creation for bank1 and storage area
#--------------------------------------------------------------------------------------------------

. /etc/device.properties
partition_check_name_block1=`fdisk /dev/mmcblk0 -l | tail -2 | tr -s ' ' | cut -d ' ' -f1 | tail -1`
partition_check_name_block2=`fdisk /dev/mmcblk0 -l | tail -2 | tr -s ' ' | cut -d ' ' -f1 | head -n 1`

echo "Checking available partition for bank switch and image upgrade... "

# To Create P3 and P4 partition if not available
if [ "$partition_check_name_block1" = "/dev/mmcblk0p2" ] || [ "$partition_check_name_block2" = "/dev/mmcblk0p2" ]
then
        echo "Creating additional partitions for Bank1 and storage area, box will go for reboot..."
        if [ "$partition_check_name_block1" = "/dev/mmcblk0p2" ]
        then
            bank1_partition=`fdisk /dev/mmcblk0 -l | tail -2 | tr -s ' ' | cut -d ' ' -f3 | tail -1`
        else
            bank1_partition=`fdisk /dev/mmcblk0 -l | tail -2 | tr -s ' ' | cut -d ' ' -f3 | head -n 1`
        fi
# Give Partition offset size in sector based. 
#    1 sector = 512
# for Ex : Allocating 1GB for partition 
#    2GB = ( 1024 * 1024 * 1024 ) * 2
#    sector size for 1GB = (1024*1024*1024)*2/512 = 4194304 sectors
#    Finally need to give partition size offset is 4194304 for 1GB partiton allocation.	
        bank_offset=1
        size_offset=$PART_SIZE_OFFSET
        bank1_start=$((bank1_partition+bank_offset))
        bank1_end=$((bank1_start+size_offset))
        echo "Creating Bank1 rootfs partition mmc0blkp3..."
        echo -e "\nn\np\n3\n$((bank1_start))\n$((bank1_end))\np\nw" | fdisk /dev/mmcblk0 
        storage_partition=`fdisk /dev/mmcblk0 -l | tail -2 | tr -s ' ' | cut -d ' ' -f3 | tail -1`
        storage_offset=1
        size_offset=$PART_SIZE_OFFSET
        storage_start=$((storage_partition+storage_offset))
        storage_end=$((storage_start+size_offset))
        echo "Creating Storage partition mmc0blkp4..."
        echo -e "\nn\np\n$((storage_start))\n$((storage_end))\np\nw" | fdisk /dev/mmcblk0 
	reboot -f
else

# To Create Storage partition p4  if rootfs partition p3 is available

    echo "Creating additional partition for storage area and box will go for reboot..."
    if [ "$partition_check_name_block1" = "/dev/mmcblk0p3" ]
    then
        storage_partition=`fdisk /dev/mmcblk0 -l | tail -2 | tr -s ' ' | cut -d ' ' -f3 | tail -1`
        storage_offset=1
        size_offset=$PART_SIZE_OFFSET
        storage_start=$((storage_partition+storage_offset))
        storage_end=$((storage_start+size_offset))
        echo "Creating Storage partition mmc0blkp4..."
        echo -e "\nn\np\n$((storage_start))\n$((storage_end))\np\nw" | fdisk /dev/mmcblk0 
        reboot -f
    else
        echo "storage partition mmcblk0p4 is available"
    fi
fi

