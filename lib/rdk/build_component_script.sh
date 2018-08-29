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

execute_component() {
	
case $2 in
	"CcspCommonLibrary")
		git clone https://$1@code.rdkcentral.com/r/rdkb/components/opensource/ccsp/CcspCommonLibrary

		cd CcspCommonLibrary

		autoreconf -i

		./configure  --build=x86_64-linux  --host=arm-rdk-linux-gnueabi  --target=arm-rdk-linux-gnueabi --prefix=/build-raspberrypi-rdk-broadband/source/ccsp-commonlib/image/usr --exec_prefix=/build-raspberrypi-rdk-broadband/source/ccsp-commonlib/image/usr --bindir=/build-raspberrypi-rdk-broadband/source/ccsp-commonlib/image/usr/bin --sbindir=/build-raspberrypi-rdk-broadband/source/ccsp-commonlib/image/usr/sbin  --libexecdir=/build-raspberrypi-rdk-broadband/source/ccsp-commonlib/image/usr/lib/ccsp-common-library --datadir=/build-raspberrypi-rdk-broadband/source/ccsp-commonlib/image/usr/share --sysconfdir=/build-raspberrypi-rdk-broadband/source/ccsp-commonlib/image/etc --sharedstatedir=/build-raspberrypi-rdk-broadband/source/ccsp-commonlib/image/com --localstatedir=/build-raspberrypi-rdk-broadband/source/ccsp-commonlib/image/var --libdir=/build-raspberrypi-rdk-broadband/source/ccsp-commonlib/image/usr/lib --includedir=/build-raspberrypi-rdk-broadband/source/ccsp-commonlib/image/usr/include --oldincludedir=/build-raspberrypi-rdk-broadband/source/ccsp-commonlib/image/usr/include --infodir=/build-raspberrypi-rdk-broadband/source/ccsp-commonlib/image/usr/share/info --mandir=/build-raspberrypi-rdk-broadband/source/ccsp-commonlib/image/usr/share/man --disable-silent-rules --disable-dependency-tracking

		make CFLAGS="-I /usr/include/dbus-1.0 -I /usr/lib/dbus-1.0/include"

		make install
	;;

	"TestAndDiagnostic")
		git clone https://$1@code.rdkcentral.com/r/rdkb/components/opensource/ccsp/TestAndDiagnostic TestAndDiagnostic

		cd TestAndDiagnostic

		autoreconf -i

		./configure  --build=x86_64-linux   --host=arm-rdk-linux-gnueabi  --target=arm-rdk-linux-gnueabi   --prefix=/build-raspberrypi-rdk-broadband/source/TestAndDiagnostic/image/usr   --exec_prefix=/build-raspberrypi-rdk-broadband/source/TestAndDiagnostic/image/usr  --bindir=/build-raspberrypi-rdk-broadband/source/TestAndDiagnostic/image/usr/bin  --sbindir=/build-raspberrypi-rdk-broadband/source/TestAndDiagnostic/image/usr/sbin   --libexecdir=/build-raspberrypi-rdk-broadband/source/TestAndDiagnostic/image/usr/libexec  --datadir=/build-raspberrypi-rdk-broadband/source/TestAndDiagnostic/image/usr/share  --sysconfdir=/build-raspberrypi-rdk-broadband/source/TestAndDiagnostic/image/etc   --sharedstatedir=/build-raspberrypi-rdk-broadband/source/TestAndDiagnostic/image/com   --localstatedir=/build-raspberrypi-rdk-broadband/source/TestAndDiagnostic/image/var  --libdir=/build-raspberrypi-rdk-broadband/source/TestAndDiagnostic/image/usr/lib   --includedir=/build-raspberrypi-rdk-broadband/source/TestAndDiagnostic/image/usr/include    --oldincludedir=/build-raspberrypi-rdk-broadband/source/TestAndDiagnostic/image/usr/include    --infodir=/build-raspberrypi-rdk-broadband/source/TestAndDiagnostic/image/usr/share/info   --mandir=/build-raspberrypi-rdk-broadband/source/TestAndDiagnostic/image/usr/share/man  --disable-silent-rules  --disable-dependency-tracking


		make  CFLAGS=" -Os -pipe -g -feliminate-unused-debug-types -DFEATURE_SUPPORT_RDKLOG  -D_COSA_HAL_       -I/usr/include     -I/usr/include/dbus-1.0     -I/usr/lib/dbus-1.0/include     -I/usr/include/ccsp     -I/usr/include/utapi     -I/usr/include/utctx     -I/usr/include/ulog     -I/usr/include/syscfg      -U_COSA_SIM_ -fno-exceptions -ffunction-sections -fdata-sections -fomit-frame-pointer -fno-strict-aliasing            -D_ANSC_LINUX -D_ANSC_USER -D_ANSC_LITTLE_ENDIAN_ -D_CCSP_CWMP_TCP_CONNREQ_HANDLER            -D_DSLH_STUN_ -D_NO_PKI_KB5_SUPPORT -D_BBHM_SSE_FILE_IO -D_ANSC_USE_OPENSSL_ -DENABLE_SA_KEY            -D_ANSC_AES_USED_ -D_COSA_INTEL_USG_ARM_ -D_COSA_FOR_COMCAST_ -D_NO_EXECINFO_H_ -DFEATURE_SUPPORT_SYSLOG            -DBUILD_WEB -D_NO_ANSC_ZLIB_ -D_DEBUG -U_ANSC_IPV6_COMPATIBLE_ -D_COSA_BCM_ARM_ -DUSE_NOTIFY_COMPONENT            -D_PLATFORM_RASPBERRYPI_ -DENABLE_SD_NOTIFY -DCOSA_DML_WIFI_FEATURE_LoadPsmDefaults -UPARODUS_ENABLE        -UCONFIG_VENDOR_CUSTOMER_COMCAST"  LDFLAGS="-Wl,-O1 -Wl,--hash-style=gnu -Wl,--as-needed -lrdkloggers     -ldbus-1     "

		make install
	;;

	"webui")
		git clone https://$1@code.rdkcentral.com/r/rdkb/components/opensource/ccsp/webui webui

		cd webui/source/CcspPhpExtension

		phpize

		./configure  --build=x86_64-linux  --host=arm-rdk-linux-gnueabi   --target=arm-rdk-linux-gnueabi  --prefix=/build-raspberrypi-rdk-broadband/source/ccsp-webui/image/usr   --exec_prefix=/build-raspberrypi-rdk-broadband/source/ccsp-webui/image/usr   --bindir=/build-raspberrypi-rdk-broadband/source/ccsp-webui/image/usr/bin   --sbindir=/build-raspberrypi-rdk-broadband/source/ccsp-webui/image/usr/sbin  --libexecdir=/build-raspberrypi-rdk-broadband/source/ccsp-webui/image/usr/libexec  --datadir=/build-raspberrypi-rdk-broadband/source/ccsp-webui/image/usr/share  --sysconfdir=/build-raspberrypi-rdk-broadband/source/ccsp-webui/image/etc  --sharedstatedir=/build-raspberrypi-rdk-broadband/source/ccsp-webui/image/com  --localstatedir=/build-raspberrypi-rdk-broadband/source/ccsp-webui/image/var   --libdir=/build-raspberrypi-rdk-broadband/source/ccsp-webui/image/usr/lib  --includedir=/build-raspberrypi-rdk-broadband/source/ccsp-webui/image/usr/include   --oldincludedir=/build-raspberrypi-rdk-broadband/source/ccsp-webui/image/usr/include   --infodir=/build-raspberrypi-rdk-broadband/source/ccsp-webui/image/usr/share/info   --mandir=/build-raspberrypi-rdk-broadband/source/ccsp-webui/image/usr/share/man   --disable-silent-rules  --disable-dependency-tracking   --with-libtool-sysroot=/ --enable-cosa CCSP_COMMON_LIB=/usr/lib PHP_RPATH=no  --with-ccsp-platform=bcm --with-ccsp-arch=arm


 		make  CFLAGS=" -Os -pipe -g -feliminate-unused-debug-types -DFEATURE_SUPPORT_RDKLOG  -D_COSA_HAL_       -I/usr/include     -I/usr/include/dbus-1.0     -I/usr/lib/dbus-1.0/include     -I/usr/include/ccsp     -I/usr/include/utapi     -I/usr/include/utctx     -I/usr/include/ulog     -I/usr/include/syscfg      -U_COSA_SIM_ -fno-exceptions -ffunction-sections -fdata-sections -fomit-frame-pointer -fno-strict-aliasing            -D_ANSC_LINUX -D_ANSC_USER -D_ANSC_LITTLE_ENDIAN_ -D_CCSP_CWMP_TCP_CONNREQ_HANDLER            -D_DSLH_STUN_ -D_NO_PKI_KB5_SUPPORT -D_BBHM_SSE_FILE_IO -D_ANSC_USE_OPENSSL_ -DENABLE_SA_KEY            -D_ANSC_AES_USED_ -D_COSA_INTEL_USG_ARM_ -D_COSA_FOR_COMCAST_ -D_NO_EXECINFO_H_ -DFEATURE_SUPPORT_SYSLOG            -DBUILD_WEB -D_NO_ANSC_ZLIB_ -D_DEBUG -U_ANSC_IPV6_COMPATIBLE_ -D_COSA_BCM_ARM_ -DUSE_NOTIFY_COMPONENT            -D_PLATFORM_RASPBERRYPI_ -DENABLE_SD_NOTIFY -DCOSA_DML_WIFI_FEATURE_LoadPsmDefaults -UPARODUS_ENABLE        -UCONFIG_VENDOR_CUSTOMER_COMCAST"  LDFLAGS="-Wl,-O1 -Wl,--hash-style=gnu -Wl,--as-needed -lrdkloggers     -ldbus-1     "


		make install
	;;

	"hal")
		git clone https://$1@code.rdkcentral.com/r/rdkb/components/opensource/ccsp/hal hal


		cd hal/


		autoreconf -i


		./configure  --build=x86_64-linux   --host=arm-rdk-linux-gnueabi   --target=arm-rdk-linux-gnueabi   --prefix=/build-raspberrypi-rdk-broadband/source/hal/image/usr   --exec_prefix=/build-raspberrypi-rdk-broadband/source/hal/image/usr   --bindir=/build-raspberrypi-rdk-broadband/source/hal/image/usr/bin   --sbindir=/build-raspberrypi-rdk-broadband/source/hal/image/usr/sbin   --libexecdir=/build-raspberrypi-rdk-broadband/source/hal/image/usr/libexec   --datadir=/build-raspberrypi-rdk-broadband/source/hal/image/usr/share   --sysconfdir=/build-raspberrypi-rdk-broadband/source/hal/image/etc    --sharedstatedir=/build-raspberrypi-rdk-broadband/source/hal/image/com    --localstatedir=/build-raspberrypi-rdk-broadband/source/hal/image/var   --libdir=/build-raspberrypi-rdk-broadband/source/hal/image/usr/lib   --includedir=/build-raspberrypi-rdk-broadband/source/hal/image/usr/include   --oldincludedir=/build-raspberrypi-rdk-broadband/source/hal/image/usr/include   --infodir=/build-raspberrypi-rdk-broadband/source/hal/image/usr/share/info    --mandir=/build-raspberrypi-rdk-broadband/source/hal/image/usr/share/man   --disable-silent-rules  --disable-dependency-tracking  --with-libtool-sysroot=/

		make  CFLAGS=" -Os -pipe -g -feliminate-unused-debug-types -I=/usr/include/ccsp "  LDFLAGS="-Wl,-O1 -Wl,--hash-style=gnu -Wl,--as-needed"

		make install
	;;

	"ccsp-psm")
		git clone https://$1@code.rdkcentral.com/r/rdkb/components/opensource/ccsp/CcspPsm ccsp-psm

		cd ccsp-psm

		autoreconf -i

		./configure  --build=x86_64-linux   --host=arm-rdk-linux-gnueabi  --target=arm-rdk-linux-gnueabi  --prefix=/build-raspberrypi-rdk-broadband/source/ccsp-psm/image/usr   --exec_prefix=/build-raspberrypi-rdk-broadband/source/ccsp-psm/image/usr   --bindir=/build-raspberrypi-rdk-broadband/source/ccsp-psm/image/usr/bin  --sbindir=/build-raspberrypi-rdk-broadband/source/ccsp-psm/image/usr/sbin  --libexecdir=/build-raspberrypi-rdk-broadband/source/ccsp-psm/image/usr/libexec  --datadir=/build-raspberrypi-rdk-broadband/source/ccsp-psm/image/usr/share   --sysconfdir=/build-raspberrypi-rdk-broadband/source/ccsp-psm/image/etc  --sharedstatedir=/build-raspberrypi-rdk-broadband/source/ccsp-psm/image/com  --localstatedir=/build-raspberrypi-rdk-broadband/source/ccsp-psm/image/var   --libdir=/build-raspberrypi-rdk-broadband/source/ccsp-psm/image/usr/lib  --includedir=/build-raspberrypi-rdk-broadband/source/ccsp-psm/image/usr/include   --oldincludedir=/build-raspberrypi-rdk-broadband/source/ccsp-psm/image/usr/include   --infodir=/build-raspberrypi-rdk-broadband/source/ccsp-psm/image/usr/share/info   --mandir=/build-raspberrypi-rdk-broadband/source/ccsp-psm/image/usr/share/man    --disable-silent-rules   --disable-dependency-tracking   --with-libtool-sysroot=/   --enable-notify --with-ccsp-platform=bcm --with-ccsp-arch=arm

		cp -rf source-arm/psm_hal_apis.c source/Ssp/

		make CFLAGS=" -Os -pipe -g -feliminate-unused-debug-types  -DFEATURE_SUPPORT_RDKLOG  -D_COSA_HAL_       -I=/usr/include/dbus-1.0     -I=/usr/lib/dbus-1.0/include     -I=/usr/include/ccsp    -I=/usr/include  -U_COSA_SIM_ -fno-exceptions -ffunction-sections -fdata-sections -fomit-frame-pointer -fno-strict-aliasing            -D_ANSC_LINUX -D_ANSC_USER -D_ANSC_LITTLE_ENDIAN_ -D_CCSP_CWMP_TCP_CONNREQ_HANDLER            -D_DSLH_STUN_ -D_NO_PKI_KB5_SUPPORT -D_BBHM_SSE_FILE_IO -D_ANSC_USE_OPENSSL_ -DENABLE_SA_KEY            -D_ANSC_AES_USED_ -D_COSA_INTEL_USG_ARM_ -D_COSA_FOR_COMCAST_ -D_NO_EXECINFO_H_ -DFEATURE_SUPPORT_SYSLOG            -DBUILD_WEB -D_NO_ANSC_ZLIB_ -D_DEBUG -U_ANSC_IPV6_COMPATIBLE_ -D_COSA_BCM_ARM_ -DUSE_NOTIFY_COMPONENT            -D_PLATFORM_RASPBERRYPI_ -DENABLE_SD_NOTIFY -DCOSA_DML_WIFI_FEATURE_LoadPsmDefaults -UPARODUS_ENABLE          -UCONFIG_VENDOR_CUSTOMER_COMCAST"  LDFLAGS=" -Wl,-O1 -Wl,--hash-style=gnu -Wl,--no-as-needed  -lrdkloggers -lbreakpadwrapper     -ldbus-1  -ldl -lccsp_common -lbreakpadwrapper"

		make install
	;;

	"ccsp-p-and-m")
		git clone https://$1@code.rdkcentral.com/r/rdkb/components/opensource/ccsp/CcspPandM ccsp-p-and-m

		cd ccsp-p-and-m

		 autoreconf -i

		./configure  --build=x86_64-linux   --host=arm-rdk-linux-gnueabi  --target=arm-rdk-linux-gnueabi  --prefix=/build-raspberrypi-rdk-broadband/source/ccsp-p-and-m/image/usr   --exec_prefix=/build-raspberrypi-rdk-broadband/source/ccsp-p-and-m/image/usr  --bindir=/build-raspberrypi-rdk-broadband/source/ccsp-p-and-m/image/usr/bin   --sbindir=/build-raspberrypi-rdk-broadband/source/ccsp-p-and-m/image/usr/sbin    --libexecdir=/build-raspberrypi-rdk-broadband/source/ccsp-p-and-m/image/usr/libexec   --datadir=/build-raspberrypi-rdk-broadband/source/ccsp-p-and-m/image/usr/share   --sysconfdir=/build-raspberrypi-rdk-broadband/source/ccsp-p-and-m/image/etc   --sharedstatedir=/build-raspberrypi-rdk-broadband/source/ccsp-p-and-m/image/com    --localstatedir=/build-raspberrypi-rdk-broadband/source/ccsp-p-and-m/image/var    --libdir=/build-raspberrypi-rdk-broadband/source/ccsp-p-and-m/image/usr/lib    --includedir=/build-raspberrypi-rdk-broadband/source/ccsp-p-and-m/image/usr/include    --oldincludedir=/build-raspberrypi-rdk-broadband/source/ccsp-p-and-m/image/usr/include   --infodir=/build-raspberrypi-rdk-broadband/source/ccsp-p-and-m/image/usr/share/info   --mandir=/build-raspberrypi-rdk-broadband/source/ccsp-p-and-m/image/usr/share/man  --disable-silent-rules  --disable-dependency-tracking    --with-libtool-sysroot=/   --enable-notify --with-ccsp-platform=bcm --with-ccsp-arch=arm

		 make CFLAGS=" -Os -pipe -g -feliminate-unused-debug-types  -DFEATURE_SUPPORT_RDKLOG  -D_COSA_HAL_   -I/usr/include     -I/usr/include/dbus-1.0     -I/usr/lib/dbus-1.0/include     -I/usr/include/ccsp     -I/usr/include/utapi     -I/usr/include/utctx  -I/usr/include/ulog   -I/usr/include/syscfg  -DCONFIG_VENDOR_CUSTOMER_COMCAST -DCONFIG_INTERNET2P0 -DCONFIG_CISCO_HOTSPOT   -DPARODUS_ENABLE -I/usr/include/wrp-c    -I/usr/include/cimplog  -I/usr/include/nanomsg    -I/usr/include/trower-base64    -I/usr/include/msgpackc  -I/usr/include/libparodus    -I/usr/include/cjson -U_COSA_SIM_ -fno-exceptions -ffunction-sections -fdata-sections -fomit-frame-pointer -fno-strict-aliasing   -D_ANSC_LINUX -D_ANSC_USER -D_ANSC_LITTLE_ENDIAN_ -D_CCSP_CWMP_TCP_CONNREQ_HANDLER    -D_DSLH_STUN_ -D_NO_PKI_KB5_SUPPORT -D_BBHM_SSE_FILE_IO -D_ANSC_USE_OPENSSL_ -DENABLE_SA_KEY            -D_ANSC_AES_USED_ -D_COSA_INTEL_USG_ARM_ -D_COSA_FOR_COMCAST_ -D_NO_EXECINFO_H_ -DFEATURE_SUPPORT_SYSLOG            -DBUILD_WEB -D_NO_ANSC_ZLIB_ -D_DEBUG -U_ANSC_IPV6_COMPATIBLE_ -D_COSA_BCM_ARM_ -DUSE_NOTIFY_COMPONENT            -D_PLATFORM_RASPBERRYPI_ -DENABLE_SD_NOTIFY -DCOSA_DML_WIFI_FEATURE_LoadPsmDefaults -UPARODUS_ENABLE            -UCONFIG_VENDOR_CUSTOMER_COMCAST     -I=/usr/include/utctx     -I=/usr/include/utapi "  LDFLAGS="-Wl,-O1 -Wl,--hash-style=gnu -Wl,--as-needed -lrdkloggers -llibparodus -lnanomsg -lwrp-c -lmsgpackc -ltrower-base64 -lm -lcimplog -lcjson -lpthread -lrt -lsysevent -ldbus-1 -lutctx -lutapi -lm -lcjson"

		make install
	;;
esac 	
}
echo "====================================================="
echo "********* List of ccsp-components are ***************"
echo "             1.CcspCommonLibrary                     "
echo "             2.TestAndDiagnostic                     "
echo "             3.webui                                 "
echo "             4.ccsp-p-and-m                          "               
echo "             5.ccsp-psm                              " 
echo "             6.hal                                   "
echo "====================================================="

echo "====================================================="
echo " usage:sh bulid_ccsp_devscript.sh UserName CCSP_Component_Name"
echo "====================================================="


workspace_location="/build-raspberrypi-rdk-broadband/source/"
mkdir -p $workspace_location
cd $workspace_location

execute_component $1 $2


