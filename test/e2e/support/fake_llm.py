#!/usr/bin/env python3
"""OpenAI-compatible stand-in for the end-to-end scenarios, so no issue data
ever leaves the machine. Listens on 127.0.0.1:$FAKE_LLM_PORT (default 4010).

  POST /v1/chat/completions  Bearer e2e-key -> a summary naming the issue subject
                             model e2e-empty -> empty content
                             any other key -> 401
  GET  /v1/models            Bearer e2e-key -> e2e-model, e2e-empty

Every request is appended as one JSON line to $FAKE_LLM_LOG, so a scenario can
prove what was (or was not) sent.
"""
import json
import os
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = int(os.environ.get('FAKE_LLM_PORT', '4010'))
LOG = os.environ.get('FAKE_LLM_LOG', 'fake_llm.jsonl')
KEY = 'Bearer e2e-key'


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def reply(self, status, payload):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def record(self, body):
        with open(LOG, 'a') as f:
            f.write(json.dumps({'method': self.command, 'path': self.path,
                                'auth': self.headers.get('Authorization'), 'body': body}) + '\n')

    def authorized(self):
        if self.headers.get('Authorization') == KEY:
            return True
        self.reply(401, {'error': {'message': 'Invalid API key (fake LLM)', 'type': 'invalid_request_error'}})
        return False

    def do_GET(self):
        self.record(None)
        if not self.path.endswith('/models'):
            return self.reply(404, {'error': {'message': 'not found'}})
        if self.authorized():
            self.reply(200, {'data': [{'id': 'e2e-model'}, {'id': 'e2e-empty'}]})

    def do_POST(self):
        length = int(self.headers.get('Content-Length') or 0)
        body = json.loads(self.rfile.read(length) or b'{}')
        self.record(body)
        if not self.path.endswith('/chat/completions'):
            return self.reply(404, {'error': {'message': 'not found'}})
        if not self.authorized():
            return
        if body.get('model') == 'e2e-empty':
            content = ''
        else:
            user = next((m['content'] for m in body.get('messages', []) if m.get('role') == 'user'), '{}')
            try:
                issue = json.loads(user)
            except ValueError:
                issue = {}
            if issue.get('subject') == 'ping':
                content = 'pong'
            else:
                time.sleep(2)  # long enough to see the "generating" state
                content = ('*Fake summary* of "%s": %d note(s), %d subtask(s).'
                           % (issue.get('subject'), len(issue.get('notes') or []), len(issue.get('subtasks') or [])))
        self.reply(200, {'id': 'e2e', 'object': 'chat.completion', 'model': body.get('model'),
                         'choices': [{'index': 0, 'finish_reason': 'stop',
                                      'message': {'role': 'assistant', 'content': content}}]})


if __name__ == '__main__':
    ThreadingHTTPServer(('127.0.0.1', PORT), Handler).serve_forever()
