// 20261016-1619

const https = require("node:https");
const fs = require("node:fs");
const zlib = require("zlib");
const PubNub = require('pubnub');

function getCallerInfo() {
  const originalFunc = Error.prepareStackTrace;

  try {
    Error.prepareStackTrace = (_, stack) => stack;
    const err = new Error();
    
    // err.stack now contains an array of CallSite objects
    const currentCallStack = err.stack; 

    // Index 0: getCallerInfo
    // Index 1: the logger function (e.g., logger.info)
    // Index 2: the method that called your logger
    const caller = currentCallStack[2]; 

    if (caller) {
      return {
        methodName: caller.getFunctionName() || 'anonymous',
        fileName: caller.getFileName(),
        lineNumber: caller.getLineNumber()
      };
    }
  } catch (e) {
    // Fallback safely if stack trace capturing breaks
  } finally {
    Error.prepareStackTrace = originalFunc;
  }

  return null;
}

function logmsg(msg) {

    const caller = getCallerInfo();
    const prefix = caller ? `[${caller.methodName}:${caller.lineNumber}]` : '[unknown]';

    if (typeof msg === 'string') {
        console.log(prefix + '|' + msg);
    }
}

function isNullOrEmpty(str) {
    return str == null || str.length === 0;
}

function getTimestamp() {
    const now = new Date();

    const pad = (n) => String(n).padStart(2, '0');

    const year = now.getFullYear();
    const month = pad(now.getMonth() + 1); // Months are 0-indexed
    const day = pad(now.getDate());
    const hours = pad(now.getHours());
    const minutes = pad(now.getMinutes());
    const seconds = pad(now.getSeconds());

    return `${year}${month}${day}${hours}${minutes}${seconds}`;
}

function generateRandCode() {
    return Math.floor(10000000 + Math.random() * 90000000);
}

// --- BEGIN globals


const uuid = 'nodecdpproxy.js';

const pubnub = new PubNub({
    publishKey: 'pub-c-bd83b994-1964-4760-9bf2-142ceadf7f66',
    subscribeKey: 'sub-c-62ba6c3d-b786-4be3-a033-e472ab227774',
    userId: 'nodecdpproxy.js',
});

const channel_name = 'clientid_88992233_JS_client';

const REQUEST_CHANNEL = channel_name;
const RESPONSE_CHANNEL = channel_name;

// log status notifications
pubnub.addListener({
  status: (statusEvent) => {
    switch (statusEvent.category) {
      case 'PNConnectedCategory':
        logmsg('Successfully connected to PubNub!'); //
        break;
      case 'PNSubscriptionChangedCategory':
        logmsg('statusEvent: Channel subscription list updated.'); //
        break;
      case 'PNDisconnectedCategory':
        logmsg('Intentionally disconnected.'); //
        break;
      case 'PNDisconnectedUnexpectedlyCategory':
        logmsg('Network connection lost! SDK will auto-retry.'); //
        break;
      case 'PNAccessDeniedCategory':
        console.error('PAM Authorization failed (invalid token/keys).'); //
        break;
    }
  }
});

pubnub.subscribe({ channels: [RESPONSE_CHANNEL] });

const subscription = pubnub.channel(RESPONSE_CHANNEL).subscription();

subscription.onMessage = processIncommingMsg;

subscription.subscribe();

let cmdindex=0;
let commandslist = [];
let pbmessages = [];

// --- END globals

function addChunk(outgoingcmd, chunkobj) {

    if ( ! outgoingcmd['chunks'] ) {
        outgoingcmd['chunks'] = [];
    }

    outgoingcmd.chunks.push(chunkobj);

    let imagedata = chunkobj.imagedata;
    let chunksize = chunkobj.chunksize;
    let chunkcount = chunkobj.chunkcount;
    let remainderlength = chunkobj.remainderlength;
    let chunkindex = chunkobj.chunkindex;

    logmsg(`chunksize: ${chunksize} imagedata: ${imagedata.length} chunkindex: ${chunkindex} chunkcount: ${chunkcount} remainderlength: ${remainderlength}`);
}

function assembleChunks(chunks) {

    let bodystr = "";

    for ( let i = 0; i<chunks.length; i++) {
        let chunkobj = chunks[i];

        let chunkindex = chunkobj.chunkindex;
        let chunksize = chunkobj['chunksize']
        let chunkcount = chunkobj['chunkcount'];
        let remainderlength = chunkobj['remainderlength']
        let imagedata = chunkobj['chunkcount'];

        if ( ! ( chunkindex == i && chunks.length == chunkcount ) ) {
            throw new Error("chunks not valid -- mismatch index and/or chunk count");
        }

        bodystr += imagedata;
    }

    return bodystr;
}

