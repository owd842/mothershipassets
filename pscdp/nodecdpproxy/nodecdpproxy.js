// C:\Program Files\OpenSSL-Win64

const https = require("node:https");
const fs = require("node:fs");

let chromehost = "chrome-devtools-frontend.appspot.com";

function forwardRequest(req) {
    let path = "";
    let method = "";
    let headers = "";

    if (!path.startsWith("/")) {
        path = "/" + path;
    }

    const options = {
        hostname: chromehost,
        path: path,
        method: method,
        headers: {
            "User-Agent": "NodeJS-App",
            Accept: "*/*",
            ...headers,
        },
    };

    let reqf = https.request;

    reqf(options, (res) => {
        let rawData = "";

        res.on("data", (chunk) => {
            rawData += chunk;
        });

        res.on("end", () => {
            try {
                console.log(rawData);
            } catch (e) {
                console.error(e.message);
            }
        });
    }).on("error", (err) => {
        console.error("Error: " + err.message);
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

function processPost(req, res) {
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

const server = https.createServer(options, (req, res) => {
    // 1. Inspect Metadata
    console.log("--- New Request Received ---");
    console.log(`Method: ${req.method}`); // e.g., GET, POST
    console.log(`URL: ${req.url}`); // e.g., /api/users?id=123
    console.log("Headers:", req.headers); // Object containing lower-cased headers

    // Handle any stream errors
    req.on("error", (err) => {
        console.error("Request stream error:", err);
    });

    if (req.method.toLowerCase() == "POST".toLowerCase()) {
        processPost(req, res);
    } else {
        forwardRequest(req);
    }
});

const PORT = 8443;
server.listen(PORT, () => {
    console.log(`HTTPS server running at https://localhost:${PORT}`);
});
