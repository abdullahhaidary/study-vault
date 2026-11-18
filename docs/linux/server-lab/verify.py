"""Exercise the offline lab in an isolated Chrome via its debugging protocol.

Start Chrome with --remote-debugging-port=9237 and a disposable profile first.
Uses Python's standard library; does not touch the live Study Vault library.
"""
import base64
import json
import os
from pathlib import Path
import socket
import struct
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parent


class Browser:
    def __init__(self):
        pages = json.load(urlopen('http://127.0.0.1:9237/json'))
        endpoint = next(p['webSocketDebuggerUrl'] for p in pages if p['type'] == 'page')
        path = endpoint.split('9237', 1)[1]
        self.sock = socket.create_connection(('127.0.0.1', 9237), timeout=20)
        key = base64.b64encode(os.urandom(16)).decode()
        self.sock.sendall((f'GET {path} HTTP/1.1\r\nHost: localhost:9237\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n').encode())
        response = b''
        while not response.endswith(b'\r\n\r\n'):
            response += self.sock.recv(1)
        assert response.startswith(b'HTTP/1.1 101 '), response
        self.counter = 0
        self.errors = []

    def read(self, n):
        out = b''
        while len(out) < n:
            chunk = self.sock.recv(n-len(out))
            if not chunk:
                raise RuntimeError('Debugging connection closed')
            out += chunk
        return out

    def call(self, method, params=None):
        self.counter += 1
        data = json.dumps({'id': self.counter, 'method': method, 'params': params or {}}).encode()
        mask = os.urandom(4)
        length = len(data)
        header = bytes([129, 128 | length]) if length < 126 else bytes([129, 254]) + struct.pack('!H', length) if length < 65536 else bytes([129, 255]) + struct.pack('!Q', length)
        self.sock.sendall(header + mask + bytes(c ^ mask[i % 4] for i, c in enumerate(data)))
        fragments = b''
        while True:
            first, second = self.read(2)
            size = second & 127
            if size == 126:
                size = struct.unpack('!H', self.read(2))[0]
            elif size == 127:
                size = struct.unpack('!Q', self.read(8))[0]
            fragments += self.read(size)
            if not first & 128:
                continue
            result = json.loads(fragments)
            fragments = b''
            if result.get('method') == 'Runtime.exceptionThrown':
                self.errors.append(result)
            if result.get('id') == self.counter:
                if 'error' in result:
                    raise RuntimeError(result['error'])
                return result.get('result', {})

    def js(self, expression):
        result = self.call('Runtime.evaluate', {'expression': expression, 'returnByValue': True, 'awaitPromise': True})
        if 'exceptionDetails' in result:
            raise AssertionError(result['exceptionDetails'])
        return result['result'].get('value')


browser = Browser()
browser.call('Runtime.enable')
browser.call('Page.enable')
browser.call('Page.navigate', {'url': (ROOT / 'index.html').as_uri()})
browser.js("new Promise(resolve=>{if(document.readyState==='complete')resolve(true);else addEventListener('load',()=>resolve(true),{once:true})})")
assert browser.js('typeof specs') == 'object'
assert browser.js("JSON.parse(document.getElementById('lecture-source').textContent)") == (ROOT.parent / 'lesson 3.md').read_text()
assert browser.js("document.querySelectorAll('.reference').length") == 241

