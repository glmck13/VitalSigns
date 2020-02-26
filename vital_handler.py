from lxml import html
import requests
import os

def vital_handler(event, context):

    requestType = event['request']['type']
    userId = event['session']['user']['userId']
    sysInfo = event['context']['System']
    voice = os.environ.get('ALEXA_VOICE')
    speakStart = '<speak><voice name="{}">'.format(voice)
    speakStop = '</voice></speak>'
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

        elif intentName in ("AnalyzeData"):
            query['Request'] = intentName
            if 'slots' not in intent:
                query['Answer'] = ""
            elif 'column' in intent['slots'] and 'value' in intent['slots']['column']:
                    query['Answer'] = intent['slots']['column']['value']

        elif intentName in ("SubmitAnswer"):
            query['Request'] = intentName
            if 'slots' not in intent:
                query['Answer'] = ""
            elif 'blank' in intent['slots'] and 'value' in intent['slots']['blank']:
                    query['Answer'] = "blank"
            elif 'name' in intent['slots'] and 'value' in intent['slots']['name']:
                    query['Answer'] = intent['slots']['name']['value']
            elif 'number' in intent['slots'] and 'value' in intent['slots']['number']:
                    query['Answer'] = intent['slots']['number']['value']
            elif 'whole' in intent['slots'] and 'value' in intent['slots']['whole'] and 'fraction' in intent['slots'] and 'value' in intent['slots']['fraction']:
                    query['Answer'] = intent['slots']['whole']['value'] + "." + intent['slots']['fraction']['value']
            elif 'top' in intent['slots'] and 'value' in intent['slots']['top'] and 'bottom' in intent['slots'] and 'value' in intent['slots']['bottom']:
                    query['Answer'] = intent['slots']['top']['value'] + "/" + intent['slots']['bottom']['value']

    if query:
        query['Intent'] = "VitalIntent"
        query['Endpoint'] = sysInfo['apiEndpoint']
        query['Accesstoken'] = sysInfo['apiAccessToken']
        query['Device'] = sysInfo['device']['deviceId']
        query['User'] = userId
        query['Key'] = os.environ.get('ALEXA_KEY')
        query['Voice'] = voice

        page = requests.get(os.environ.get('ALEXA_URL'), auth=(os.environ.get('ALEXA_USER'), os.environ.get('ALEXA_PASS')), params=query)
        tree = html.fromstring(page.content)
        speech = html.tostring(tree.xpath('//speak')[0], encoding="unicode")
        subtree = tree.xpath('//body/p')
        try:
            card = subtree[0].xpath('string()')
            if subtree[1].xpath('string()') == "False":
                shouldEndSession = False
        except:
            card = ''; shouldEndSession = True
    else:
        speech = speakStart + "Goodbye!" + speakStop

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
                    "type": "SSML",
                    "ssml": speech
                }
            },
            "shouldEndSession": shouldEndSession
        }
    }

    if card in ("#Name", "#Email"):
        response["response"]["card"] = {
            "type": "AskForPermissionsConsent",
            "permissions": [
                "alexa::profile:given_name:read",
                "alexa::profile:email:read"
            ]
        }
    else:
        response["response"]["card"] = {
            "type": "Simple",
            "title": os.environ.get('ALEXA_CARDTITLE'),
            "content": card
        }

    return response
