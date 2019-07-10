#!/bin/ksh

PATH=$PWD:$PATH

vars="$QUERY_STRING"
while [ "$vars" ]
do
	print $vars | IFS='&' read v vars
	[ "$v" ] && export $v
done

print "Content-type: application/json\\n"

case "$Intent" in
	VitalIntent)
		eval $(vitalreq.py)
		IdToken=${IdToken#*.} IdToken=${IdToken%.*}
		eval $(echo -n "$IdToken" | base64 -id 2>/dev/null | gid.py)
		vitalsigns.sh | grsp.py
		;;
esac
