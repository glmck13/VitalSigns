#!/bin/ksh

umask 077
XML_A="<speak><voice name=\"$Voice\">" XML_Z="</voice></speak>"

PATH=$PWD:~welby/bin:$PATH
cd ~www-data/run/vitalsigns

Name=$(curl -s -H "Authorization: Bearer $Accesstoken" $(urlencode -d $Endpoint)/v2/accounts/~current/settings/Profile.givenName)
if [[ $Name == \{*\} ]]; then
	Name=""
else
	Name=${Name//\"/}
fi

Email=$(curl -s -H "Authorization: Bearer $Accesstoken" $(urlencode -d $Endpoint)/v2/accounts/~current/settings/Profile.email)
if [[ $Email == \{*\} ]]; then
	Email=""
else
	Email=${Email//\"/}
fi

Answer=$(urlencode -d "$Answer")
Key=$(urlencode -d "$Key")

[ -d "$User" ] && Subscriber=$User

if [ ! "$Subscriber" ]; then

	case "$Request" in

		CancelSkill)
			Prompt="${XML_A}Goodbye!${XML_Z}<p>Vital Signs</p><p>True</p>"
			;;

		CreateAccount)
			if [ ! "$Name" ]; then
				Prompt="${XML_A}In order to create an account, I'd first like to know your name. Go to the home screen in your Alexa app, and grant me the necessary permission. Afterwards, try creating your account again. Goodbye!${XML_Z}<p>Vital Signs</p><p>True</p>"

			elif [ ! "$Email" ]; then
				Prompt="${XML_A}In order to create an account, I need access to your email address. Go to the home screen in your Alexa app, and grant me the necessary permission. Afterwards, try creating your account again. Goodbye!${XML_Z}<p>Vital Signs</p><p>True</p>"

			else
				Subscriber=$User
				mkdir $Subscriber; cd $Subscriber
				mknod inpipe p; mknod outpipe p; >firstheard; >lastheard
				cat - <<-EOF >info.conf
				Name="$Name"
				Email="$Email"
				BotScript="vitalbot.sh"
				export Name Email BotScript
				EOF
				chmod +x info.conf

				Prompt="${XML_A}$Name, I've created an account for you, and linked it to $Email. For tips on using Vital Signs say: 'help'. How can I help you?${XML_Z}<p>Vital Signs</p><p>False</p>"
			fi
			;;

		*)
			Prompt="${XML_A}Welcome to Vital Signs! I can't find an account for you on our system. If you would like one, just say: 'create account'. Otherwise say: 'cancel'. How can I help you?${XML_Z}<p>Vital Signs</p><p>False</p>"
			;;
	esac

else
	cd "$Subscriber"; . ./info.conf

	Prompt="${XML_A}Thanks for using Vital Signs. Goodbye!${XML_Z}<p>Vital Signs</p><p>True</p>"

	case "$Request" in

		DeleteAccount)

			Prompt="${XML_A}$Name, are you sure you want to delete your account? If so, confirm by saying 'delete account' a second time. Otherwise say: 'cancel'.${XML_Z}<p>Vital Signs</p><p>False</p>"

			if [ -f .confirm ]; then
				ls --full-time .confirm 2>/dev/null | read x x x x x d t x
				(( secs = $(date +%s) - $(date --date="$d $t" +%s) ))
				if (( secs <= 30 )); then
					cd ..; rm -fr $Subscriber
					proxyUtil.sh -u $Subscriber -d- 2>/dev/null
					Prompt="${XML_A}$Name, your account has been deleted. Thank you for using Vital Signs. Goodbye!${XML_Z}<p>Vital Signs</p><p>True</p>"
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
			timeout 2m $BotScript alexa >/dev/null 2>&1 &
			read Prompt <outpipe
			;;
	esac
fi

print "<html><body>$Prompt</body></html>"
