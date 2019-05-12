#!/usr/bin/python

import sys
import re
import email

TextFile = sys.argv[1]

msg = email.message_from_file(sys.stdin)
text = ""

if msg.is_multipart():
    for part in msg.walk():
        ctype = part.get_content_type()
        if re.match("text/.*", ctype):
            if not text:
                text = part.get_payload(decode=True)
else:
    text = msg.get_payload(decode=True)

fd = open(TextFile, "w")
fd.write(text)
fd.close()

print msg["From"]
