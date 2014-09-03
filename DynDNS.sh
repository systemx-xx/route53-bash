#/bin/sh

# AWS Route53 DNS Updater
# Usage: Replace the credentials below and then execute ./DynDns.sh HostedZoneID FQDN
# Aws Route53 Key Credentials
AWSKeyID=""
AWSAccessKey=""

################################################################################################################################

TTL=300

if [ "$1" == '' ]
	then
	echo "You must provide a HostedZoneID"
	exit 0
fi

if [ "$2" == '' ]
	then
	echo "You must provide a FQDN to update"
	exit 0
fi

WanIP=`curl -s icanhazip.com`

DateVar=`date "+%a, %d %b %Y %T" --utc`" GMT"
Signature=`echo -en "$DateVar" | openssl dgst -sha256 -hmac "$AWSAccessKey" -binary | openssl enc -base64`
Header="Date: $DateVar\nX-Amzn-Authorization: AWS3-HTTPS AWSAccessKeyId=$AWSKeyID,Algorithm=HmacSHA256,Signature=$Signature"
Header=`echo -en $Header`

CurrentIP=`curl -k -H "$Header" -d "name=$2" -G "https://route53.amazonaws.com/2013-04-01/hostedzone/$1/rrset?maxitems=1" 2>/dev/null | awk -v FS="(<Value>|<\/Value>)" '{print $2}' 2>/dev/null | sed '/^$/d'`

if [ "$3" == 'force' ]
	then
	CurrentIP=0
fi

if [ "$WanIP" != "$CurrentIP" ]
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
            <Name>$2.</Name>
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
	Result=`curl -k -H "$Header" -d "$Data" https://route53.amazonaws.com/2013-04-01/hostedzone/$1/rrset 2>/dev/null | awk -v FS="(<Status>|<\/Status>)" '{print $2}' 2>/dev/null | sed '/^$/d'`
	if [ "$Result" == 'PENDING' ]
		then
			echo "$2 has been qued to update"
		else
			echo "/!\ Update has Failed on $2"
	fi
	else
		echo "No Update Required"
fi