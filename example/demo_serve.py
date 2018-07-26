#!/usr/bin/env python
# -*- coding: utf-8 -*-
import json
import websocket
import sys

if len(sys.argv) < 3:
    print("Usage: ./demo_serve.py TOKEN FILENAME")
    raise SystemExit

URL = 'ws://127.0.0.1:8088/message'
TOKEN = sys.argv[1]
FILENAME = sys.argv[2]


def serve_data(data, kind, token, url=URL):
    """Serve data to RainbowAlga"""
    ws = websocket.create_connection(url)
    message = {'token': token, 'data': data, 'kind': kind}
    ws.send(json.dumps(message))
    ws.close()


with open(FILENAME, "r") as fobj:
    data = fobj.read()
    serve_data(data, 'event', TOKEN)
