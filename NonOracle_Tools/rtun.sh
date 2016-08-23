#!/bin/bash

$REMOTEHOST=###USERNAME###
REMOTEHOST=###DNS###
KEYPATH=###PATH_TO_ID_FILE###

SSH_REMOTEPORT=22
SSH_LOCALPORT=5051

TUNNEL_REMOTEPORT=8080
TUNNEL_LOCALPORT=8080

createTunnel() {
   /usr/bin/ssh -q -i $KEYPATH -R $TUNNEL_REMOTEPORT:localhost:22 -f -N -L $TUNNEL_LOCALPORT:$REMOTEHOST:22 $REMOTEUSE@$REMOTEHOST
    if [[ $? -eq 0 ]]; then
        echo Tunnel to $REMOTEHOST created successfully
    else
        echo An error occurred creating a tunnel to $REMOTEHOST RC was $?
    fi
}

## Run the 'ls' command remotely.  If it returns non-zero, then create a new connection
/usr/bin/ssh -p $TUNNEL_LOCALPORT $REMOTEUSER@localhost ls >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
    echo Creating new tunnel connection
    createTunnel
fi
