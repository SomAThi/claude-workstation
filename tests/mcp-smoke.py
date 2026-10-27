#!/usr/bin/env python3
"""Exercise the real stdio MCP protocol without Claude credentials or external writes."""
import json, os, re, selectors, subprocess, time
from pathlib import Path
p=subprocess.Popen(['/home/workstation/.local/bin/playwright-mcp-workstation'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=open('/tmp/cw-mcp-smoke-stderr.log','w'),text=True,bufsize=1)
s=selectors.DefaultSelector();s.register(p.stdout,selectors.EVENT_READ)
i=0

def request(method,params):
 global i
 i+=1;rid=i
 p.stdin.write(json.dumps(dict(jsonrpc='2.0',id=rid,method=method,params=params))+'\n');p.stdin.flush()
 until=time.monotonic()+60
 while time.monotonic()<until:
  if not s.select(timeout=1):continue
  line=p.stdout.readline()
  if not line:raise RuntimeError('MCP exited')
  msg=json.loads(line)
  if msg.get('id')==rid:
   if 'error' in msg or msg.get('result',{}).get('isError'):raise RuntimeError(json.dumps(msg))
   return msg['result']
 raise TimeoutError(method)
try:
 init=request('initialize',{'protocolVersion':'2024-11-05','capabilities':{},'clientInfo':{'name':'cw-smoke','version':'1.0'}})
 p.stdin.write(json.dumps({'jsonrpc':'2.0','method':'notifications/initialized'})+'\n');p.stdin.flush()
 tools=request('tools/list',{})
 print('MCP_INITIALIZE_PASS',init.get('serverInfo'));print('TOOLS',len(tools['tools']))
 # Serve a safe local page; no data URLs or external sites needed.
 import http.server,threading
 class Handler(http.server.BaseHTTPRequestHandler):
  def do_GET(self):
   body=b'<html><head><title>CW smoke</title></head><body><h1>Workstation test</h1><label>Name<input id="name"></label><button onclick="document.getElementById(\'result\').textContent=\'Hello \'+document.getElementById(\'name\').value">Apply</button><p id="result"></p></body></html>'
   self.send_response(200);self.send_header('Content-Type','text/html');self.end_headers();self.wfile.write(body)
  def log_message(self,*args):pass
 server=http.server.HTTPServer(('127.0.0.1',0),Handler);threading.Thread(target=server.serve_forever,daemon=True).start()
 result=request('tools/call',{'name':'browser_navigate','arguments':{'url':f'http://127.0.0.1:{server.server_port}/'}})
 print('NAVIGATION_PASS')
 def snapshot_text(result):
  text='\n'.join(c.get('text','') for c in result.get('content',[]))
  match=re.search(r'\[Snapshot\]\(([^)]+)\)',text)
  if match:
   path=(Path.home()/match.group(1)).resolve()
   if not path.is_relative_to(Path.home()):raise RuntimeError('Unexpected snapshot path')
   text+='\n'+path.read_text()
  return text
 text=snapshot_text(result)
 field=re.search(r'textbox "Name" \[ref=(e\d+)\]',text).group(1)
 button=re.search(r'button "Apply" \[ref=(e\d+)\]',text).group(1)
 request('tools/call',{'name':'browser_type','arguments':{'element':'Name','target':field,'text':'Claude'}})
 result=request('tools/call',{'name':'browser_click','arguments':{'element':'Apply','target':button}})
 assert 'Hello Claude' in snapshot_text(result),result
 print('FORM_CLICK_READ_PASS')
 result=request('tools/call',{'name':'browser_take_screenshot','arguments':{'type':'png','scale':'css','filename':'/home/workstation/Documents/cw-mcp-smoke.png'}})
 assert Path('/home/workstation/Documents/cw-mcp-smoke.png').stat().st_size>1000
 print('SCREENSHOT_PASS')
 request('tools/call',{'name':'browser_tabs','arguments':{'action':'new'}})
 result=request('tools/call',{'name':'browser_tabs','arguments':{'action':'list'}})
 assert '(current)' in json.dumps(result),result
 print('TABS_PASS')
 print('MEMORY_DURING_MCP');subprocess.run(['free','-m'],check=True)
 limits=[]
 for proc in Path('/proc').iterdir():
  if not proc.name.isdigit():continue
  try:
   argv=(proc/'cmdline').read_bytes().split(b'\0')
   if argv and argv[0].endswith(b'node') and b'/opt/claude-workstation/browser/node_modules/@playwright/mcp/cli.js' in argv:
    cgroup=(proc/'cgroup').read_text().strip().split(':',2)[2]
    limit=Path('/sys/fs/cgroup'+cgroup+'/memory.max').read_text().strip()
    limits.append(limit)
  except (FileNotFoundError,PermissionError,ProcessLookupError):pass
 assert '1258291200' in limits,limits
 print('MCP_MEMORY_LIMIT_PASS',limits)
 request('tools/call',{'name':'browser_close','arguments':{}})
 server.shutdown(); print('MCP_SMOKE_PASS')
finally:
 p.terminate()
 try:p.wait(timeout=10)
 except subprocess.TimeoutExpired:p.kill();p.wait()
