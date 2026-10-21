// 20261016-1619

const https = require("node:https");
const fs = require("node:fs");
const zlib = require("zlib");
const PubNub = require('pubnub');

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

const uuid = 'nodecdpproxy.js';

const pubnub = new PubNub({
    publishKey: 'pub-c-bd83b994-1964-4760-9bf2-142ceadf7f66',
    subscribeKey: 'sub-c-62ba6c3d-b786-4be3-a033-e472ab227774',
    userId: 'nodecdpproxy.js',
});

const channel_name = 'clientid_88992233_JS_client';

const REQUEST_CHANNEL = channel_name;
const RESPONSE_CHANNEL = channel_name;

pubnub.addListener({
  status: (statusEvent) => {
    switch (statusEvent.category) {
      case 'PNConnectedCategory':
        console.log('Successfully connected to PubNub!'); //
        break;
      case 'PNSubscriptionChangedCategory':
        console.log('Channel subscription list updated.'); //
        break;
      case 'PNDisconnectedCategory':
        console.log('Intentionally disconnected.'); //
        break;
      case 'PNDisconnectedUnexpectedlyCategory':
        console.log('Network connection lost! SDK will auto-retry.'); //
        break;
      case 'PNAccessDeniedCategory':
        console.error('PAM Authorization failed (invalid token/keys).'); //
        break;
    }
  }
});

pubnub.subscribe({ channels: [RESPONSE_CHANNEL] });

const subscription = pubnub.channel(RESPONSE_CHANNEL).subscription();

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

    console.log(`addChunk chunksize: ${chunksize} imagedata: ${imagedata.length} chunkindex: ${chunkindex} chunkcount: ${chunkcount} remainderlength: ${remainderlength}`);
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

subscription.onMessage = (messageEvent) => {

    let builtincmd = messageEvent.message;

    if ( ! builtincmd ) {
        throw new Error('builtincmd is null');
    }

    if ( builtincmd.destination != 'nodecdpproxy.js' ) {
        console.log('...received message from: '+builtincmd.source+' to: ' + builtincmd.destination + ' ts: '+builtincmd.ts + ' cmd: '+builtincmd.builtincmd);
        return;
    }

    let outgoingcmd = commandslist.find( cmd => builtincmd.cmdid == cmd.builtincmd.cmdid );

    if ( ! outgoingcmd.pbmsglist ) {
        outgoingcmd.pbmsglist = [];
    }

    outgoingcmd.pbmsglist.push(builtincmd);

    let result = builtincmd.result;

    let bodystr = null;

    let ischunked = builtincmd.result.chunksize >= 1;

    let chunkobj = null;

    if ( ! ischunked ) {
        console.log('requesturl: '+result.requesturl);
        console.log('statuscode: '+result.statuscode);
        
        bodystr = result.body;
    } else {

        chunkobj = result;

        let chunkcount = chunkobj.chunkcount;
        let chunkindex = chunkobj.chunkindex;

        if ( chunkindex == 0 ) {
            console.log('requesturl: '+chunkobj.requesturl);
            console.log('statuscode: '+chunkobj.statuscode);
            console.log('...received first chunk');
        }

        addChunk(outgoingcmd, chunkobj);

        if ( chunkindex < chunkcount - 1 ) {
            return;
        } else {
            console.log('...assembling chunks');
            bodystr = assembleChunks(outgoingcmd.chunks);
        }
    }

    let theaders = result.headers;
    let statuscode = result.statuscode;

    console.log('received headers');
    Object.entries(theaders).forEach(([header, value]) => {
        console.log(`<-- [${header}]=[${value}]`);
    });

    // TODO handle error gracefully
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

    // TODO ! charset will be an issue
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
        console.log('pass B');
    }

    /*
messageEvent.message.result
{
  ischunked: false,
  chunkobj: null,
  headers: {
    "access-control-allow-origin": "*",
    "x-cloud-trace-context": "0732c52e6cff9ccde3991c5451d323ff",
    Vary: "Accept-Encoding",
    Age: "1537",
    "Alt-Svc": "h3=\":443\"; ma=2592000,h3-29=\":443\"; ma=2592000",
    "Content-Length": "990",
    "Cache-Control": "public, max-age=604800",
    "Content-Type": "text/html",
    Date: "Sat, 17 Oct 2026 03:06:48 GMT",
    Server: "Google Frontend",
  },
  requesturl: "https://chrome-devtools-frontend.appspot.com/serve_rev/@d04cdb24d67b081f6cf80200ffc5233f44b61109/inspector.html?ws=localhost:9223/devtools/page/93E6F8C8006E3788B047A07C263005F3",
  body: "PCEtLQogKiBDb3B5cmlnaHQgMjAxOCBUaGUgQ2hyb21pdW0gQXV0aG9ycwogKiBVc2Ugb2YgdGhpcyBzb3VyY2UgY29kZSBpcyBnb3Zlcm5lZCBieSBhIEJTRC1zdHlsZSBsaWNlbnNlIHRoYXQgY2FuIGJlCiAqIGZvdW5kIGluIHRoZSBMSUNFTlNFIGZpbGUuCi0tPgo8IURPQ1RZUEUgaHRtbD4KPGh0bWwgbGFuZz0iZW4iPgo8bWV0YSBjaGFyc2V0PSJ1dGYtOCI+Cjx0aXRsZT5EZXZUb29sczwvdGl0bGU+CjxzdHlsZT4KICBAbWVkaWEgKHByZWZlcnMtY29sb3Itc2NoZW1lOiBkYXJrKSB7CiAgICBib2R5IHsKICAgICAgYmFja2dyb3VuZC1jb2xvcjogcmdiKDQxIDQyIDQ1KTsKICAgIH0KICB9Cjwvc3R5bGU+CjxtZXRhCiAgaHR0cC1lcXVpdj0iQ29udGVudC1TZWN1cml0eS1Qb2xpY3kiCiAgY29udGVudD0iZGVmYXVsdC1zcmMgJ3NlbGYnIGRldnRvb2xzOiBkYXRhOjsgc3R5bGUtc3JjICdzZWxmJyAndW5zYWZlLWlubGluZScgZGV2dG9vbHM6OyBvYmplY3Qtc3JjICdub25lJzsgc2NyaXB0LXNyYwogICdzZWxmJyBodHRwczovL2Nocm9tZS1kZXZ0b29scy1mcm9udGVuZC5hcHBzcG90LmNvbTsgaW1nLXNyYyAnc2VsZicgZGF0YTogYmxvYjo7IGZyYW1lLXNyYyAqIGRhdGE6OyBjb25uZWN0LXNyYyBkYXRhOiBodHRwczovL2Nocm9tZXV4cmVwb3J0Lmdvb2dsZWFwaXMuY29tICdzZWxmJyBkZXZ0b29sczogd3M6Ly8xMjcuMC4wLjE6KjsiPgo8bWV0YSBuYW1lPSJyZWZlcnJlciIgY29udGVudD0ibm8tcmVmZXJyZXIiPgo8c2NyaXB0IHR5cGU9Im1vZHVsZSIgc3JjPSIuL2VudHJ5cG9pbnRzL2luc3BlY3Rvci9pbnNwZWN0b3IuanMiPjwvc2NyaXB0Pgo8bGluayBocmVmPSIuL2FwcGxpY2F0aW9uX3Rva2Vucy5jc3MiIHJlbD0ic3R5bGVzaGVldCI+CjxsaW5rIGhyZWY9Ii4vZGVzaWduX3N5c3RlbV90b2tlbnMuY3NzIiByZWw9InN0eWxlc2hlZXQiPgo8Ym9keSBjbGFzcz0idW5kb2NrZWQiIGlkPSItYmxpbmstZGV2LXRvb2xzIj4K",
}       
    */
};

