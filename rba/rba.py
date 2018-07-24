#!/usr/bin/env python
# Filename: rba.py
"""
The dispatcher for the event display.

"""
import base64
import json
import os
import threading
import re
from time import sleep

import tornado

import tornado.ioloop
import tornado.web
import tornado.websocket
from tornado.options import define, options

import websocket

from .logger import get_logger

__author__ = "Tamas Gal"
__copyright__ = "Copyright 2018, Tamas Gal and the KM3NeT collaboration."
__credits__ = []
__license__ = "MIT"
__maintainer__ = "Tamas Gal"
__email__ = "tgal@km3net.de"
__status__ = "Development"

define(
    "ip",
    default="0.0.0.0",
    type=str,
    help="The WAN IP of this machine. You can use 127.0.0.1 for local tests.")
define(
    "port",
    default="8088",
    type=int,
    help="The RainbowAlga server will be available on this port.")


def token_urlsafe(nbytes=32):
    """Return a random URL-safe text string, in Base64 encoding.

    >>> token_urlsafe(16)  #doctest:+SKIP
    'Drmhze6EPcv0fN_81Bj-nA'

    """
    tok = os.urandom(nbytes)
    return base64.urlsafe_b64encode(tok).rstrip(b'=').decode('ascii')


class ClientManager(object):
    """Manage RainbowAlga clients.
    """

    def __init__(self):
        self._clients = {}
        self.log = get_logger(self.__class__.__name__)
        self.log.debug("Initialising")
        self.heartbeat_thread = threading.Thread(target=self.heartbeat)
        self.heartbeat_thread.daemon = True
        self.heartbeat_thread.start()

    def add(self, client):
        """Register a new client"""
        token = token_urlsafe(3)
        self._clients[token] = client
        self.log.info("New client with token '%s' registered.", token)
        return token

    def remove(self, token):
        """Remove a client with a given token"""
        del self._clients[token]
        self.log.info("Client with token '%s' removed.", token)

    def heartbeat(self, interval=30):
        """Ping clients ever `interval` seconds"""
        while True:
            self.log.info("Pinging %d clients.", len(self._clients))
            print(self._clients)
            for client in self._clients.values():
                print(client)
                client.message("Ping.")
            sleep(interval)

    def broadcast_status(self):
        """Send a status message to all clients"""
        self.log.info("Broadcasting status")
        self.broadcast("Number of connected clients: {}.".format(
            len(self._clients)))

    def message_to(self, token, data, kind):
        """Send a message to a client with a given token"""
        message = json.dumps({'kind': kind, 'data': data})
        self.log.info("Sent %d bytes (kind=%s) to %s.", len(message), kind,
                      token)
        self.raw_message_to(token, message)

    def raw_message_to(self, token, message):
        """Convert message to JSON and send it to the client with token"""
        if token not in self._clients:
            self.log.critical("Client with token '%s' not found!", token)
            return
        client = self._clients[token]
        try:
            client.write_message(message)
        except (AttributeError, tornado.websocket.WebSocketClosedError):
            self.log.error("Lost connection to client '%s'", client)
        else:
            print("Sent {} raw bytes to {}.".format(len(message), token))

    def broadcast(self, data, kind="info"):
        """Send a message to all connected clients"""
        self.log.info("Broatcasting to %d clients.", len(self._clients))
        for token in self._clients:
            self.message_to(token, data, kind)


class MessageProvider(tornado.websocket.WebSocketHandler):
    def __init__(self, *args, **kwargs):
        self.log = get_logger(self.__class__.__name__)
        self.log.debug("Initialising")
        self.client_manager = kwargs.pop('client_manager')
        super(MessageProvider, self).__init__(*args, **kwargs)

    def on_message(self, message):
        self.log.info("Client said: %s", message)
        try:
            token = json.loads(message)['token']
        except (ValueError, KeyError):
            self.log.error("Invalid JSON received: %s", message)
        else:
            self.client_manager.raw_message_to(token, message)


class EchoWebSocket(tornado.websocket.WebSocketHandler):
    """An echo handler for client/server messaging and debugging"""

    def __init__(self, *args, **kwargs):
        self.client_manager = kwargs.pop('client_manager')
        self._status = kwargs.pop('server_status')
        self._lock = kwargs.pop('lock')
        self._token = self.client_manager.add(self)
        self.log = get_logger(self.__class__.__name__)
        self.log.debug("Initialising")
        super(EchoWebSocket, self).__init__(*args, **kwargs)

    def check_origin(self, origin):
        return True

    def open(self):
        welcome = "WebSocket opened. Welcome to RainbowAlga!"
        self.message(welcome)
        self.message(self._token, 'token')
        self.message(self.status, 'status')
        self.client_manager.broadcast_status()

    def on_close(self):
        self.client_manager.remove(self._token)
        print("WebSocket closed, client removed.")

    def on_message(self, message):
        self.message(u"Client said '{}'".format(message))
        print("Client said: {}".format(message))

    @property
    def status(self):
        return self._status

    @status.setter
    def status(self, value):
        self._status = value

    def message(self, data, kind="info"):
        """Convert message to JSON and send it to the clients"""
        message = json.dumps({'kind': kind, 'data': data})
        print("Sent {} bytes.".format(len(message)))
        self.write_message(message)


def srv_event(token, hits, url):
    """Serve event to RainbowAlga"""

    if url is None:
        log.error("Please provide a valid RainbowAlga URL.")
        return

    ws_url = url + '/message'

    event = {
        "hits": {
            'pos': pos,
            'time': time,
            'tot': tot,
        }
    }

    srv_data(ws_url, token, event, 'event')


def srv_data(url, token, data, kind):
    """Serve data to RainbowAlga"""
    ws = websocket.create_connection(url)
    message = {'token': token, 'data': data, 'kind': kind}
    ws.send(json.dumps(message))
    ws.close()


def main():
    root = os.path.dirname(__file__)

    options.parse_command_line()

    ip = options.ip
    port = int(options.port)
    server_status = 'ready'
    lock = threading.Lock()
    client_manager = ClientManager()
    root_folder = os.path.join(os.path.dirname(__file__), 'www')

    log = get_logger("rainbowalga")

    print("Starting RainbowAlga.")
    print("Running on {}:{}".format(ip, port))

    settings = {
        'debug': True,
        'static_path': os.path.join(root, 'static'),
        'template_path': os.path.join(root, 'static/templates'),
    }

    application = tornado.web.Application([(r"/test", EchoWebSocket, {
        'client_manager': client_manager,
        'server_status': server_status,
        'lock': lock
    }), (r"/message", MessageProvider, {
        'client_manager': client_manager
    }), (r"/(.*)", tornado.web.StaticFileHandler, {
        "path": root_folder,
        "default_filename": "index.html"
    })], **settings)

    try:
        application.listen(port)
        tornado.ioloop.IOLoop.instance().start()
    except KeyboardInterrupt:
        print()
        log.warning("Exiting...")
        tornado.ioloop.IOLoop.instance().stop()


if __name__ == "__main__":
    main()
