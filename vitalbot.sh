#!/bin/ksh

#
# Local function definitions
#

plural () {
	if (( $1 == 1 )); then
		print ${1} ${2%s}
	else
		print ${1} ${2%s}s
	fi
}

timeElapsed () {
typeset -i relmajor relminor

if (( secs < $oneHour )); then
	(( relmajor = secs / oneMin ))
	(( relminor = secs % oneMin ))
	print -- "$(plural $relmajor minutes) \\c"
#	(( relminor > 0 )) && print -- "and $(plural $relminor seconds) \\c"
	print "ago"
elif (( secs < $oneDay)); then
	(( relmajor = secs / oneHour ))
	(( relminor = (secs % oneHour) / oneMin ))
	print -- "$(plural $relmajor hours) \\c"
	(( relminor > 0 )) && print -- "and $(plural $relminor minutes) \\c"
	print "ago"
else
	(( relmajor = secs / oneDay ))
	(( relminor = (secs % oneDay) / oneHour ))
	print -- "$(plural $relmajor days) \\c"
	(( relminor > 0 )) && print -- "and $(plural $relminor hours) \\c"
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
	url="${scriptfile%/*}/plot.url"
	if [ -f "$url" ]; then
		url=$(<$url); curl -s --data-binary @- $url
	fi
}

analyzedata () {
	url="./analyze.url"
	[ ! -f "$url" ] && url="$CONFIG/$url"
	url=$(<$url); curl -s --data-binary @- $url?column=${1}
}

#
# Script
#

umask 077
CONFIG=~welby/etc
PROXYEMAIL=$CONFIG/proxy.txt
TMPFILE=/tmp/$$.txt
XML_A="<speak><voice name=\"$Voice\">" XML_Z="</voice></speak>"
LANG=en_US.UTF-8; export LANG #csvkit tools

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
		sed -e "s/%ASSISTANT%/$Assistant/g" -e "s/%NAME%/$Name/g" -e "s/%PROXYLIST%/$ProxyList/" <$PROXYEMAIL | tr '\n' '\r' >$TMPFILE
		sendaway.sh "$Email" "$Assistant proxy information" "$(<$TMPFILE)"
		rm -f $TMPFILE
		writeTandemRead "Proxy information has been sent to $Email. In order to update your proxies, just reply back to that email requesting to add or delete users. Is there anything else I can do for you $Name?" "" answer
		if [ "$answer" = "yes" ]; then Intro="OK. " Request="GetHelp"; else Request=""; fi
		;;

	GetHelp)
		[ ! "$Intro" ] && Intro=$(cat - <<-EOF
		"Enter data" will prompt you for your current vital signs. "Erase data" will delete your vital sign history. "Analyze data" will provide stats on the data you've entered, while "analyze column" followed by a number will give you stats for just a single column. "Send report" will email your history file, together with a graph of the data. You'll also receive a history file and graph for anyone who has identified you as a proxy. "Update proxy" will email you instructions for how to add or delete a proxy on your account. Lastly, "delete account" will completely remove your account.
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

	AnalyzeData)
		column="$Answer"
		if [ -f report.csv.cpt ]; then

			rows=$(ccrypt -E Key -c report.csv.cpt | wc -l)
			(( --rows ))

			x=$(ccrypt -E Key -c report.csv.cpt | head -1)
			set -A title "" ${x//,/ }
			cols=${#title[*]}
			(( --cols ))

			if [ $rows -le 0 ]; then
				Intro="Your vital sign data file is empty. "

			elif [ ! "$column" ]; then
				Intro="Your vital sign data file contains $(plural $rows rows) and $(plural $cols columns) of data. "
				column=1; while (( column <= cols ))
				do
					writeTandemRead "$Intro Column $column is labled \"${title[$column]}\".  Do you want stats for this column?" "" answer
					if [ "$answer" = "yes" ]; then
						Intro=$(ccrypt -E Key -c report.csv.cpt | analyzedata $column)
					else
						Intro=""
					fi
					(( ++column ))
				done

			elif [ $column -ge 1 -a $column -le $cols ]; then
				Intro="Column $column is labeled \"${title[$column]}\", and contains $(plural $rows rows) of data. $(ccrypt -E Key -c report.csv.cpt | analyzedata $column) "

			else
				Intro="$column is not a valid column number. Your file contains $(plural $cols columns). "
			fi
		else
			Intro="You don't have any vital sign data. "
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
				ccrypt -E Key -d report.csv; plotdata <report.csv >report.png
				report="./report.csv"
				[ -s report.png ] && report+=", ./report.png"
				msg="Here is ${Name}'s ($Email) report.\r\rTake care,\r$Assistant"
				sendaway.sh "$addr" "$Assistant report for $Name" "$msg" "$report"
				(( ++count ))
				rm -f report.png; ccrypt -E Key -e report.csv
			fi
		done
		cd ../$User; . ./info.conf
		Intro="$(plural $count reports) sent to $Email. "
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

		if [ "$Platform" = "Google" ]; then
			Intro="Welcome back $Name, it's good to hear from you again! Remember, the information provided by this action is not a substitute for advice from a medical professional. Alright, you last checked in $(timeElapsed). Do you want to enter your vital signs?"
		else
			Intro="Welcome back $Name, it's good to hear from you again! You last checked in $(timeElapsed). Do you want to enter your vital signs?"
		fi
		writeTandemRead "$Intro" "" answer
		if [ "$answer" != "yes" ]; then Intro="OK. " Request="GetHelp"; else Intro="" Request="EnterData"; fi
		continue
		;;

	esac
done

writeTandemRead "Thanks for using $Assistant. Goodbye!" ""