subscription.subscribe();

let cmdindex=0;
let commandslist = [];
let pbmessages = [];

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
            pubnub.removeListener(listener);
            messagePayload.istimeout = true;
            reject(new Error(`Timeout: No response received within ${timeoutMs}ms`));
        }, timeoutMs);

        const listener = {
            message: (event) => {

                if (event.channel === RESPONSE_CHANNEL && event.message.requestId === requestId) {
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
            console.log(`Message published successfully. Timetoken: ${publishResponse.timetoken}`);
        })
        .catch((error) => {
            clearTimeout(timeout);
            pubnub.removeListener(listener);
            messagePayload.error = error.message;
            reject(new Error(`Failed to publish message: ${error.message}`));
        });
    });
}

async function main() {
    try {
        console.log("🚀 Sending test message, waiting for response...");
        
        const testData = { text: "Hello World!", timestamp: Date.now() };
        const response = await sendMessageAndWait(testData, 10000);
        
        console.log("✅ Response received:", response);
    } catch (error) {
        console.error("❌ Error:", error.message);
    } finally {
        pubnub.unsubscribeAll();
        process.exit();
    }
}

let chromehost = "chrome-devtools-frontend.appspot.com";

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
        console.log("info: ignoring path");

        res.writeHead(204);
        res.end();

        return;
    }

    console.log(`making request to ${chromehost}${path}:${port}`);

    console.log('request headers');
    Object.entries(headers).forEach(([header, value]) => {
        console.log(`--> [${header}]=[${value}]`);
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
            state.isPending = false;
            state.isRejected = true;
            state.value = error;
            // throw error;
        }
    );

    let outgoingcmd = {
        builtincmd:pbreq,
        sendtask:sendtask,
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

const options = {
    key: fs.readFileSync(
        "C:\\MAIN\\WORKING\\hacking_WORK\\DevOps\\git_repo\\mothershipassets\\pscdp\\nodecdpproxy\\key.pem"
    ),
    cert: fs.readFileSync(
        "C:\\MAIN\\WORKING\\hacking_WORK\\DevOps\\git_repo\\mothershipassets\\pscdp\\nodecdpproxy\\cert.pem"
    ),
};

const server = https.createServer(options, (req, res) => {
    console.log("--- New Request Received ---");
    console.log(`Method: ${req.method}`);
    console.log(`Path: ${req.url}`);
    console.log("Headers:", req.headers);

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
