#!/usr/bin/python

import sys
import json

request = ''; answer = ''; idToken = ''

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
    if request in ("SubmitAnswer"):
        if params["blank"] != '':
            answer = params["blank"]
        elif params["confirmation"] != '':
            answer = params["confirmation"]
        elif params["number"] != '':
            answer = str(int(params["number"]))
        elif params["float"] != '':
            answer = webhook["queryResult"]["queryText"]
        elif params["whole"] != '' and params["fraction"] != '':
            answer = str(int(params["whole"])) + "." + str(int(params["fraction"]))
        elif params["top"] != '' and params["bottom"] != '':
            answer = str(int(params["top"])) + "/" + str(int(params["bottom"]))
        elif params["name"] != '':
            answer = params["name"]
    elif request in ("AnalyzeData"):
        if params["column"] != '':
            answer = str(int(params["column"]))
except:
    answer = ''

print "export", "Request="+request, "Answer="+'"'+answer.replace(" ", "")+'"', "IdToken="+idToken