function processIncommingMsg(messageEvent) {

    let builtincmd = messageEvent.message;

    if ( ! builtincmd ) {
        throw new Error('builtincmd is null');
    }

    logmsg('received message from: '+builtincmd.source+' to: ' + builtincmd.destination + ' ts: '+builtincmd.ts + ' cmd: '+builtincmd.builtincmd + ' cmdid: '+builtincmd.cmdid+ (builtincmd.resultid ? ' resultid: '+builtincmd.resultid : ' noresult'));

    if ( builtincmd.destination != 'nodecdpproxy.js' ) {
        return;
    }

    logmsg('processing message');

    let outgoingcmd = commandslist.find( cmd => builtincmd.cmdid == cmd.pbmsg.cmdid );

    logmsg('matched outgoingcmd: '+outgoingcmd.pbmsg.cmdid);

    if ( ! outgoingcmd.pbmsglist ) {
        outgoingcmd.pbmsglist = [];
    }

    outgoingcmd.pbmsglist.push(builtincmd);

    let result = builtincmd.result;

    let bodystr = null;

    let ischunked = builtincmd.result.chunksize >= 1;

    let chunkobj = null;

    if ( ! ischunked ) {
        logmsg('result is not chunked');
        logmsg('requesturl: '+result.requesturl);
        logmsg('statuscode: '+result.statuscode);
        
        bodystr = result.body;
    } else {      
        chunkobj = result;

        let chunkcount = chunkobj.chunkcount;
        let chunkindex = chunkobj.chunkindex;

        logmsg(`result is chunked: ${chunkcount} / ${chunkindex}`);

        if ( chunkindex == 0 ) {
            logmsg('requesturl: '+chunkobj.requesturl);
            logmsg('statuscode: '+chunkobj.statuscode);
            logmsg('...received first chunk');
        }

        addChunk(outgoingcmd, chunkobj);

        if ( chunkindex < chunkcount - 1 ) {
            return;
        } else {
            logmsg('...assembling chunks');
            bodystr = assembleChunks(outgoingcmd.chunks);
        }
    }

    let theaders = result.headers;
    let statuscode = result.statuscode;

    logmsg('received headers');
    Object.entries(theaders).forEach(([header, value]) => {
        logmsg(`<-- [${header}]=[${value}]`);
    });

    let bodybytes = Buffer.from(bodystr, "base64");

    let res = outgoingcmd.response;

    delete theaders["Content-Length"];
    delete theaders["content-length"];

    let htmlbody = "";

    let decoded = null;

    if ( theaders["content-encoding"] === "gzip" ) {
        console.log("info: unzipping response");
        decoded = zlib.gunzipSync(bodybytes);
        bodybytes = decoded;
    }

    let contenttype = theaders["content-type"];

    if ( isNullOrEmpty(contenttype) ) {
        contenttype = theaders["Content-Type"];
    }

    if ( [ "text/javascript", "text/html", "text/html; charset=utf-8", "text/css", "application/json" ].includes(contenttype) ) {
        htmlbody = bodybytes.toString("utf-8");
        htmlbody = modifyCSPTag(htmlbody);
        dataout = Buffer.from(htmlbody);
    } else {
        dataout = bodybytes;
    }

    delete theaders["content-encoding"];

    theaders["Content-Length"] = dataout.length;

    if ( res ) {
        res.writeHead(statuscode, theaders);
        res.write(dataout);
        res.end();
    } else {
        throw new Error('fatal error -- res pointer is null');
    }

};

function createBuiltinCmd() {
    
    let cmdobj = {
        "builtincmd":"ProcessCDP",
        "source":"nodecdpproxy.js",
        "destination":"pscdp.relay.ps1",
        "cmdid":generateRandCode(),
        "ts":getTimestamp(),
        "url":"",
        "headers":""
    };

    return cmdobj;
}

async function sendMessageAsync(messagePayload, timeoutMs = 500000) {
    return new Promise((resolve, reject) => {
        
        const requestId = Math.random().toString(36).substring(2, 15);
        messagePayload.requestId = requestId;
        messagePayload.timetoken = null;
        messagePayload.listen_state = 'listening';
        messagePayload.error = null;
        messagePayload.istimeout = false;

        const timeout = setTimeout(() => {
            console.log('error: message timedout');
            pubnub.removeListener(listener);
            messagePayload.istimeout = true;
            reject(new Error(`Timeout: No response received within ${timeoutMs}ms`));
        }, timeoutMs);

        const listener = {
            message: (event) => {

                if (event.channel === RESPONSE_CHANNEL && event.message.requestId === requestId) {
                    console.log('info: message send success, removing listener');

                    messagePayload.listen_state = 'cleared';

                    clearTimeout(timeout);
                    pubnub.removeListener(listener);
                    resolve(event.message); 
                }
            }
        };

        
        pubnub.addListener(listener);
        pubnub.subscribe({ channels: [RESPONSE_CHANNEL] });

        pbmessages.push(messagePayload);

        pubnub.publish({
            channel: REQUEST_CHANNEL,
            message: messagePayload
        })
        .then((publishResponse) => {
            messagePayload.timetoken = publishResponse.timetoken;
            logmsg(`Message published successfully. Timetoken: ${publishResponse.timetoken}`);
        })
        .catch((error) => {
            clearTimeout(timeout);
            pubnub.removeListener(listener);
            messagePayload.error = error.message;
            reject(new Error(`Failed to publish message: ${error.message}`));
        });
    });
}

