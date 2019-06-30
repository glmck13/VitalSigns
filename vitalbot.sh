#!/bin/ksh

#
# Local function definitions
#

plural () {
	if (( $1 == 1 )); then
		print ${1} ${2}
	else
		print ${1} ${2}s
	fi
}

timeElapsed () {
typeset -i relmajor relminor

if (( secs < $oneHour )); then
	(( relmajor = secs / oneMin ))
	(( relminor = secs % oneMin ))
	print -- "$(plural $relmajor minute) \\c"
#	(( relminor > 0 )) && print -- "and $(plural $relminor second) \\c"
	print "ago"
elif (( secs < $oneDay)); then
	(( relmajor = secs / oneHour ))
	(( relminor = (secs % oneHour) / oneMin ))
	print -- "$(plural $relmajor hour) \\c"
	(( relminor > 0 )) && print -- "and $(plural $relminor minute) \\c"
	print "ago"
else
	(( relmajor = secs / oneDay ))
	(( relminor = (secs % oneDay) / oneHour ))
	print -- "$(plural $relmajor day) \\c"
	(( relminor > 0 )) && print -- "and $(plural $relminor hour) \\c"
	print "ago"
fi
}

writeTandemRead () {

	ml="${XML_A}$1${XML_Z}"

	ml+="<p>${2:-$1}</p>"

	if [ "$3" ]; then ml+="<p>False</p>"; else ml+="<p>True</p>"; fi

	print "$ml" >outpipe

	[ "$3" ] && read $3 <inpipe
}

plotdata () {
	plotfile="${scriptfile%/*}/plot.txt"
	[ -f "$plotfile" ] && gnuplot <$plotfile
}

#
# Script
#

umask 077
CONFIG=~welby/etc
PROXYEMAIL=$CONFIG/proxy.txt
TMPFILE=/tmp/$$.txt
XML_A="<speak><voice name=\"$Voice\">" XML_Z="</voice></speak>"

(( oneMin = 60 ))
(( oneHour = oneMin*60 ))
(( oneDay = oneHour*24 ))

scriptfile="./script.txt"
[ ! -f "$scriptfile" ] && scriptfile="$CONFIG/$scriptfile"
n=0; while read line
do
	[ ! "$line" ] && continue

	if [[ "$line" == \#* ]]; then
		header=",${line#\#}"
	else
		x=$line\"\" x=${x#*\"} x=${x%%\"*} header+=",$x"
		label[$n]=${x:-missing label}
		prompt[$n]="${line//\"/}"
		(( ++n ))
	fi
done <$scriptfile
signs=$n

exec <>inpipe

while [ "$Request" ]
do
	case "$Request" in

	CancelSkill)
		Request=""
		;;

	UpdateProxy)
		ProxyList=$(proxyUtil.sh -u "$User" -f | tr '\n' '\r')
		[ ! "$ProxyList" ] && ProxyList="(no proxies)"
		sed -e "s/%NAME%/$Name/g" -e "s/%PROXYLIST%/$ProxyList/" <$PROXYEMAIL | tr '\n' '\r' >$TMPFILE
		sendaway.sh "$Email" "Vital Signs proxy information" "$(<$TMPFILE)"
		rm -f $TMPFILE
		writeTandemRead "Proxy information has been sent to $Email. In order to update your proxies, just reply back to that email requesting to add or delete users. Is there anything else I can do for you $Name?" "" answer
		if [ "$answer" = "yes" ]; then Intro="OK. " Request="GetHelp"; else Request=""; fi
		;;

	GetHelp)
		[ ! "$Intro" ] && Intro=$(cat - <<-EOF
		"Enter data" will prompt you for your current vital signs. "Erase data" will clear out your vital sign history. "Send report" will email you a file with your vital sign history, as well as a graph of the data. You'll also receive a history file and graph for anyone who has identified you as a proxy. "Update proxy" will email you instructions for how to add or delete a proxy on your account. Lastly, "delete account" will completely remove your Vital Signs account.
		EOF
		)
		writeTandemRead "$Intro  How can I help you $Name?" "" answer; Intro=""
		;;

	EraseData)
		writeTandemRead "Are you sure you want to erase your data $Name?" "" confirm
		if [ "$confirm" = "yes" ]; then
			rm -f report.*
			Intro="Data erased."
		else
			Intro="Request cancelled."
		fi
		writeTandemRead "$Intro Is there anything else I can do for you $Name?" "" answer
		if [ "$answer" = "yes" ]; then Intro="OK. " Request="GetHelp"; else Request=""; fi
		;;

	SendReport)
		addr=$Email count=0
		for f in $User $(find . -type l)
		do
			cd ../$f; . ./info.conf
			if [ -f report.csv.cpt ]; then
				ccrypt -E Key -d report.csv; plotdata >report.png
				report="./report.csv"
				[ -s report.png ] && report+=", ./report.png"
				msg="Here is ${Name}'s ($Email) report.\r\rTake care,\rVital Signs"
				sendaway.sh "$addr" "Vital Signs report for $Name" "$msg" "$report"
				(( ++count ))
				rm -f report.png; ccrypt -E Key -e report.csv
			fi
		done
		cd ../$User; . ./info.conf
		Intro="$(plural $count report) sent to $Email. "
		writeTandemRead "$Intro Is there anything else I can do for you $Name?" "" answer
		if [ "$answer" = "yes" ]; then Intro="OK. " Request="GetHelp"; else Request=""; fi
		;;

	EnterData)
		confirm="yes"
		(( signs > 0 )) && confirm="no"
		while [ "$confirm" != "yes" ]
		do
			n=0; while (( n < signs ))
			do
				writeTandemRead "${prompt[$n]}" "" x
				value[$n]=$x
				(( ++n ))
			done
			rusure=""
			n=0; while (( n < signs ))
			do
				x=${value[$n]} x=${x//\// over }
				rusure+="Your ${label[$n]} is $x. "
				(( ++n ))
			done
			rusure+="Is that correct?"
			writeTandemRead "$rusure" "" confirm
		done

		if [ -f report.csv ]; then
			rm -f report.csv.*
		elif [ -f report.csv.cpt ]; then
			ccrypt -E Key -d report.csv
		else
			print "Date$header" >report.csv
		fi

		typeset -l y
		line="$(date "+%b-%d-%Y %H:%M:%S")"
		n=0; while (( n < signs ))
		do
			y=${value[$n]} y=${y//\//,} y=${y//blank/}
			line+=",$y"
			(( ++n ))
		done
		print "$line" >>report.csv
		ccrypt -E Key -e report.csv

		writeTandemRead "Data saved. Is there anything else I can do for you $Name?" "" answer
		if [ "$answer" = "yes" ]; then Intro="OK. " Request="GetHelp"; else Request=""; fi
		;;

	*)
		ls --full-time lastheard 2>/dev/null | read x x x x x d t x
		(( secs = $(date +%s) - $(date --date="$d $t" +%s) ))
		>lastheard

		writeTandemRead "Hello $Name. You last checked in $(timeElapsed). Do you want to enter your vital signs?" "" answer
		if [ "$answer" != "yes" ]; then Intro="OK. " Request="GetHelp"; else Intro="" Request="EnterData"; fi
		continue
		;;

	esac
done

writeTandemRead "Thanks for using Vital Signs. Goodbye!" ""
