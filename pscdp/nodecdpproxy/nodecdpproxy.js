const https = require("node:https");
const fs = require("node:fs");
const zlib = require("zlib");
const PubNub = require('pubnub');

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

function sendMessageAndWait(messagePayload, timeoutMs = 5000) {
    return new Promise((resolve, reject) => {
        
        const requestId = Math.random().toString(36).substring(2, 15);
        messagePayload.requestId = requestId;
        
        const timeout = setTimeout(() => {
            pubnub.removeListener(listener);
            reject(new Error(`Timeout: No response received within ${timeoutMs}ms`));
        }, timeoutMs);

        const listener = {
            message: (event) => {
                // message was sent successfully
                if (event.channel === RESPONSE_CHANNEL && event.message.requestId === requestId) {
                    clearTimeout(timeout);
                    pubnub.removeListener(listener); // Clean up listener
                    resolve(event.message); // TODO remove and move to handlerm resolve when pscdp.relay.ps1 sends response
                }

                // TODO handle response from pscdp.relay.ps1
                // handle chunks -- reassemble
            },

            status: function (event) {
                if ( event.category === "PNConnectedCategory" ) {

                    console.log("Connected to PubNub!");

                } else if ( event.category === "PNNetworkIssuesCategory" ) {

                    console.log("Connection lost. Attempting to reconnect...");

                } else if ( event.category === "PNReconnectedCategory" ) {

                    console.log("Reconnected to PubNub!");

                }
            }

        };

        pubnub.addListener(listener);
        pubnub.subscribe({ channels: [RESPONSE_CHANNEL] });

        pubnub.publish({
            channel: REQUEST_CHANNEL,
            message: messagePayload
        })
        .then((publishResponse) => {
            console.log(`✨ Message published successfully. Timetoken: ${publishResponse.timetoken}`);
        })
        .catch((error) => {
            clearTimeout(timeout);
            pubnub.removeListener(listener);
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

    console.log(`making request to ${chromehost}${path}:${port}`);

    if (path.indexOf(".well-known/appspecific/com.chrome.devtools.json") >= 0) {
        console.log("info: ignoring path");

        res.writeHead(204);
        res.end();

        return;
    }

    Object.entries(headers).forEach(([header, value]) => {
        console.log(`--> [${header}]=[${value}]`);
    });

    let chunks = [];

    // TODO replace with pubnub message and await response
sendMessageAndWait

    /*
    let preq = https.request(options, (pres) => {
        console.log(`--- response: ${pres.statusCode}`);

        Object.entries(pres.headers).forEach(([header, value]) => {
            console.log(`--> [${header}]=[${value}]`);
        });

        if (pres.statusCode >= 400) {
            console.log("warn: 4xx received");
            //let theaders = { ...pres.headers };
            //res.writeHead(pres.statusCode, theaders);
            //res.end();
        }

        pres.on("data", (chunk) => {
            chunks.push(chunk);
        });

        pres.on("end", () => {
            let dataout = Buffer.concat(chunks);

            let theaders = { ...pres.headers };

            let contlena = theaders["Content-Length"];
            let contlenb = theaders["content-length"];

            delete theaders["Content-Length"];
            delete theaders["content-length"];

            let htmlbody = "";

            if (theaders["content-type"] == "text/html") {
                if (pres.headers["content-encoding"] === "gzip") {
                    console.log("info: unzipping response");
                    let decoded = zlib.gunzipSync(dataout);
                    htmlbody = decoded.toString("utf-8");
                } else {
                    htmlbody = dataout.toString();
                }

                delete theaders["content-encoding"];

                htmlbody = modifyCSPTag(htmlbody);
                dataout = Buffer.from(htmlbody);
            } else {
                console.log("info: content type is not text/html");
            }

            theaders["Content-Length"] = dataout.length;

            Object.entries(theaders).forEach(([header, value]) => {
                console.log(`--> [${header}]=[${value}]`);
            });

            res.writeHead(pres.statusCode, theaders);
            res.write(dataout);
            res.end();
        });
    });

    preq.on("error", (err) => {
        console.error("Error: " + err.message);
    });

    preq.end();
    */
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
