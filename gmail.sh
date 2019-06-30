#!/bin/ksh

PATH=$PWD:~welby/bin:$PATH

tmpFile=./message$$.txt
trap "rm -f $tmpFile" HUP INT QUIT TERM EXIT

typeset -l cmd subject

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
	msg="Your proxy updates have been completed.  Thanks for using Vital Signs!"
	sendaway.sh "$email" "Vital Signs confirmation" "$msg"
	;;

*data*)
	if [ "$(fileUtil.sh -m "$email" -a report.csv <$tmpFile)" ]; then
	msg="Your data file has been replaced.  Thanks for using Vital Signs!"
	sendaway.sh "$email" "Vital Signs confirmation" "$msg" "$tmpFile"
	fi
	;;

*script*)
	if [ "$(fileUtil.sh -m "$email" -a script.txt <$tmpFile)" ]; then
	msg="Your updated script has been installed.  Be sure to supply a corresponding plot routine. Thanks for using Vital Signs!"
	sendaway.sh "$email" "Vital Signs confirmation" "$msg" "$tmpFile"
	fi
	;;

*plot*)
	if [ "$(fileUtil.sh -m "$email" -a plot.chk <$tmpFile)" ]; then
	msg="Your updated plot routine is under review.  You will receive a confirmation message once it is installed. Thanks for using Vital Signs!"
	sendaway.sh "$email" "Vital Signs confirmation" "$msg" "$tmpFile"
	fi
	;;
esac
