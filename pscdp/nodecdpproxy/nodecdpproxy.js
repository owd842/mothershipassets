// C:\Program Files\OpenSSL-Win64

const https = require("node:https");
const fs = require("node:fs");
const zlib = require("zlib");

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
