#!/usr/bin/python

import sys
import json

try:
    webhook = json.load(sys.stdin)
except:
    webhook = ''

try:
    request = webhook["queryResult"]["intent"]["displayName"]
except:
    request = ''

try:
    idToken = webhook["originalDetectIntentRequest"]["payload"]["user"]["idToken"]
except:
    idToken = ''

try:
    params = webhook["queryResult"]["parameters"]
    if params["blank"]:
        answer = params["blank"]
    elif params["confirmation"]:
        answer = params["confirmation"]
    elif params["number"]:
        answer = str(int(params["number"]))
    elif params["float"]:
        answer = webhook["queryResult"]["queryText"]
    elif params["whole"] and params["fraction"]:
        answer = str(int(params["whole"])) + "." + str(int(params["fraction"]))
    elif params["top"] and params["bottom"]:
        answer = str(int(params["top"])) + "/" + str(int(params["bottom"]))
    elif params["name"]:
        answer = params["name"]
except:
    answer = ''

print "export", "Request="+request, "Answer="+'"'+answer.replace(" ", "")+'"', "IdToken="+idToken
