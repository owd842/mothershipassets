Option Explicit
' On Error Resume Next

' executes ps script, sends all stdout to log file path

' cscript RunHiddenPSx.vbs <ps script path> <runner log file path> <key/value pair>
' logPath = tempPath & "\" & "RunHiddenPSx_" & timestamp & ".log"

' start "" /min /b cscript //B //nologo RunHiddenPSx.vbs pc_monitoring.ps1 runner.log
' --> owdkeyboardlog.txt

Function GetKeyValuePair(ByVal inputStr, ByVal delim, ByRef kkey, ByRef value)

    Dim delimiterPos, part1, part2
    
    GetKeyValuePair = False
    
    delimiterPos = InStr(1, inputStr, delim)

    If delimiterPos > 0 Then
        kkey = Mid(inputStr, 1, delimiterPos - 1) 
        value = Mid(inputStr, delimiterPos + 1)   

        GetKeyValuePair = True
    End If

End Function

Function IsNullOrEmpty(str)
    If IsNull(str) Then
        IsNullOrEmpty = True
    ElseIf IsEmpty(str) Then
        IsNullOrEmpty = True
    ElseIf Len(Trim(str)) = 0 Then
        IsNullOrEmpty = True
    Else
        IsNullOrEmpty = False
    End If
End Function


Function GetFormattedTimestamp()
    Dim Yr, Mo, Da, Ho, Mi, Se, TimeStamp
    Dim CurrentDateTime
    
    ' Get the current date and time
    CurrentDateTime = Now()
    
    ' Extract date and time parts
    Yr = Year(CurrentDateTime)
    Mo = Month(CurrentDateTime)
    Da = Day(CurrentDateTime)
    Ho = Hour(CurrentDateTime)
    Mi = Minute(CurrentDateTime)
    Se = Second(CurrentDateTime)
    
    ' Build the timestamp string, adding leading zeros if needed
    TimeStamp = Yr & _
        Right("00" & Mo, 2) & _
        Right("00" & Da, 2) & _
        Right("00" & Ho, 2) & _
        Right("00" & Mi, 2) & _
        Right("00" & Se, 2)
        
    GetFormattedTimestamp = TimeStamp
End Function

Dim timestamp : timestamp = GetFormattedTimestamp()

Dim objShell : Set objShell = CreateObject("WScript.Shell")
Dim fso : Set fso = CreateObject("Scripting.FileSystemObject")
Dim tempPath : tempPath = objShell.ExpandEnvironmentStrings("%TEMP%")

Dim filePath 
Dim logPath : logPath = tempPath & "\" & "RunHiddenPSx_" & timestamp & ".log"

If WScript.Arguments.Count > 0 Then
    filePath = WScript.Arguments.Item(0)
Else
    WScript.Quit 1
End If

If WScript.Arguments.Count > 1 Then
    logPath = WScript.Arguments.Item(1)
End If

Dim keyvaluepairStr : keyvaluepairStr = ""
Dim kkey : kkey = "" : Dim value : value = ""
Dim iskvp : iskvp = False

If WScript.Arguments.Count > 2 Then
    keyvaluepairStr = WScript.Arguments.Item(2)    
End If

If Not IsNullOrEmpty(keyvaluepairStr) Then
    iskvp = GetKeyValuePair(keyvaluepairStr, "=", kkey, value)
End If

Dim strScriptHost : strScriptHost = LCase(WScript.FullName)
Dim iscscript : iscscript = False

If Right(strScriptHost, 11) = "cscript.exe" Then
    iscscript = True
End If


Dim logfile : Set logfile = fso.CreateTextFile(logPath, True)

Function LogMsg(msg)
    If Not logfile Is Nothing Then
        logfile.WriteLine msg
    End If
    
    If iscscript Then
        WScript.Echo msg
    End IF
    
End Function


If Not fso.FileExists(filePath) Then
    LogMsg "path does not exist [" & filePath & "]"
    WScript.Quit 1
End If

' WindowStyle Hidden
Dim command : command = "powershell.exe -WindowStyle Minimized -NoProfile -ExecutionPolicy Bypass -File " & filePath 

If iskvp Then
    command = command & " -" & kkey & "=" & value
End IF

LogMsg "filePath: " & filePath
LogMsg "command: " & command

Dim objExec: Set objExec = objShell.Exec(command)

Do While objExec.Status = 0
    WScript.Sleep 100
Loop

Dim strOutput : strOutput = objExec.StdOut.ReadAll

LogMsg strOutput

If Err.Number <> 0 Then
    LogMsg "Error # " & CStr(Err.Number) & vbCrLf & "Description: " & Err.Description & vbCrLf & "Source: " & Err.Source, vbCritical, "VBScript Error"    
    Err.Clear
End If


logfile.Close

Set logfile = Nothing
Set objShell = Nothing
Set fso = Nothing
