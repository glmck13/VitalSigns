from __future__ import print_function
from lxml import html
import requests
import os

def vital_handler(event, context):

    requestType = event['request']['type']
    userId = event['session']['user']['userId']
    sysInfo = event['context']['System']
    query = {}; speech = ''; card = ''; shouldEndSession = True

    if requestType == "LaunchRequest":
        query['Request'] = requestType
        query['Answer'] = ""

    elif requestType == "IntentRequest":
        intent = event['request']['intent']
        intentName = intent['name']

        if intentName in ("AMAZON.FallbackIntent", "AMAZON.HelpIntent"):
            query['Request'] = "GetHelp"
            query['Answer'] = ""

        elif intentName in ("AMAZON.CancelIntent"):
            query['Request'] = "CancelSkill"
            query['Answer'] = ""

        elif intentName in ("AMAZON.YesIntent"):
            query['Request'] = "SubmitAnswer"
            query['Answer'] = "yes"

        elif intentName in ("AMAZON.NoIntent"):
            query['Request'] = "SubmitAnswer"
            query['Answer'] = "no"

        elif intentName in ("CreateAccount", "DeleteAccount", "EnterData", "EraseData", "SendReport", "UpdateProxy"):
            query['Request'] = intentName
            query['Answer'] = ""

        elif intentName in ("SubmitAnswer"):
            query['Request'] = intentName
            if not intent.has_key('slots'):
                query['Answer'] = ""
            elif intent['slots'].has_key('number') and intent['slots']['number'].has_key('value'):
                    query['Answer'] = intent['slots']['number']['value']
            elif intent['slots'].has_key('whole') and intent['slots']['whole'].has_key('value') and intent['slots'].has_key('fraction') and intent['slots']['fraction'].has_key('value'):
                    query['Answer'] = intent['slots']['whole']['value'] + "." + intent['slots']['fraction']['value']
            elif intent['slots'].has_key('top') and intent['slots']['top'].has_key('value') and intent['slots'].has_key('bottom') and intent['slots']['bottom'].has_key('value'):
                    query['Answer'] = intent['slots']['top']['value'] + "/" + intent['slots']['bottom']['value']

    if query:
        try:
            query['Endpoint'] = sysInfo['apiEndpoint']
            query['Accesstoken'] = sysInfo['apiAccessToken']
            query['Device'] = sysInfo['device']['deviceId']
        except:
            pass
        query['Intent'] = "VitalIntent"
        query['User'] = userId
        query['Key'] = os.environ.get('ALEXA_KEY')

        page = requests.get(os.environ.get('ALEXA_URL'), auth=(os.environ.get('ALEXA_USER'), os.environ.get('ALEXA_PASS')), params=query)
        tree = html.fromstring(page.content)
        speech = html.tostring(tree.xpath('//speak')[0])
        subtree = tree.xpath('//body/p')
        try:
            card = subtree[0].xpath('string()')
            if subtree[1].xpath('string()') == "False":
                shouldEndSession = False
        except:
            card = ''; shouldEndSession = True
    else:
        speech = "<speak>" + "Goodbye!" + "</speak>"

    response = {
        "version": "1.0",
        "sessionAttributes": {},
        "response": {
            "outputSpeech": {
                "type": "SSML",
                "ssml": speech
            },
            "reprompt": {
                "outputSpeech": {
                    "type": "PlainText",
                    "text": ""
                }
            },
            "card": {
                "type": "Simple",
                "title": os.environ.get('ALEXA_CARDTITLE'),
                "content": card
            },
            "shouldEndSession": shouldEndSession
        }
    }

    return response
