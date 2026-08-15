// npm install ws
// npm install pubnub
console.log("--- start nodehostrelay.cmdlist.js ---");

let helper = null;
helper = require("./nodehostrelayhelper.js");


console.log(typeof helper);
console.log(Object.keys(helper));

helper.logmsg("start cmdslist");

let childp = null;

try {
    childp = helper.spawn_chrome(); // process closes, running chrome process has a new pid
    
    let ws = helper.connectToChrome(9223);

    ws.send(JSON.stringify(command));

} catch (err) {
    helper.logmsg(err);
}

function keepRunning() {
    helper.logmsg("looping...");

    setTimeout(keepRunning, 1000);
}

keepRunning();
