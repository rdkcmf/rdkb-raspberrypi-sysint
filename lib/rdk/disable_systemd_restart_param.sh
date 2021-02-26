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

############################  This script is used to comment the restart parameter for all ccsp services files ##############################
############################  If any ccsp process is crashed, that process will restart via selfheal instead of systemd #####################
############################  Techsummit work ###############################################################################################

comment_restart_parameter ()
{
	sed -i "s/^Restart=always/#Restart=always/g" $1
}

cd /lib/systemd/system

comment_restart_parameter CcspCrSsp.service
comment_restart_parameter CcspEthAgent.service
comment_restart_parameter CcspLMLite.service
comment_restart_parameter CcspTr069PaSsp.service
comment_restart_parameter PsmSsp.service 
comment_restart_parameter ccspwifiagent.service
comment_restart_parameter parodus.service
comment_restart_parameter webpabroadband.service

cd -

systemctl daemon-reload
