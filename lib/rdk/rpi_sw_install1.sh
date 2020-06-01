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

. /etc/include.properties
. /etc/device.properties

OUTPUT="$PERSISTENT_PATH/output.txt"                                  
cloudProto=$1
cloudFWLocation=$2
cloudFWFile=$3

                                        
tftpDownload () {      

 mkdir -p /extblock/tftpimage
 cd /extblock/tftpimage                                     
 echo "set IPtable rules for tftp !!"   
 iptables -t raw -I OUTPUT -j CT -p udp -m udp --dport 69 --helper tftp
 echo "cloudfile is:"$cloudFWFile                                 
 echo "cloudlocation is:"$cloudFWLocation                                

 echo "Downloading already deployed checksum file from server $cloudFWFile"
 mkdir -p checksum
 cd checksum                                         
 check_sum=$(echo "$cloudFWFile" | cut -f 1 -d '.')
 check_sum_file="${check_sum}.txt"
 echo "tftp download checksum file"                          
 echo "checksum file to download is $check_sum_file"
 tftp -g  -r $check_sum_file $cloudFWLocation
 sleep 10
 if [ ! -f $check_sum_file ]; then
    echo "Sorry cloud checksum not downloaded from TFTP!!"
    ret=1
 fi

 cd ..
 mkdir -p imagedwnld
 cd imagedwnld
 echo "Downloading $cloudFWFile ..."

 tftp -g  -r $cloudFWFile $cloudFWLocation
 #ret=$?
 sleep 10
 if [ "$(ls -A $pwd)" ]; then
    echo "$pwd is not empty,image downloaded from tftp,lets check the md5sum file from cloud !!"
    echo "Doing additional check..."
    echo "comparing checksum files..."
    cloudcsfile_path="/extblock/tftpimage/checksum/$check_sum_file"
    echo "checksum file to download with actual path is $cloudcsfile_path"
    cloudcs=`cat $cloudcsfile_path | cut -f 1 -d ' '`
    echo "cloudcs:cloud download md5sum file version is:$cloudcs"
    devcs=`md5sum /extblock/tftpimage/imagedwnld/rdk* | cut -f 1 -d " "`
    echo "devcs:image download checksum md5sum file version is:$devcs"
    if [ "$devcs" = "$cloudcs" ]; then
      echo "md5sum matches !!"
      ret=0
   else
      echo "tftp file not downloaded properly"
      ret=1
   fi
   cd ..
 else
    echo "image itself not downloaded from TFTP,pls check tftp connection!!"
    cd ..
    ret=1
 fi
 echo "checksum verification done...coming back and deleting checksum folder"
 cd ..
 rm -rf checksum                                                                 
 return $ret
                                                                    
}  

httpDownload () {
    echo "Inside httpdownlaod !!"
    echo  "`Timestamp` Image download with http prtocol"
    mkdir -p /extblock/httpimage
    cd /extblock/httpimage
    echo "cloudfile is:"$cloudFWFile                                 
    echo "cloudlocation is:"$cloudFWLocation                                

    echo "Downloading already deployed checksum file from server $cloudFWFile"
    mkdir -p checksum
    cd checksum
    check_sum=$(echo "$cloudFWFile" | cut -f 1 -d '.')
    check_sum_file="${check_sum}.txt"

    echo "HTTP CURL URL is curl -w %{http_code} '$cloudFWLocation/$check_sum_file' -o '$check_sum_file'"
    eval curl -w %{http_code} '$cloudFWLocation/$check_sum_file' -o '$check_sum_file'
    sleep 10
    if [ ! -f $check_sum_file ]; then
        echo "Sorry cloud checksum not downloaded from HTTP!!"
        ret=1
    fi

    cd ..
    mkdir -p imagedwnld
    cd imagedwnld
    echo "Downloading $cloudFWFile ..."

    echo "HTTP CURL URL is curl -w %{http_code} '$cloudFWLocation/$cloudFWFile' -o '$cloudFWFile'"
    eval curl -w %{http_code} '$cloudFWLocation/$cloudFWFile' -o '$cloudFWFile'
    sleep 10
    if [ "$(ls -A $pwd)" ]; then
          echo "$pwd is not empty,image downloaded from http,lets check the md5sum file from cloud !!"
          echo "Doing additional check..."
          echo "comparing checksum files..."
          cloudcsfile_path="/extblock/httpimage/checksum/$check_sum_file"
          echo "checksum file to download with actual path is $cloudcsfile_path"
          cloudcs=`cat $cloudcsfile_path | cut -f 1 -d ' '`
          echo "cloudcs:cloud download md5sum file version is:$cloudcs"
          devcs=`md5sum /extblock/httpimage/imagedwnld/rdk* | cut -f 1 -d " "`
          echo "devcs:image download checksum md5sum file version is:$devcs"
          if [ "$devcs" = "$cloudcs" ]; then
             echo "md5sum matches !!"
             ret=0
          else
             echo "http file not downloaded properly"
             ret=1
          fi
          cd ..
    else
          echo "image itself not downloaded from HTTP,pls check HTTP connection!!"
          cd ..
          ret=1
    fi
    echo "checksum verification done...coming back and deleting checksum folder"
    cd ..
    rm -rf checksum
    return $ret
    
}

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
echo "cloud proto is :"$cloudProto
if [ $cloudProto -eq 2 ] ; then                                      
        protocol=2                                                
else                                                                      
        protocol=1                                       
fi     
if [ $protocol -eq 1 ]; then
  tftpDownload
  ret=$?
elif [ $protocol -eq 2 ]; then
  httpDownload
  ret=$?
else
  echo "Invalid Protocol"
fi
if [ $ret -ne 0 ]; then      
	if [ $protocol -eq 1 ]; then
	     echo "tftp download failed & exiting !!"                                                   
	elif [ $protocol -eq 2 ]; then
	     echo "http download failed & exiting !!"
	fi                                                   
        exit 1
elif [ -f "$cloudFWFile" ]; then                                                                                                          
	if [ $protocol -eq 1 ]; then
        	echo "$cloudFWFile Local Image Download Completed using TFTP protocol!"                                                   
	elif [ $protocol -eq 2 ]; then
        	echo "$cloudFWFile Local Image Download Completed using HTTP protocol!"
	fi                                                   
        filesize=`ls -l $cloudFWFile |  awk '{ print $5}'`                                                                                    
        echo "Downloaded $cloudFWFile of size $filesize"                                                                          
    fi                                                     
#umount /extblock
	

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

#mkdir /tmp/dirname
#tftp/scp the image to /extblock/image folder

if [ $protocol -eq 1 ]; then
	cd /extblock/tftpimage
elif [ $protocol -eq 2 ]; then
	cd /extblock/httpimage
fi
rm -rf checksum

cd imagedwnld 
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
if [ $protocol -eq 1 ]; then
	rm -rf /extblock/tftpimage/*
elif [ $protocol -eq 2 ]; then
	rm -rf /extblock/httpimage/*
fi
#umount /extblock


#--------------------------------------------------------------------------------------------------
# Reboot box for firmware upgrade to be active
#--------------------------------------------------------------------------------------------------

echo "Firmware upgrade successful"
echo "Rebooting with bank switch ...."

reboot -f
