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
	gnuplot <<-EOF
	set term png size 900,1600
	set datafile separator ","
	set xdata time
	set timefmt "%b-%d-%Y %H:%M:%S"
	set key autotitle columnheader
	set multiplot layout 3,1
	set xtics timedate format "%b\n%d"
#	set autoscale noextend
	set style line 1 lc rgb "red" lt 1 lw 3 pt 7 pi -1 ps 1.5
	set style line 2 lc rgb "blue" lt 1 lw 3 pt 7 pi -1 ps 1.5
	set pointintervalbox 3
	set title "Blood Pressure"
	plot "report.csv" using 1:2 with linespoints ls 1, "" using 1:3 with linespoints ls 2
	set title "Pulse + Respiration"
	plot "" using 1:4 with linespoints ls 1, "" using 1:5 with linespoints ls 2
	set title "Temperature"
	plot "" using 1:6 with linespoints ls 1
	unset multiplot
	EOF
}

#
# Script
#

umask 077
PROXYEMAIL=~welby/etc/proxy.txt
TMPFILE=/tmp/$$.txt
XML_A="<speak><voice name=\"$Voice\">" XML_Z="</voice></speak>"

(( oneMin = 60 ))
(( oneHour = oneMin*60 ))
(( oneDay = oneHour*24 ))

typeset -i systolic; systolic=0
typeset -i diastolic; diastolic=0
typeset -i respiration; respiration=0
typeset -i pulse; pulse=0
typeset -F1 temperature; temperature=0

exec <>inpipe

while [ "$Request" ]
do
	case "$Request" in

	CancelSkill)
		Request=""
		;;

	UpdateProxy)
		ProxyList=$(proxyUtil.sh -u "$User" -f | tr '\n' '\r')
		[ ! "$ProxyList" ] && ProxyList="None"
		sed -e "s/%NAME%/$Name/g" -e "s/%PROXYLIST%/$ProxyList/" <$PROXYEMAIL | tr '\n' '\r' >$TMPFILE
		sendaway.sh "$Email" "Vital Signs proxy info" "$(<$TMPFILE)"
		rm -f $TMPFILE
		writeTandemRead "Proxy info has been sent to $Email. Is there anything else I can do for you $Name?" "" answer
		if [ "$answer" = "yes" ]; then Intro="OK. " Request="GetHelp"; else Request=""; fi
		;;

	GetHelp)
		[ ! "$Intro" ] && Intro=$(cat - <<-EOF
		"Send report" will email you a file with your vital sign history, as well as a graph of the data.  You'll also receive a history file and graph for anyone who has identified you as a proxy. "Erase data" will clear out your vital sign history. "Enter data" will prompt you for your current vital signs. "Update proxy" will email you instructions for how to add or delete a proxy on your account.  Lastly, "delete account" will completely remove your Vital Signs account.
		EOF
		)
		writeTandemRead "$Intro  How can I help you $Name?" "" answer; Intro=""
		;;

	EraseData)
		writeTandemRead "Are you sure you want to erase your data $Name?" "" confirm
		if [ "$confirm" = "yes" ]; then
			rm -f report.csv report.png
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
			if [ -f report.csv -a -f report.png ]; then
				report="./report.csv, ./report.png"
				msg="Here is ${Name}'s ($Email) report.\r\rTake care,\rVital Signs"
				sendaway.sh "$addr" "Vital Signs report for $Name" "$msg" "$report"
				(( ++count ))
			fi
		done
		cd ../$User; . ./info.conf
		Intro="$(plural $count report) sent to $Email. "
		writeTandemRead "$Intro Is there anything else I can do for you $Name?" "" answer
		if [ "$answer" = "yes" ]; then Intro="OK. " Request="GetHelp"; else Request=""; fi
		;;

	LaunchRequest)
		ls --full-time lastheard 2>/dev/null | read x x x x x d t x
		(( secs = $(date +%s) - $(date --date="$d $t" +%s) ))
		>lastheard

		writeTandemRead "Hello $Name. You last checked in $(timeElapsed). Do you want to enter your vital signs?" "" answer
		if [ "$answer" != "yes" ]; then Intro="OK. " Request="GetHelp"; else Intro="" Request="EnterData"; fi
		continue
		;;

	EnterData)
		confirm="no"
		while [ "$confirm" != "yes" ]
		do
			writeTandemRead "What is your blood pressure?" "" pressure
			writeTandemRead "What is your pulse, in beats per minute?" "" pulse
			writeTandemRead "What is your respiration rate, in breaths per minute?" "" respiration
			writeTandemRead "What is your temperature, in degrees Fahrenheit?" "" temperature
			systolic=${pressure%/*} diastolic=${pressure#*/}
			writeTandemRead "Your blood pressure is $systolic over $diastolic, your pulse is $pulse, your respiration rate is $respiration, and your temperature is $temperature.  Is that correct?" "" confirm
		done

		[ ! -f report.csv ] && print "Date,Systolic,Diastolic,Pulse,Respiration,Temperature" >report.csv
		print "$(date "+%b-%d-%Y %H:%M:%S"),$systolic,$diastolic,$pulse,$respiration,$temperature" >>report.csv
		plotdata >report.png

		writeTandemRead "Data saved. Is there anything else I can do for you $Name?" "" answer
		if [ "$answer" = "yes" ]; then Intro="OK. " Request="GetHelp"; else Request=""; fi
		;;
	esac
done

writeTandemRead "Thanks for using Vital Signs. Goodbye!" ""
