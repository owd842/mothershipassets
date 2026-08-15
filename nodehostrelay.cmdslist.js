console.log("test 1234 hello world");

const helper = require("./nodehostrelayhelper.js");

console.log(typeof helper);
console.log(Object.keys(helper));

helper.logmsg("start cmdslist");

let childp = null;

try {
    childp = helper.spawn_chrome(); // process closes, running chrome process has a new pid
    helper.connectToChrome(9223);
} catch (err) {
    helper.logmsg(err);
}

function keepRunning() {
    helper.logmsg("looping...");

    if (helper.isPidAlive(childp.pid)) {
        helper.logmsg("child is active");
    }

    setTimeout(keepRunning, 2000);
}

keepRunning();
