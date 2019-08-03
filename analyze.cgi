#!/bin/ksh

PATH=$PWD:$PATH

vars="$QUERY_STRING"
while [ "$vars" ]
do
	print $vars | IFS='&' read v vars
	[ "$v" ] && export $v
done
export LANG=en_US.UTF-8

print "Content-type: text/plain\\n"

in2csv -f csv --datetime-format "%b-%d-%Y %H:%M:%S" 2>/dev/null |
csvstat -c${column:-1} --freq-count 3 --csv | csvformat -D'|' -U3 |
tail -1 | IFS="|" read column_id column_name type nulls unique min max sum mean median stdev len freq

case "$type" in

	DateTime)
		print "The oldest date is ${min/ / at }, and the most recent is ${max/ / at }."
		;;
	Text)
		freq=${freq//\"/} freq=${freq//,/, }
		print "The most common values are: $freq."
		;;
	Number)
		print "The smallest value is $min, the largest value is $max, the middle value is $median, the average is $mean, and the standard deviation is ${stdev:-0}."
		;;
	*)
		print "That column contains $type data."
		;;
esac
