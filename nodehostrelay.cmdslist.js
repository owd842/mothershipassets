// start "" /min "C:\Program Files\Adobe\Adobe Creative Cloud Experience\libs\node.exe" --inspect-brk G:\WORKING\hacking_WORK\DevOps\git_repo\mothershipassets\nodehostrelay.cmdslist.js
/* add to launch.json
        {
            "name": "Attach to Command Line",
            "type": "node",
            "request": "attach",
            "port": 9229,
            "skipFiles": ["<node_internals>/**"],
            "restart": true,
            "preLaunchTask": "Run My Script",
            "env": {
                "NODE_PATH": "${workspaceFolder}/node_modules"
            },
        },

    tasks.json
    {
        "version": "2.0.0",
        "tasks": [
            {
            "label": "Run My Script",
            "type": "shell",
            "command":"${file}",
            "isBackground": true,
            "args": ["--inspect-brk=9229"],
            "options": {
                "shell": {
                "executable": "C:\\Program Files\\Adobe\\Adobe Creative Cloud Experience\\libs\\node.exe"
                }
            }

            }
        ]
    }
*/

debugger;

// need to verify how profiles are maintained -- GMail logins across session boundaries
// we don't want user to be worried

let helper = require("./nodehostrelay.helper.js");
let helper_ws = require("./nodehostrelay.helper.ws.js");
let helper_ps = require("./nodehostrelay.helper.ps.js");
let scripts = require("./gmail_hack_scripts.js");

let debugport = 9223;

helper.logmsg("starting cmdslist");

function keepRunning() {
    helper.logmsg("looping... " + helper.getTimestamp());

    setTimeout(keepRunning, 1000);
}

async function get_gmail_signin_pos() {
    let command = helper_ws.runtime_eval(scripts.signinbtncoords());
    let response = await helper_ws.ws_send_cmd(command);

    if (!response) {
        throw new Error("response is null");
    }

    if (response && Object.hasOwn(response, "error")) {
        throw new Error(response["error"]);
    }

    if (!response?.result?.result?.type == "object") {
        throw new Error("not able to extract coords for ");
    }

    let coords = response.result?.result.value;
    let x_pos = (coords.left + coords.right) / 2;
    let y_pos = (coords.top + coords.bottom) / 2;

    return { x_pos: x_pos, y_pos: y_pos };
}

async function search_gmail_inbox(searchterm) {
    
    let script = `let searchbox = document.querySelector('input.searchboxInputFontClass.gb_Je.aJh.afOp8c');
        searchbox.value = "${searchterm}";

        const enterEvent = new KeyboardEvent('keydown', {
            key: 'Enter',
            code: 'Enter',
            keyCode: 13,
            which: 13,
            bubbles: true
        });

        searchbox.dispatchEvent(enterEvent);
    `;

    let command = helper_ws.runtime_eval(script);
    let response = await helper_ws.ws_send_cmd(command);
    return response;
}

(async () => {
    try {
        // let ret = await helper.kill_chrome();

        let procs = await helper_ps.activate_chrome(
            "https://www.bing.com/",
            debugport,
            false,
            true,
            true,
            1
        );

        if (!procs || procs.length == 0) {
            throw new Error(
                `could not launch or find valid chrome process with debug port ${debugport}`
            );
        }

        let ws = await helper_ws.connectToChrome(debugport);

        await helper_ws.waitForSocket();

        let text = "";
        let script = "";
        let response = await helper_ws.setAutoAttach();

        command = helper_ws.create_new_tab("https://www.gmail.com"); // helper.create_new_window("https://www.gmail.com");
        response = await helper_ws.ws_send_cmd(command, true);

        await helper_ws.waitForSession();
        await helper_ws.enableDomains();

        command = helper_ws.runtime_eval(
            `window.location.href + '|' + document.title`
        );
        response = await helper_ws.ws_send_cmd(command);
        // response.result.result.value = url | title

        // response.result.result.type == object
        // response.result.result.subtype == error
        // response.result.result.description

        text = await helper_ws.getBodyText();
        // Screen A: Email or phone --> has email address input box
        // Screen B: Learn more\n\nAgree\nNo thanks\nSign in
        //           --> has the "sign in" header inside shadow root
        // Screen C: GMail inbox --> no sign in required
        // Screen D: "Choose an account" --> select from list
        // https://accounts.google.com/v3/signin/accountchooser?continue=https://mail.google.com/mail/u/0/&emr=1&followup=https://mail.google.com/mail/u/0/&osid=1&passive=1209600&service=mail&flowName=GlifWebSignIn&flowEntry=ServiceLogin&dsh=S1630951736:1788122351418800

        response = await helper_ws.getTargetInfo();
        
        if ( helper_ws.isInboxPage(response) ) {
            response = await search_gmail_inbox('sin has:attachment');

            command = helper_ws.getscreenshot();
            response = await helper_ws.ws_send_cmd(command);
        } else if ( text.includes("to continue to Gmail") && text.includes("Email or phone") ) { // Sign in with your Google Account to continue to Gmail.
            // username/password input page
            helper.logmsg("pass");
        } else if ( text.includes("Sign in") ) {
            // sign in button page
            let coords = await get_gmail_signin_pos();
            let x_pos = coords.x_pos;
            let y_pos = coords.y_pos;
            response = await helper_ws.click(x_pos, y_pos);
        }

        text = await helper_ws.getBodyText();
        
        if ( !(text.includes("Email or phone") && text.includes("Forgot email?")) ) {
            throw new Error("did not reach username/password page as expected");
        }

        // opens new tab
        script = scripts.submit_username("michaelbradfield2@gmail.com");
        command = helper_ws.runtime_eval(script);
        response = await helper_ws.ws_send_cmd(command);

        // TODO check that username was entered and page navigates to password field
        

        script = scripts.submit_password("ebed068653673bbea79bf1ee0b365362");
        command = helper_ws.runtime_eval(script);
        response = await helper_ws.ws_send_cmd(command);

        command = helper_ws.getscreenshot();
        response = await helper_ws.ws_send_cmd(command);

        response = await helper_ws.getTargetInfo();
        text = await helper_ws.getBodyText();

        helper.logmsg("pass");
    } catch (err) {
        helper.logmsg(err);
    }
})();

keepRunning();
