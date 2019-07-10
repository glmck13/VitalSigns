#!/usr/bin/python

import sys
from lxml import html

card = ''; expectUserResponse = False

tree = html.fromstring(sys.stdin.read())
speech = html.tostring(tree.xpath('//speak')[0])
subtree = tree.xpath('//body/p')
try:
    card = subtree[0].xpath('string()')
    if subtree[1].xpath('string()') == "False":
        expectUserResponse = True
except:
    card = ''; expectUserResponse = False

if card in ("#Name", "#Email"):
    response = {
        "payload": {
            "google": {
                "expectUserResponse": True,
                "systemIntent": {
                    "intent": "actions.intent.SIGN_IN",
                    "data": {
                        "@type": "type.googleapis.com/google.actions.v2.SignInValueSpec"
                    }
                }
            }
        }
    }
else:
    response = {
        "payload": {
            "google": {
                "expectUserResponse": expectUserResponse,
                "richResponse": {
                    "items": [
                        {
                            "simpleResponse": {
                                "textToSpeech": speech,
                                "displayText": card
                            }
                        }
                    ]
                }
            }
        }
    }

print response
