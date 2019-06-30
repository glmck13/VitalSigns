#!/bin/ksh

USAGE="u:m:a:d:fl"

while getopts "$USAGE" optchar ; do
	case $optchar in
	f|l) cmd="$optchar";;
	a|d) cmd="$optchar" proxy="$OPTARG";;
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

print "$user"

case "$cmd" in

	f|l|d)
		find . -type l -name "$user" | while read f
		do
			. ./${f%/*}/info.conf
			if [ "$cmd" = "f" ]; then
				print $Email
			elif [ "$cmd" = "l" ]; then
				print ${f##*/}
			elif [ "$proxy" = "-" -o "$proxy" = "$Email" ]; then
				rm -f $f
			fi
		done
		;;

	a)
		. ./$user/info.conf
		if [ ! "$proxy" ]; then print "no proxy specified" >&2; exit; fi
		if [ "$proxy" = "$Email" ]; then print "user cannot be their own proxy" >&2; exit; fi
		find . -name "info.conf" | xargs grep -il "Email=\"$proxy\"" | read proxy
		if [ ! "$proxy" ]; then print "proxy not found" >&2; exit; fi
		proxy=${proxy%/*}; cd $proxy
		ln -s $VITALRUN/$user $user
		;;
esac
