#!/bin/ksh

PATH=$PWD:~welby/bin:$PATH

tmpFile=./message$$.txt
trap "rm -f $tmpFile" HUP INT QUIT TERM EXIT

typeset -l cmd subject

cd ~www-data/run/vitalsigns
VITALRUN=$PWD

cd ~/tmp; umask 077

gmail.py $tmpFile | IFS='|' read email subject

email=${email#*<} email=${email%>*}
[ "$email" -a -f "$tmpFile" ] || exit 0

recode -f html..ascii <$tmpFile | tr -d '\r' | sed -e "s/<[^>]\+>//g" >$tmpFile.tmp; mv $tmpFile.tmp $tmpFile

case "$subject" in

*proxy*)
	cat $tmpFile | grep '@' | sed -e "s/  *:/:/g" -e "s/:  */:/g" |
		grep -o -iE "add[a-z]*:[^ ]+|del[a-z]*:[^ ]+" |
	while IFS=":," read cmd proxy
	do
		proxyUtil.sh -m "$email" -${cmd:0:1} "$proxy" >/dev/null
	done
	user=$(fileUtil.sh -m "$email")
	if [ "$user" ]; then
	. $VITALRUN/$user/info.conf
	msg="$Name - Your proxy updates have been completed.  Thanks for using $Assistant!"
	sendaway.sh "$email" "$Assistant confirmation" "$msg"
	fi
	;;

*data*)
	user=$(fileUtil.sh -m "$email" -a report.csv <$tmpFile)
	if [ "$user" ]; then
	. $VITALRUN/$user/info.conf
	msg="$Name - Your data file has been replaced.  Thanks for using $Assistant!"
	sendaway.sh "$email" "$Assistant confirmation" "$msg" "$tmpFile"
	fi
	;;

*script*)
	user=$(fileUtil.sh -m "$email" -a script.txt <$tmpFile)
	if [ "$user" ]; then
	. $VITALRUN/$user/info.conf
	msg="$Name - Your updated script has been installed.  Be sure to supply a corresponding plot routine. Thanks for using $Assistant!"
	sendaway.sh "$email" "$Assistant confirmation" "$msg" "$tmpFile"
	fi
	;;

*plot*)
	user=$(grep -o 'http[s]*://[^[:space:]]*' $tmpFile | fileUtil.sh -m "$email" -a plot.url)
	if [ "$user" ]; then
	. $VITALRUN/$user/info.conf
	msg="$Name - Your URL has been configured. Thanks for using $Assistant!"
	sendaway.sh "$email" "$Assistant confirmation" "$msg" "$tmpFile"
	fi
	;;

*analyze*)
	user=$(grep -o 'http[s]*://[^[:space:]]*' $tmpFile | fileUtil.sh -m "$email" -a analyze.url)
	if [ "$user" ]; then
	. $VITALRUN/$user/info.conf
	msg="$Name - Your URL has been configured. Thanks for using $Assistant!"
	sendaway.sh "$email" "$Assistant confirmation" "$msg" "$tmpFile"
	fi
	;;
esac
