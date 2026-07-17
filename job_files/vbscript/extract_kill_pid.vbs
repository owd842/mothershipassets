Option Explicit

On Error Resume Next

Dim hostName : hostName = LCase(WScript.FullName)
Dim logtoconsole : logtoconsole = False

If InStr(hostName, "cscript.exe") > 0 Then
    logtoconsole = true
    ' WScript.Echo "This script is running via CScript.exe (command-line)."
ElseIf InStr(hostName, "wscript.exe") > 0 Then
    ' WScript.Echo "This script is running via WScript.exe (windowed)."
Else
    ' WScript.Echo "Could not determine the script host."
End If

Function LogMsg(msg) 
    if ( logtoconsole ) Then
        WScript.Echo msg
    end if
End Function

Const ForReading = 1
Dim objTextFile, strLine, filePath

Dim objArgs, argCount
Set objArgs = Wscript.Arguments

argCount = objArgs.Count

If ( argCount < 1 ) Then
    WScript.Quit 1
End If

filePath = WScript.Arguments.Item(0)

Dim objFSO
Set objFSO = CreateObject("Scripting.FileSystemObject")

If Not objFSO.FileExists(filePath) Then
    WScript.Quit 1
End If

Set objTextFile = objFSO.OpenTextFile(filePath, ForReading)

Dim oShell : Set oShell = WScript.CreateObject("WScript.Shell")

Do Until objTextFile.AtEndOfStream
    strLine = objTextFile.ReadLine
    
    Dim arrValues
    Dim strval
    Dim spacedString
    
    arrValues = Split(strLine, ",")

    strval = arrValues(2)

    strval = Replace(strval , vbCrLf, "")
    strval = Replace(strval , vbCr, "")
    strval = Replace(strval , vbLf, "")

    LogMsg Trim(strval) 

    Dim command : command = "taskkill /F /T /PID "  & strval
    ' command = "echo 213423 " & strval & "> test.txt"
    LogMsg command
    
    ' intReturn = oShell.Run(command, 0, True)

    Dim WshScriptExec : Set WshScriptExec = oShell.Exec(command)

    If Err.Number <> 0 Then
        ' An error occurred, get the details
        Dim errorMessage
        errorMessage = "Error # " & CStr(Err.Number) & vbCrLf & _
                       "Description: " & Err.Description & vbCrLf & _
                       "Source: " & Err.Source
        
        LogMsg errorMessage
        
        Err.Clear
    End If

    If Not ( WshScriptExec Is Nothing or ( IsNull(WshScriptExec) ) ) Then
        Do While WshScriptExec.Status = 0
            WScript.Sleep 100 ' Sleep for 100 milliseconds
            LogMsg "sleeping"
        Loop

        StdOut = WshScriptExec.StdOut.ReadAll

        LogMsg StdOut
    
    End If

Loop

objTextFile.Close
Set objTextFile = Nothing

Set objFSO = Nothing
Set oShell = Nothing

LogMsg "done"
