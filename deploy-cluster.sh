#!/bin/bash

# INSTALL: Basic Script to install DAP Master Server (dap1)

# Global Variables
masterContainer="conjur-appliance"
masterIP="10.10.10.13"
serverType="master"
masterDNS="dap1.myorg.local"
clusterDNS="dapmaster.myorg.local"
standby1DNS="dap2.myorg.local"
standby2DNS="dap3.myorg.local"
standbyContainer="conjur-appliance2"
standbyIP="10.10.10.14"
adminPass="MyCyber@rk01"
accountName="myorg"
version="11.4.0"		## Change to installation version
certDir="/home/ec2-user/certs"
archive="certBundle.tar"


# Create Docker Container
echo "Creating DAP Master Server Container"
echo "------------------------------------"
set -x
docker run --name $masterContainer \
  -d --restart=unless-stopped \
  --ip $masterIP \
  --network conjur-ipvlan \
  --security-opt seccomp:unconfined \
  -v /opt/conjur/backup/$masterContainer:/opt/conjur/backup/:Z \
  -p "443:443"
  -p "5432:5432"
  -p "1999:1999"
  registry.tld/conjur-appliance:$version
set +x

# EVOKE: Execute evoke command to configure DAP container as Master Server
docker exec $masterContainer evoke configure $serverType --accept-eula -h $masterDNS --master-altnames "$clusterDNS,$standby1DNS,$standby2DNS" -p $adminPass $accountName

# Change working directory
cd $certDir

# Create archive file for SSL certificates
tar -cf $archive cacert.cer dap-follower.key dap-follower.cer dap-master.key dap-master.cer

# Import SSL certificates to DAP Master Server
docker cp $archive $masterContainer:/tmp/
docker exec $masterContainer tar -xf /tmp/$archive
docker exec $masterContainer evoke ca import --force --root cacert.cer
docker exec $masterContainer evoke ca import --key dap-follower.key dap-follower.cer
docker exec $masterContainer evoke ca import --key dap-master.key --set dap-master.cer

# Create Seed Archive File
echo "Creating seed archive: $standbyDNS"
echo "------------------------------------"
set -x
docker exec -t $masterContainer bash -c "evoke seed $serverType $standbyDNS > /tmp/$serverType-$standbyContainer-seed.tar"
set +x

# Copy Seed Archive to Docker Host (docker-host1)
echo "Copy seed archive to Docker Host: docker-host1"
echo "------------------------------------"
set -x
docker cp $masterContainer:/tmp/$serverType-$standbyContainer-seed.tar .
set +x

# Create Container (DAP Standby Server)
echo "Creating Docker Container: $standbyContainer"
echo "------------------------------------"
set -x
docker run --name $standbyContainer \
  -d --restart=always \
  --network conjur-ipvlan \
  --ip $standbyIP \
  --security-opt seccomp:unconfined \
  -v /var/log/conjur/$standbyContainer:/var/log/conjur/:Z \
  --log-driver json-file \
  --log-opt max-size=1000m \
  --log-opt max-file=3 \
  registry.tld/conjur-appliance:$version
set +x

# Copy Seed Archive to Server Container
echo "Copy seed archive to container: $standbyContainer"
echo "------------------------------------"
set -x
docker cp $serverType-$standbyContainer-seed.tar $standbyContainer:/tmp
set +x

# Unpack the seed archive
echo "Unpack seed archive file"
echo "------------------------------------"
set -x
docker exec -it $standbyContainer bash -c "evoke unpack seed /tmp/$serverType-$standbyContainer-seed.tar"
set +x

# Install & Configure Server
echo "Install & Configure Server: $standbyDNS"
echo "------------------------------------"
set -x
docker exec -it $standbyContainer bash -c "evoke configure $serverType --master-address=$masterDNS"
set +x

#stopped before #5
