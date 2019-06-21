#!/bin/ksh

USAGE="u:m:a:d:"

while getopts "$USAGE" optchar ; do
	case $optchar in
	a|d) cmd="$optchar" filename="$OPTARG";;
	u)   user="$OPTARG";;
	m)   email="$OPTARG";;
	esac
done
shift $OPTIND-1

cd ~www-data/run/vitalsigns
VITALRUN=$PWD

if [ "$email" ]; then
	find . -name "info.conf" | xargs grep -il "Email=\"$email\"" | read user
	user=${user%/*} user=${user##*/}
fi

if [ ! "$user" ]; then print "must specify user/email account" >&2; exit; fi
if [ ! -d "$user" ]; then print "user account not found" >&2; exit; fi

case "$cmd" in

	d)
		rm -f ./$user/$filename
		;;

	a)
		cat - >./$user/$filename
		;;
esac
