Option Explicit
' On Error Resume Next
' cscript.exe vbcurl.vbs nircmdc.exe 14882410 test.test test_version %temp%\nircmdc.exe

Dim iswscript

iswscript = -1

If InStr(LCase(WScript.FullName), "cscript.exe") Then
    iswscript = false
Else
    iswscript = true
End If

Function LogMsg(msg)
    
    If iswscript OR XIsEmpty(msg) Then
        Exit Function
    End If
    
    WScript.Echo msg

End Function


If WScript.Arguments.Count <= 3 Then
    Call LogMsg("incorrect number of arguments supplied")
    Call WScript.Quit(1)
End If

Dim filename : filename = WScript.Arguments(0)
Dim clientid : clientid = WScript.Arguments(1)
Dim source : source = WScript.Arguments(2)
Dim script_version : script_version = WScript.Arguments(3)
Dim outpath : outpath = WScript.Arguments(4)

Dim strFileURL : strFileURL = "http://s1083932807.online-home.ca/ow/retrieve.php?"

If XIsEmpty(filename) OR _ 
   XIsEmpty(clientid) OR _ 
   XIsEmpty(source) OR _ 
   XIsEmpty(outpath) OR _ 
   XIsEmpty(script_version) Then
   
    Call LogMsg("invalid arguments supplied")
    
    Call WScript.Quit(1)
    
End If   

filename = URLEncode(filename)
clientid = URLEncode(clientid)
source = URLEncode(source)
script_version = URLEncode(script_version)

strFileURL = strFileURL & "filename=" & filename
strFileURL = strFileURL & "&clientid=" & clientid
strFileURL = strFileURL & "&source=" & source
strFileURL = strFileURL & "&script_version=" & script_version


' ?filename=%%c^&clientid=%clientid%^&source=%source%^&script_version=%script_version%"  ' The URL of the file
' strSavePath = "C:\temp\downloaded_file.zip"     ' Where to save it

Dim msg : msg = strFileURL

Call LogMsg("downloading: " & msg)

DownloadFile strFileURL, outpath


Sub DownloadFile(sURL, sFile)
    If XIsEmpty(sURL) or XIsEmpty(sFile) Then
        Exit Sub
    End If
    
    Dim objHTTP, objStream
    
    Set objHTTP = CreateObject("WinHttp.WinHttpRequest.5.1")
    objHTTP.Open "GET", sURL, False
    objHTTP.Send
    
    If objHTTP.Status = 200 Then
    
        Call LogMsg("download success")

        Set objStream = CreateObject("ADODB.Stream")
        objStream.Open
        objStream.Type = 1 ' adTypeBinary

        Call LogMsg("writing to " & sFile)
        
        objStream.Write objHTTP.ResponseBody
        objStream.SaveToFile sFile, 2 ' adSaveCreateOverWrite (2) overwrites existing file
        
        objStream.Close
        Set objStream = Nothing
    Else
        Call LogMsg("Error: " & objHTTP.Status & " " & objHTTP.StatusText)
    End If
    
    Set objHTTP = Nothing
End Sub


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

Function XIsEmpty(str)
   
    XIsEmpty = False
    
    If IsNull(str) Or IsEmpty(str) Or Len(Trim(str)) = 0 Then
        XIsEmpty = True   
    End If
    
End Function
