#!/bin/bash

# CONFIGURE: Basic Script to configure DAP container as Master Server (dap1)

# Global Variables
masterContainer="conjur-appliance"
serverType="master"
masterDNS="dap1.myorg.local"
clusterDNS="dapmaster.myorg.local"
standby1DNS="dap2.myorg.local"
standby2DNS="dap3.myorg.local"
adminPass="MyCyber@rk01"
accountName="myorg"

# EVOKE: Execute evoke command to configure DAP container as Master Server
docker exec $masterContainer evoke configure $serverType --accept-eula -h $masterDNS --master-altnames "$clusterDNS,$standby1DNS,$standby2DNS" -p $adminPass $accountName
