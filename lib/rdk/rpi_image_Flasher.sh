#!/bin/sh
##########################################################################
# If not stated otherwise in this file or this component's Licenses.txt
# file the following copyright and licenses apply:
#
# Copyright 2021 RDK Management
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
. /etc/include.properties

export PATH=$PATH:/usr/bin:/bin:/usr/local/bin:/sbin:/usr/local/lighttpd/sbin:/usr/local/sbin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib

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
        #reboot -f
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
        #reboot -f
    else
        echo "storage partition mmcblk0p4 is available"
    fi
fi

mkdir -p /extblock
mount /dev/mmcblk0p3 /extblock
fs_chk_cnt=`df -T /dev/mmcblk0p3 | grep -c "ext4"`

echo "file system type check count partition p3 is $fs_chk_cnt"

if [ "$fs_chk_cnt" = "0" ];
then
        echo "Creating ext4 file system for partition mmc0blkp3..."
        mkfs.ext4 -F /dev/mmcblk0p3
else
    echo "File system available for partition mmcblk0p3"
fi
umount /extblock

mount /dev/mmcblk0p4 /extblock
fs_chk_cnt=`df -T /dev/mmcblk0p4 | grep -c "ext4"`

echo "file system type check count partition p4 is $fs_chk_cnt"

if [ "$fs_chk_cnt" = "0" ];
then
        echo "Creating ext4 file system for partition mmc0blkp4..."
        mkfs.ext4 -F /dev/mmcblk0p4
else
    echo "File system available for partition mmcblk0p4"
fi

#-------------------------------------------------------------------------------------------------
# Create storage area directory in current rootfs and mount storage area
#--------------------------------------------------------------------------------------------------

bank1_partition_name=`fdisk /dev/mmcblk0 -l | tail -2 | cut -d' ' -f1 | head -n1`
extended_block_name=`fdisk /dev/mmcblk0 -l | tail -2 | cut -d' ' -f1 | tail -1`

mkdir -p /extblock
mount $extended_block_name /extblock

#--------------------------------------------------------------------------------------------------
# Create backup/extract directories inside storage area directory
#--------------------------------------------------------------------------------------------------

mkdir -p /extblock/bank0_rootfs
mkdir -p /extblock/bank1_rootfs

mkdir -p /extblock/bank0_linux
#mkdir -p /extblock/bank1_linux

mkdir -p /extblock/data_bkup_linux_bank0
mkdir -p /extblock/data_bkup_linux_bank1

#--------------------------------------------------------------------------------------------------
# Create directory and Download the image in storage area /extblock/image directory
#--------------------------------------------------------------------------------------------------

cd /firmware/imagedwld
for file in *; do
    echo "Downloaded image to be upgrade is $file"
done

if [ "$file" == "*" ]
then
echo "Image is not present for upgrade"
umount /extblock
exit 1
fi


#--------------------------------------------------------------------------------------------------
# Extract meta information of Downloaded image
#--------------------------------------------------------------------------------------------------

fdisk -u -l $file > /extblock/sector.txt

linux_sector=`tail -2 /extblock/sector.txt | tr -s ' ' | cut -d'*' -f2 | cut -d' ' -f2 | head -n1`
linux_offset=$((linux_sector*512))

rootfs_sector=`tail -2 /extblock/sector.txt | tr -s ' ' | cut -d'*' -f2 | cut -d' ' -f2 | tail -1`
rootfs_offset=$((rootfs_sector*512))

mkdir -p /extblock/linux_data
mkdir -p /extblock/rootfs_data

mkdir -p /extblock/linux_backup_data
mkdir -p /extblock/rootfs_backup_data

mount /dev/mmcblk0p1 /extblock/bank0_linux

#--------------------------------------------------------------------------------------------------
# Loop mount + Extract kernel and bootload data of Downloaded image to storage area
#--------------------------------------------------------------------------------------------------

