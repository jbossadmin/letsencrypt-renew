#!/bin/bash

# Variables
red='\e[0;31m'
green='\033[0;32m'
bluedark='\033[0;34m'
blue='\e[0;36m'
yellow='\e[0;33m'
bwhite='\e[1;37m'
nc='\033[0m'
certdir="/etc/letsencrypt/live"
date=`date +%Y-%m-%d`
hour=`date +%H:%M:%S`

# Verification du telegrambot.id
if [[ ! -f "/root/telegrambot.id" ]]; then
	userid=$(whiptail --title "UserID" --inputbox "Enter your UserID" 10 60 3>&1 1>&2 2>&3)
	token=$(whiptail --title "Token" --inputbox "Enter your Bot Token" 10 60 3>&1 1>&2 2>&3)
	echo "$userid#$token" > "/root/telegrambot.id"
else
	userid=$(cat "/root/telegrambot.id" | cut -d\# -f1)
	token=$(cat "/root/telegrambot.id" | cut -d\# -f2)
fi

# Functions
function notification() {
	URL="https://api.telegram.org/bot$5/sendMessage"
	DATE="$(date "+%d %b %Y %H:%M")"
	SERVERNAME=$(cat /etc/hostname | cut -d\. -f1)
	if [[ $1 == "renew" ]]; then
		TEXT="*[$SERVERNAME]* Le certificat pour $2 expire dans $3 jours. Renouvellement automatique !
		*Date:* $DATE"
	else
		TEXT="*[$SERVERNAME]* Aucun certificat n'a besoin d'être renouvelé."
	fi
	curl -s -d "chat_id=$4&text=$TEXT&disable_web_page_preview=true&parse_mode=markdown" $URL > /dev/null
}

# Main
echo -e "${blue}##################################################${nc}"
echo -e "${blue}### CHECKING RENEWAL STATUS FOR LE CERTIFICATE ###${nc}"
for site in $(ls -d $certdir/*)
do
	domain1=$(echo $site | cut -d\/ -f 5)
	echo ""
	echo $domain1 | grep -q "www"
	if [[ $? ==  0 ]]; then
		domain2=$(echo $domain1 | cut -d\. -f 2)
	fi
	declare -A monthtab=( ['Jan']="01" ['Feb']="02" ['Mar']="03" ['Apr']="04" ['May']="05" ['Jun']="06" ['Jul']="07" ['Aug']="08" ['Sep']="09" ['Oct']="10" ['Nov']="11" ['Dec']="12")
	monthcertdate=$(openssl x509 -enddate -noout -in $certdir/$domain1/fullchain.pem | cut -d\= -f2 | cut -d\  -f1)
	daycertdate=$(openssl x509 -enddate -noout -in $certdir/$domain1/fullchain.pem | cut -d\= -f2 | cut -d\  -f2)
	yearcertdate=$(openssl x509 -enddate -noout -in $certdir/$domain1/fullchain.pem | cut -d\= -f2 | cut -d\  -f4)
	hourcertdate=$(openssl x509 -enddate -noout -in $certdir/$domain1/fullchain.pem | cut -d\= -f2 | cut -d\  -f3)
	mounth=$(echo $date | cut -d\- -f 2)
	year=$(echo $date | cut -d\- -f 1)
	day=$(echo $date | cut -d\- -f 3)
	expiredate=$(date -d "$yearcertdate-${monthtab[$monthcertdate]}-$daycertdate" '+%s')
	todaydate=$(date -d "$year-$mounth-$day" '+%s')
	daytoexpire=$(( ( expiredate - todaydate )/(60*60*24) ))
	if [[ $daytoexpire -le 5 ]]; then
		echo -e " ${bwhite}[${red}CRITICAL${nc}${bwhite}]${nc} $domain1 - $daytoexpire days remaining"
		state="renew"
		echo -e "	--> Arrêt du service Nginx"
		service nginx stop
		bash /opt/certbot/certbot-auto certonly --standalone --preferred-challenges http-01 --agree-tos --non-interactive --force-renew --cert-name $domain1
		echo -e "	--> Redémarrage du service Nginx"
		service nginx start
		notification $state $domain1 $daytoexpire $userid $token
	elif [[ $daytoexpire -gt 5 && $daytoexpire -le 90 ]]; then
		echo -e " ${bwhite}[${green}OK${nc}${bwhite}]${nc} $domain1 - $daytoexpire days remaining"
		state="norenew"
	fi
done
if [[ $state == "norenew" ]]; then
	notification $state "" "" $userid $token
fi

echo ""