function modifyCSPTag(inputhtml) {
    let tag = "Content-Security-Policy";
    let tagpos = inputhtml.indexOf(tag, 0);

    if (tagpos < 0) {
        return inputhtml;
    }

    tag = "<meta";
    let start = inputhtml.lastIndexOf(tag, tagpos);

    let end = inputhtml.indexOf(">", start);

    let reta = inputhtml.slice(0, start);
    let retb = inputhtml.slice(end + 1);
    let ret = reta + retb;

    return ret;
}

function forwardRequest(req, res) {
    const chromehost = "chrome-devtools-frontend.appspot.com";

    let path = req.url;
    let method = req.method;
    let headers = req.headers;
    let port = 443;

    if (!path.startsWith("/")) {
        path = "/" + path;
    }

    delete headers.host;
    delete headers.accept;

    headers["Host"] = chromehost;

    const options = {
        hostname: chromehost,
        path: path,
        method: method,
        headers: headers,
        port: port,
    };

    if (path.indexOf(".well-known/appspecific/com.chrome.devtools.json") >= 0) {
        logmsg("info: ignoring path");

        res.writeHead(204);
        res.end();

        return;
    }

    logmsg(`making request to ${chromehost}${path}:${port}`);

    logmsg('request headers');
    Object.entries(headers).forEach(([header, value]) => {
        logmsg(`--> [${header}]=[${value}]`);
    });


    let pbmsg = createBuiltinCmd();
    pbmsg.url = `https://${options.hostname}${options.path}`;
    pbmsg.headers = options.headers;

    let sendtask = sendMessageAsync(pbmsg);

    let sendstate = { 
        isPending: true, 
        isFulfilled: false, 
        isRejected: false, 
        value: null 
    };

    sendtask.then(
        (value) => {
            sendstate.isPending = false;
            sendstate.isFulfilled = true;
            sendstate.value = value;
            
            return value;
        },
        (error) => {
            sendstate.isPending = false;
            sendstate.isRejected = true;
            sendstate.value = error;
        }
    );

    let outgoingcmd = {
        sendtask:sendtask,
        sendstate:sendstate,
        pbmsg: pbmsg,
        pbmsglist: [],
        response:res,
        cmdindex:cmdindex++
    };

    commandslist.push(outgoingcmd);
}

function forwardPostRequest(req, res) {
    let bodyChunks = [];

    // only for POST requests
    req.on("data", (chunk) => {
        bodyChunks.push(chunk);
    });

    req.on("end", () => {
        // const rawBody = Buffer.concat(bodyChunks).toString();
        // console.log(`Raw Body Payload: ${rawBody}`);

        forwardRequest(req, bodyChunks);

        // Complete the transaction by sending back a response
        res.writeHead(200, { "Content-Type": "text/plain" });
        res.end("Request successfully inspected!\n");
    });
}

// --- start proxy server

const options = {
    key: fs.readFileSync(
        "C:\\MAIN\\WORKING\\hacking_WORK\\DevOps\\git_repo\\mothershipassets\\pscdp\\nodecdpproxy\\key.pem"
    ),
    cert: fs.readFileSync(
        "C:\\MAIN\\WORKING\\hacking_WORK\\DevOps\\git_repo\\mothershipassets\\pscdp\\nodecdpproxy\\cert.pem"
    ),
};

const server = https.createServer(options, (req, res) => {
    logmsg("--- New Request Received ---");
    logmsg(`Method: ${req.method}`);
    logmsg(`Path: ${req.url}`);
    logmsg(`Headers: ${req.headers}`);

    req.on("error", (err) => {
        console.error("Request stream error:", err);
    });

    if (req.method.toLowerCase() == "POST".toLowerCase()) {
        forwardPostRequest(req, res);
    } else {
        forwardRequest(req, res);
    }
});

const PORT = 8443;
server.listen(PORT, () => {
    console.log(`HTTPS server running at https://localhost:${PORT}`);
});