mount -o loop,offset=$linux_offset $file /extblock/linux_data
cp -R /extblock/linux_data/* /extblock/linux_backup_data/
umount /extblock/linux_data
rm -rf /extblock/linux_data


#--------------------------------------------------------------------------------------------------
# Loop mount + Extract rootfs data of Downloaded image to storage area
#--------------------------------------------------------------------------------------------------

mount -o loop,offset=$rootfs_offset $file /extblock/rootfs_data

cp -R /extblock/rootfs_data/* /extblock/rootfs_backup_data
umount /extblock/rootfs_data
rm -rf /extblock/rootfs_data

#--------------------------------------------------------------------------------------------------
# Identify active bank ( either bank 0 or bank 1 ) or ( mmcblk0p2 or mmcblk0p3 )
#--------------------------------------------------------------------------------------------------

activeBank=`sed -e "s/.*root=//g" /proc/cmdline | cut -d ' ' -f1`
echo "Active bank partition is $activeBank"


#--------------------------------------------------------------------------------------------------
# Upgrade passive bank mmcblk0p2 and switch it as active bank
#--------------------------------------------------------------------------------------------------

if [ "$activeBank" = "$bank1_partition_name" ];
then

echo "Modifying Bank 0 partition mmcblk0p2 Content with downloaded image ..."

mount /dev/mmcblk0p2 /extblock/bank0_rootfs

passiveBank=/dev/mmcblk0p2;

rm -rf /extblock/data_bkup_linux_bank0/*
cp -R /extblock/linux_backup_data/* /extblock/data_bkup_linux_bank0/

#remove the existing linux data backup of bank0 from storage area

rm -rf /extblock/data_bkup_linux_bank1/*

#copy the new image linux data to storage area as bank0 linux back up

cp -R /extblock/bank0_linux/* /extblock/data_bkup_linux_bank1

rm -rf /extblock/bank0_linux/*

#Only one linux partition for both banks. So copy the latest linux image content to bank0 linux FAT partition
cp -R /extblock/linux_backup_data/* /extblock/bank0_linux

# change cmdline.txt for bank0 linux to partition p2 or mmcblk0p2 which has to be active bank after reboor
sed -i -e "s|${activeBank}|${passiveBank}|g" /extblock/bank0_linux/cmdline.txt

rm -rf /extblock/bank0_rootfs/*

#Copy the new image rootfs content to bank0 rootfs 
cp -R /extblock/rootfs_backup_data/* /extblock/bank0_rootfs

umount /extblock/bank0_rootfs

export ACTIVE_BANK=0

else

#--------------------------------------------------------------------------------------------------
# Upgrade passive bank mmcblk0p3 and switch it as active bank
#--------------------------------------------------------------------------------------------------

echo "Modifying Bank 1 partition mmcblk0p3 Content with downloaded image ..."

#remove the existing linux data backup of bank1 from storage area

rm -rf /extblock/data_bkup_linux_bank0/*

# if data_bkup_linux_bank1 is empty copy the /extblock/linux_backup_data/* content to /extblock/data_bkup_linux_bank0/*


#copy the new image linux data to storage area as bank1 linux back up
[ "$(ls -A /extblock/data_bkup_linux_bank0)" ] && export Notempty=0 || export Notempty=1

if [ "$Notempty" = "1" ];
then
    cp -R /extblock/bank0_linux/* /extblock/data_bkup_linux_bank0
fi

rm -rf /extblock/bank0_linux/*

rm -rf /extblock/data_bkup_linux_bank1/*

cp -R /extblock/linux_backup_data/* /extblock/data_bkup_linux_bank1/

mount $bank1_partition_name /extblock/bank1_rootfs

passiveBank=$bank1_partition_name;

#Only one linux partition for both banks. So copy the latest linux image content to bank0 linux FAT partition
cp -R /extblock/linux_backup_data/* /extblock/bank0_linux

# change cmdline.txt for bank0 linux to partition p3 or mmcblk0p3 which has to be active bank after reboot
sed -i -e "s|${activeBank}|${passiveBank}|g" /extblock/bank0_linux/cmdline.txt

rm -rf /extblock/bank1_rootfs/*

#Copy the new image rootfs content to bank1 rootfs
cp -R /extblock/rootfs_backup_data/* /extblock/bank1_rootfs/

umount /extblock/bank1_rootfs

export ACTIVE_BANK=1

fi

#--------------------------------------------------------------------------------------------------
# Remove temp folder used for copying present inside storage area and umount memory area
#--------------------------------------------------------------------------------------------------

umount /extblock/bank0_linux
rm -rf /extblock/rootfs*
rm -rf /extblock/linux*
rm -rf /extblock/bank*
rm -f /extblock/sec*
rm -rf /firmware/imagedwld/*

#--------------------------------------------------------------------------------------------------
# Reboot box for firmware upgrade to be active
#--------------------------------------------------------------------------------------------------

echo "Firmware upgrade successful"
echo "Rebooting with bank switch ...."