results = browser.js('''(()=>{
 const assert=(test,message)=>{if(!test)throw Error(message)};
 const results=[];
 for(let i=0;i<specs.length;i++){
  states[i]=fresh(i);select(i);
  assert(!complete(i),'Ticket '+i+' must start incomplete');
  for(const cmd of specs[i].solution){
   if(cmd.startsWith('edit ')){
    run(cmd);
    const p=cmd.slice(5);
    document.getElementById('editor-text').value=p===paths.unit?good.unit:p===paths.proxy?good.proxy:good.ssh;
    document.getElementById('save-file').click();
   }else run(cmd);
  }
  assert(complete(i),'Ticket '+i+' solution failed: '+JSON.stringify(status(state(),i)));
  results.push(specs[i].title);
 }
 select(3);states[3]=fresh(3);
 let blocked=false;try{run('systemctl reload ssh')}catch{blocked=true}
 assert(blocked,'SSH reload must require key login and validation');
 select(4);states[4]=fresh(4);blocked=false;try{run('ufw enable')}catch{blocked=true}
 assert(blocked,'Firewall activation without management access must fail');
 select(6);states[6]=fresh(6);
 assert(run('curl http://127.0.0.1:8080/readyz').includes('502'),'Broken upstream must fail');
 state().files[paths.proxy]=good.proxy;run('nginx -t');
 assert(run('curl http://127.0.0.1:8080/readyz').includes('502'),'Saved config must not activate before reload');
 run('systemctl reload nginx');assert(run('curl http://127.0.0.1:8080/readyz').includes('200'),'Reload must activate fixed upstream');
 select(7);states[7]=fresh(7);
 assert(run('curl http://127.0.0.1:8765/healthz').includes('200'),'Liveness should pass');
 assert(run('curl http://127.0.0.1:8765/readyz').includes('503'),'Readiness should fail');
 blocked=false;try{run('cat /missing')}catch{blocked=true}assert(blocked,'Missing path must fail');
 blocked=false;try{run('free -h; whoami')}catch{blocked=true}assert(blocked,'Unsupported chaining must fail');
 blocked=false;try{tokens('bash /lab/args.sh "unfinished')}catch{blocked=true}assert(blocked,'Unclosed quotes must fail');
 assert(tokens('bash /lab/args.sh "" stable')[2]==='','Empty quoted argument must survive');
 document.querySelector('[data-view="reference"]').click();
 document.getElementById('search').value='NGINX 502';document.getElementById('search').dispatchEvent(new Event('input'));
 assert([...document.querySelectorAll('.reference')].some(d=>!d.hidden&&d.textContent.includes('502')),'Reference search must find incident');
 document.getElementById('search').value='<absent-search-string>';document.getElementById('search').dispatchEvent(new Event('input'));
 assert(document.getElementById('search-count').textContent.startsWith('0 /'),'No-result search must be visible');
 document.getElementById('search').value='';document.getElementById('search').dispatchEvent(new Event('input'));
 select(0);document.querySelector('[data-view="lab"]').click();
 document.getElementById('command').value='cat /lab/args.sh';document.getElementById('shell').dispatchEvent(new Event('submit',{cancelable:true}));
 assert(document.getElementById('output').textContent.includes('Argument count'),'Terminal UI must show output');
 save();return results;
})()''')
browser.call('Page.reload')
browser.js("new Promise(resolve=>{if(document.readyState==='complete')resolve(true);else addEventListener('load',()=>resolve(true),{once:true})})")
assert browser.js("states[0].history.includes('cat /lab/args.sh')"), 'Progress must persist across reload'
browser.call('Emulation.setDeviceMetricsOverride', {'width':1440,'height':1000,'deviceScaleFactor':1,'mobile':False})
browser.js("view('learn')")
(ROOT / 'desktop.png').write_bytes(base64.b64decode(browser.call('Page.captureScreenshot', {'format':'png'})['data']))
browser.call('Emulation.setDeviceMetricsOverride', {'width':390,'height':844,'deviceScaleFactor':1,'mobile':True})
browser.js("select(13); view('lab')")
assert browser.js('document.documentElement.scrollWidth<=innerWidth'), 'Phone layout must not overflow horizontally'
(ROOT / 'mobile.png').write_bytes(base64.b64decode(browser.call('Page.captureScreenshot', {'format':'png'})['data']))
assert not browser.errors, browser.errors
print(json.dumps({'tickets_passed':len(results),'checks':['all supported solutions','key-login and firewall activation guards','saved versus active proxy configuration','liveness versus readiness','invalid inputs','terminal UI','full source integrity','reference search','reload persistence','desktop and phone screenshots','no browser exceptions']},indent=2))
browser.call('Browser.close')
