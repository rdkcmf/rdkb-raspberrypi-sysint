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
echo "copying boot"

pass=$(cat /home/root/boot-info.txt | grep Credentials | cut -d ":" -f2) 


curl -X GET -H "Authorization: Basic ${pass}" -H "Content-Type: application/json" "https://wiki.rdkcentral.com/rest/api/content?spaceKey=RDK&title=RDK-B%20Boot%20time%20data%20plot" > ne.txt

cat ne.txt | cut -d':' -f3 | cut -d',' -f1 | cut -c2- | rev | cut -c2- | rev > nn.txt


export PAGE_ID=$(echo $(cat nn.txt))

export MONPAGE=$(date '+%B_%Y_RPI_BootTimeData')

curl -H "Authorization: Basic ${pass}" -X POST -H "Content-Type: application/json" -d'{"type":"page","title":"'""$MONPAGE""'","space":{"key":"RDK"},"ancestors":[{"id": "'""$PAGE_ID""'"}],"body":{"storage":{"value":"<p><ac:structured-macro ac:name=\"children\"/></p>","representation":"storage"}}}' https://wiki.rdkcentral.com/rest/api/content?spaceKey=RDK&title=RDK-B%20Boot%20time%20data%20plot

sleep 3


curl -X GET -H "Authorization: Basic ${pass}" -H "Content-Type: application/json" "https://wiki.rdkcentral.com/rest/api/content?spaceKey=RDK&title=$MONPAGE" > ne.txt

cat ne.txt | cut -d':' -f3 | cut -d',' -f1 | cut -c2- | rev | cut -c2- | rev > nn.txt

export MONPAGE_ID=$(echo $(cat nn.txt))


export DATEPAGE=$(date '+%F_RPI')

curl -H "Authorization: Basic ${pass}" -X POST -H "Content-Type: application/json" -d'{"type":"page","title":"'""$DATEPAGE""'","space":{"key":"RDK"},"ancestors":[{"id": "'"$MONPAGE_ID"'"}],"body":{"storage":{"value":"<p><ac:structured-macro ac:name=\"attachments\"/></p>","representation":"storage"}}}' https://wiki.rdkcentral.com/rest/api/content?spaceKey=RDK&title=$MONPAGE


sleep 2

systemd-analyze > total-time.txt

systemd-analyze blame > top-consumers.txt

mkdir -p /usr/share/fonts/

cp -rf /usr/www/cmn/fonts/* /usr/share/fonts/

cp /run/log/bootchart-*.svg boot-chart.svg

rsvg-convert boot-chart.svg > boot-data-plot.png


curl -X GET -H "Authorization: Basic ${pass}" -H "Content-Type: application/json" "https://wiki.rdkcentral.com/rest/api/content?spaceKey=RDK&title=$DATEPAGE" > ne.txt

sleep 5

cat ne.txt | cut -d':' -f3 | cut -d',' -f1 | cut -c2- | rev | cut -c2- | rev > nn.txt

export DATEPAGE_ID=$(echo $(cat nn.txt))


curl -H "Authorization: Basic ${pass}" -X POST -H "X-Atlassian-Token: no-check" -F "file=@total-time.txt" "https://wiki.rdkcentral.com/rest/api/content/$DATEPAGE_ID/child/attachment"

curl -H "Authorization: Basic ${pass}" -X POST -H "X-Atlassian-Token: no-check" -F "file=@top-consumers.txt" "https://wiki.rdkcentral.com/rest/api/content/$DATEPAGE_ID/child/attachment"

curl -H "Authorization: Basic ${pass}" -X POST -H "X-Atlassian-Token: no-check" -F "file=@boot-data-plot.png" "https://wiki.rdkcentral.com/rest/api/content/$DATEPAGE_ID/child/attachment"



