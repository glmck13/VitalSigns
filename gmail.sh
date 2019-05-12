#!/bin/ksh

PATH=$PWD:~welby/bin:$PATH

TmpFile=message$$.txt
typeset -l cmd

cd ~/tmp; umask 077

gmail.py $TmpFile | read email

email=${email#*<} email=${email%>*}
[ "$email" -a -f "$TmpFile" ] || exit 0

recode -f html..ascii <$TmpFile | tr -d '\r' | sed -e "s/<[^>]\+>//g" |
	grep '@' | sed -e "s/  *:/:/g" -e "s/:  */:/g" | grep -o -iE "add[a-z]*:[^ ]+|del[a-z]*:[^ ]+" |
while IFS=":," read cmd proxy
do
	proxyUtil.sh -m "$email" -${cmd:0:1} "$proxy"
done

rm -f $TmpFile
