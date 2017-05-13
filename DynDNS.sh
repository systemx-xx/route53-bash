#!/bin/bash
# AWS Route53 DNS Updater

if [ -z "$AWS_ACCESS_KEY_ID" ];
then
  echo "You must set AWS_ACCESS_KEY_ID prior to running this script"
  exit 0
fi
AWSKeyID="$AWS_ACCESS_KEY_ID"

if [ -z "$AWS_SECRET_ACCESS_KEY" ];
then
  echo "You must set AWS_SECRET_ACCESS_KEY prior to running this script"
  exit 0
fi
AWSAccessKey="$AWS_SECRET_ACCESS_KEY"

if [ -z $1 ];
then
  echo "You must provide a HostedZoneID"
  echo "./DynDns.sh HostedZoneID Fqdn"
  exit 0
fi
HostedZoneId=$1

if [ -z $2 ];
then
  echo "You must provide a Fqdn to update"
  echo "./DynDns.sh HostedZoneID Fqdn"
  exit 0
fi
Fqdn=$2

TTL=300

WanIP=`curl -s icanhazip.com`

DateVar=`date "+%a, %d %b %Y %T" --utc`" GMT"
Signature=`echo -en "$DateVar" | openssl dgst -sha256 -hmac "$AWSAccessKey" -binary | openssl enc -base64`
Header="Date: $DateVar\nX-Amzn-Authorization: AWS3-HTTPS AWSAccessKeyId=$AWSKeyID,Algorithm=HmacSHA256,Signature=$Signature"
Header=`echo -en $Header`

CurrentIP=`curl -k -H "$Header" -d "name=$Fqdn" -G "https://route53.amazonaws.com/2013-04-01/hostedzone/$HostedZoneId/rrset?maxitems=1" 2>/dev/null | awk -v FS="(<Value>|<\/Value>)" '{print $2}' 2>/dev/null | sed '/^$/d'`

if [ "$3" == "force" ];
then
  CurrentIP=0
fi

if [ "$WanIP" != "$CurrentIP" ];
then

  Data=$(cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<ChangeResourceRecordSetsRequest xmlns="https://route53.amazonaws.com/doc/2013-04-01/">
<ChangeBatch>
   <Comment>Route53 DynDNS Script</Comment>
   <Changes>
      <Change>
         <Action>UPSERT</Action>
         <ResourceRecordSet>
            <Name>$Fqdn.</Name>
            <Type>A</Type>
            <TTL>$TTL</TTL>
            <ResourceRecords>
               <ResourceRecord>
                  <Value>$WanIP</Value>
               </ResourceRecord>
            </ResourceRecords>
         </ResourceRecordSet>
      </Change>
   </Changes>
</ChangeBatch>
</ChangeResourceRecordSetsRequest>
EOF
)
  Header="Content-Type: 'text/xml'\nDate: $DateVar\nX-Amzn-Authorization: AWS3-HTTPS AWSAccessKeyId=$AWSKeyID,Algorithm=HmacSHA256,Signature=$Signature"
  Header=`echo -en $Header`
  Result=`curl -k -H "$Header" -d "$Data" https://route53.amazonaws.com/2013-04-01/hostedzone/$HostedZoneId/rrset 2>/dev/null | awk -v FS="(<Status>|<\/Status>)" '{print $2}' 2>/dev/null | sed '/^$/d'`

  if [ "$Result" == "PENDING" ];
  then
    echo "$Fqdn has been queued for update"
  else
    echo "/!\ Update has Failed on $Fqdn"
  fi
else
  echo "No Update Required for $Fqdn"
fi
