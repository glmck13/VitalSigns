#!/bin/ksh

#
# alpine config: https://github.com/termux/termux-packages/issues/2023, https://www.ccdw.org/node/14
# alpine IMAP auth: disable-these-authenticators=PLAIN
#

EMAIL=${1:?Enter address}
SUBJECT=${2:?Enter subject}
MESSAGE=${3:?Enter message}
ATTACH=${4}

export TERM=xterm
expect >/dev/null <<EOF
set timeout 120
spawn alpine "$EMAIL"
expect "To AddrBk"
send "$SUBJECT$ATTACH\r\r$MESSAGE\rY"
expect "Alpine finished"
EOF
