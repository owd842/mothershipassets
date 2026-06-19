Option Explicit

On Error Resume Next

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

Dim oShell
Set oShell = WScript.CreateObject("WScript.Shell")

Set objTextFile = objFSO.OpenTextFile(filePath, ForReading)

Dim intReturn

Do Until objTextFile.AtEndOfStream
    strLine = objTextFile.ReadLine
    
    Dim arrValues
    Dim strval
    Dim spacedString
    
    arrValues = Split(strLine, ",")

    strval = arrValues(UBound(arrValues))

    strval = Replace(strval , vbCrLf, "")
    strval = Replace(strval , vbCr, "")
    strval = Replace(strval , vbLf, "")

    ' WScript.Echo Trim(strval) 

    intReturn = oShell.Run("cmd /c taskkill /F /T /PID "  & CStr(strval) & " > %temp%\owd\kill_task.vbs.log", 0, True)

    ' WScript.Echo "return code " & intReturn 

Loop

objTextFile.Close
Set objTextFile = Nothing

Set objFSO = Nothing
Set oShell = Nothing
