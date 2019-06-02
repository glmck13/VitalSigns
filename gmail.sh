#!/bin/ksh

PATH=$PWD:~welby/bin:$PATH

tmpFile=message$$.txt
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
		proxyUtil.sh -m "$email" -${cmd:0:1} "$proxy"
	done
	;;

*script*)
	cat $tmpFile | fileUtil.sh -m "$email" -a script.txt
	;;

*plot*)
	cat $tmpFile | fileUtil.sh -m "$email" -a plot.chk
	;;
esac
