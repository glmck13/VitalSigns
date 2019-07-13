#!/bin/ksh

writeTandemRead () {

	ml="${XML_A}$1${XML_Z}"

	ml+="<p>${2:-$1}</p>"

	if [ "$3" ]; then ml+="<p>False</p>"; else ml+="<p>True</p>"; fi

	print "$ml"
}

umask 077
PATH=$PWD:~welby/bin:$PATH
cd ~www-data/run/vitalsigns

if [ "$Voice" ]; then
XML_A="<speak><voice name=\"$Voice\">" XML_Z="</voice></speak>"
else
XML_A="<speak>" XML_Z="</speak>"
fi

Answer=$(urlencode -d "$Answer")
Key=$(urlencode -d "$Key")

[ -d "$User" ] && Subscriber=$User

if [ ! "$Subscriber" ]; then

	case "$Request" in

		CancelSkill)
			Prompt=$(writeTandemRead "Thanks for using Vital Signs. Goodbye!" "")
			;;

		CreateAccount)
			if [ "$Endpoint" ]; then
			Name=$(curl -s -H "Authorization: Bearer $Accesstoken" $(urlencode -d $Endpoint)/v2/accounts/~current/settings/Profile.givenName)
			if [[ $Name == \{*\} ]]; then
				Name=""
			else
				Name=${Name//\"/}
			fi
			fi

			if [ "$Endpoint" ]; then
			Email=$(curl -s -H "Authorization: Bearer $Accesstoken" $(urlencode -d $Endpoint)/v2/accounts/~current/settings/Profile.email)
			if [[ $Email == \{*\} ]]; then
				Email=""
			else
				Email=${Email//\"/}
			fi
			fi

			if [ "$Device" ]; then
			TZ=$(curl -s -H "Authorization: Bearer $Accesstoken" $(urlencode -d $Endpoint)/v2/devices/$Device/settings/System.timeZone)
			TZ=${TZ//\"/}
			else
			TZ=$(timedatectl) TZ=${TZ#*zone: } TZ=${TZ%% *}
			fi
			export TZ

			if [ ! "$Name" ]; then
				Prompt=$(writeTandemRead "In order to create an account, I'd first like to know your name. Go to the home screen in your app, and grant me the necessary permission. Afterwards, try creating your account again. Goodbye!" "#Name")

			elif [ ! "$Email" ]; then
				Prompt=$(writeTandemRead "In order to create an account, I need access to your email address. Go to the home screen in your app, and grant me the necessary permission. Afterwards, try creating your account again. Goodbye!" "#Email")

			else
				Subscriber=$User
				mkdir $Subscriber; cd $Subscriber
				mknod inpipe p; mknod outpipe p; >firstheard; >lastheard
				cat - <<-EOF >info.conf
				Name="$Name"
				Email="$Email"
				TZ="$TZ"
				BotScript="vitalbot.sh"
				export Name Email TZ BotScript
				EOF
				chmod +x info.conf

				Prompt=$(writeTandemRead "$Name, I've created an account for you, and linked it to $Email. For tips on using Vital Signs say: 'help'. How can I help you?" "" "?")
			fi
			;;

		*)
			if [ "$Platform" = "Google" ]; then
			Prompt=$(writeTandemRead "Welcome to Vital Signs! You can now specify what health metrics you'd like to track using this action. For the latest updates, please visit: vital signs 'dot' dyn dns 'dot' org. Also, please be aware that the information provided by this action is not a substitute for advice from a medical professional. Alright, I can't find an account for you on our system. If you would like one, just say: 'create account'. Otherwise say: 'cancel'. How can I help you?" "" "?")
			else
			Prompt=$(writeTandemRead "Welcome to Vital Signs! You can now specify what health metrics you'd like to track using this skill. For the latest updates, please visit: vital signs '.'  dyn dns '.' org. I can't find an account for you on our system. If you would like one, just say: 'create account'. Otherwise say: 'cancel'. How can I help you?" "" "?")
			fi
			;;
	esac

else
	cd "$Subscriber"; . ./info.conf

	Prompt=$(writeTandemRead "Thanks for using Vital Signs. Goodbye!" "")

	case "$Request" in

		DeleteAccount)

			Prompt=$(writeTandemRead "$Name, are you sure you want to delete your account? If so, confirm by saying 'delete account' a second time. Otherwise say: 'cancel'." "" "?")

			if [ -f .confirm ]; then
				ls --full-time .confirm 2>/dev/null | read x x x x x d t x
				(( secs = $(date +%s) - $(date --date="$d $t" +%s) ))
				if (( secs <= 30 )); then
					proxyUtil.sh -u $Subscriber -d- 2>/dev/null
					cd ..; rm -fr $Subscriber
					Prompt=$(writeTandemRead "$Name, your account has been deleted. Thanks for using Vital Signs. Goodbye!" "")
				else
					>.confirm
				fi
			else
				>.confirm
			fi
			;;

		SubmitAnswer)
			if [ "$(fuser inpipe 2>/dev/null)" ]; then
				print "${Answer:-?}" >inpipe
				read Prompt <outpipe
			fi
			;;

		*)
			fuser -k inpipe >/dev/null 2>&1
			timeout 2m $BotScript $Platform >/dev/null 2>&1 &
			read Prompt <outpipe
			;;
	esac
fi

print "<html><body>$Prompt</body></html>"
