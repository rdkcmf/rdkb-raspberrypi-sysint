#!/bin/sh

#### To generate the server.pem by using openssl
#### For support HTTPS port in Remote Management

if [ ! -f /etc/server.pem ]; then
openssl req -newkey rsa:2048 -new -nodes -x509 -days 3650 -subj /C=IN/ST=TN/L=Bangalore/O=Example_Org/CN=*.example.org -keyout /etc/key.pem -out /etc/cert.pem	
cat /etc/key.pem > /etc/server.pem
cat /etc/cert.pem >> /etc/server.pem
rm /etc/key.pem /etc/cert.pem
fi
