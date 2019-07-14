#!/bin/ksh

PATH=$PWD:~welby/bin:$PATH

cd ~www-data/run/vitalsigns
VITALRUN=$PWD
WARNDAY=${1:-30}
GRACEDAYS=${2:-5}
let PURGEDAY=$WARNDAY+$GRACEDAYS

find . -daystart -name lastheard -mtime $WARNDAY | while IFS='/' read x user x
do
	. ./$user/info.conf
	sendaway.sh "$Email" "Vital Signs pending account deletion" "$Name - You have not accessed your Vital Signs account in the last $WARNDAY days.  If you want to retain your account, please access Vital Signs within the next $GRACEDAYS days, otherwise your account will be deleted.  If you have recommendations for improving the skill, please feel free to respond to this email with your suggestions.  Thanks for using Vital Signs!"
done

find . -daystart -name lastheard -mtime +$PURGEDAY | while IFS='/' read x user x
do
	rm -fr ./$user
done
