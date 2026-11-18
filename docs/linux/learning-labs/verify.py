"""Browser acceptance checks for the portable learning folder and all 120 tickets."""
import base64
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parent
# Reuse the standard-library Chrome debugging client from Lecture 3's verifier.
client=(ROOT.parent/'server-lab/verify.py').read_text().split('browser = Browser()')[0]
exec(compile(client,str(ROOT.parent/'server-lab/verify.py'),'exec'),globals())
ROOT=Path(__file__).resolve().parent
DEST=Path('/home/haidary/Downloads/Linux_Learning_Labs')
browser=Browser()
browser.call('Runtime.enable')
browser.call('Page.enable')
def navigate(path):
    browser.call('Page.navigate',{'url':path.as_uri()})
    browser.js("new Promise(resolve=>{if(document.readyState==='complete')resolve(true);else addEventListener('load',()=>resolve(true),{once:true})})")

navigate(DEST/'other/index.html')
assert browser.js('LABS.length')==120
report=browser.js(r'''(()=>{
 const assert=(v,m)=>{if(!v)throw Error(m)},results=[],failures=[];
 assert(new Set(LABS.map(l=>l.title)).size===120,'Titles must be distinct');
 assert(new Set(LABS.map(l=>l.topic)).size===30,'Expected 30 topics');
 for(let i=0;i<LABS.length;i++){
  const lab=LABS[i];saved[lab.id]=fresh(lab);choose(i);
  if(complete(lab)){failures.push(lab.id+' starts complete');continue;}
  try{
   for(const command of lab.solution){
    if(command.startsWith('edit ')){
     run(command);document.getElementById('editor-text').value=lab.edits[command.slice(5)];document.getElementById('save-file').click();
    }else run(command);
   }
   if(!complete(lab))failures.push(lab.id+' failed objectives '+JSON.stringify(checks(lab,state())));
   else results.push(lab.id);
  }catch(e){failures.push(lab.id+' '+e.message);}
 }
 assert(failures.length===0,failures.join('\n'));
 choose(0);saved[LABS[0].id]=fresh(LABS[0]);render();
 document.getElementById('command').value='chmod 600 /srv/app/secret.env';
 document.getElementById('shell').dispatchEvent(new Event('submit',{cancelable:true}));
 assert(state().fs['/srv/app/secret.env'].mode==='600','Terminal UI must change current server');
 choose(1);assert(state().fs['/srv/app/secret.env'].mode==='666','Tickets must have independent servers');
 document.getElementById('topic').value='SSH hardening';document.getElementById('topic').dispatchEvent(new Event('input'));
 assert(document.querySelectorAll('#lab-list button').length===4,'Topic filter should find four SSH labs');
 document.getElementById('topic').value='all';document.getElementById('search').value='X120';document.getElementById('search').dispatchEvent(new Event('input'));
 assert(document.querySelectorAll('#lab-list button').length===1,'ID search should find one lab');
 document.getElementById('search').value='no-such-ticket-value';document.getElementById('search').dispatchEvent(new Event('input'));
 assert(document.getElementById('matching').textContent==='0 labs shown','Empty search feedback');
 document.getElementById('search').value='';document.getElementById('scope').value='complete';renderList();
 assert(document.querySelectorAll('#lab-list button').length===119,'Completed filter must reflect independent progress');
 document.getElementById('scope').value='incomplete';renderList();
 assert(document.querySelectorAll('#lab-list button').length===1,'Incomplete filter must reflect reset ticket');
 document.getElementById('scope').value='all';renderList();
 let blocked=false;try{run('cat /missing')}catch{blocked=true}assert(blocked,'Missing path rejected');
 blocked=false;try{run('whoami; pwd')}catch{blocked=true}assert(blocked,'Unsupported shell chaining rejected');
 choose(56);saved[LABS[56].id]=fresh(LABS[56]);blocked=false;try{run('ufw enable')}catch{blocked=true}assert(blocked,'Firewall activation guard');
 choose(52);saved[LABS[52].id]=fresh(LABS[52]);blocked=false;try{run('systemctl reload ssh')}catch{blocked=true}assert(blocked,'SSH key-login guard');
 choose(104);saved[LABS[104].id]=fresh(LABS[104]);
 assert(run('curl http://127.0.0.1:8080/readyz').includes('502'),'Bad upstream produces 502');
 state().fs['/etc/nginx/app.conf'].data=LABS[104].edits['/etc/nginx/app.conf'];run('nginx -t');
 assert(run('curl http://127.0.0.1:8080/readyz').includes('502'),'Saved config remains inactive until reload');
 run('systemctl reload nginx');assert(run('curl http://127.0.0.1:8080/readyz').includes('200'),'Reload activates repaired proxy');
 persist();return {tickets:results.length,topics:new Set(LABS.map(l=>l.topic)).size};
})()''')
browser.call('Page.reload')
browser.js("new Promise(resolve=>{if(document.readyState==='complete')resolve(true);else addEventListener('load',()=>resolve(true),{once:true})})")
assert browser.js("saved['X001'].fs['/srv/app/secret.env'].mode")=='600'
browser.call('Emulation.setDeviceMetricsOverride',{'width':1440,'height':1000,'deviceScaleFactor':1,'mobile':False})
browser.js('choose(104)')
Path('/tmp/linux-extra-labs-desktop.png').write_bytes(base64.b64decode(browser.call('Page.captureScreenshot',{'format':'png'})['data']))
browser.call('Emulation.setDeviceMetricsOverride',{'width':390,'height':844,'deviceScaleFactor':1,'mobile':True})
assert browser.js('document.documentElement.scrollWidth<=innerWidth'),'Mobile bank overflows'
assert browser.js("getComputedStyle(document.getElementById('mobile-picker')).display")!='none'
Path('/tmp/linux-extra-labs-mobile.png').write_bytes(base64.b64decode(browser.call('Page.captureScreenshot',{'format':'png'})['data']))
for section in ['index.html','lecture-02/index.html','lecture-03/index.html']:
    navigate(DEST/section)
    assert browser.js("!!document.querySelector('a[href$=\"other/index.html\"]')"),'Missing Other navigation: '+section
    assert browser.js('document.documentElement.scrollWidth<=innerWidth'),'Mobile overflow: '+section
    if section!='index.html':assert browser.js("!!document.getElementById('shell')"),'Original lecture terminal lost'
assert not browser.errors,browser.errors
print(json.dumps({**report,'passed':['every solution starts incomplete and reaches completion','terminal UI','ticket state isolation','search and topic/completion filters','reload persistence','invalid command handling','SSH/firewall guards','saved versus active proxy config','mobile layouts','shared navigation','original lecture terminals','no browser exceptions']},indent=2))
browser.call('Browser.close')
