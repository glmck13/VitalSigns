#!/usr/bin/python

import sys
import json

try:
    customer = json.load(sys.stdin)
except:
    customer = ''

try:
    name = customer["given_name"]
except:
    name = ''

try:
    email = customer["email"]
except:
    email = ''

try:
    sub = customer["sub"]
except:
    sub = ''

print "export", "Name="+'"'+name+'"', "Email="+email, "User="+sub
