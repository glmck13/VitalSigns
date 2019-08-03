#!/bin/ksh

PATH=$PWD:$PATH
CONFIG=~welby/etc
TMPFILE=/tmp/plot$$.csv
trap "rm -f $TMPFILE" HUP INT QUIT TERM EXIT

vars="$QUERY_STRING"
while [ "$vars" ]
do
	print $vars | IFS='&' read v vars
	[ "$v" ] && export $v
done

cat - >$TMPFILE

print "Content-type: image/png\\n"

gnuplot -e "plotfile='$TMPFILE'" $CONFIG/plot.txt
