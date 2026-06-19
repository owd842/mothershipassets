Option Explicit

On Error Resume Next

Const ForReading = 1
Dim objTextFile, strLine, filePath

Dim objArgs, argCount
Set objArgs = Wscript.Arguments

argCount = objArgs.Count

If ( argCount < 1 ) Then
    ' WScript.Quit 1
End If

filePath = WScript.Arguments.Item(1)

Dim objFSO
Set objFSO = CreateObject("Scripting.FileSystemObject")

Dim oShell
Set oShell = CreateObject("WScript.Shell")

Dim cmdsarr
' cfkz eiwe ghso uahy izew
cmdsarr = Array("cfkz", "eiwe" , "ghso" , "uahy", "izew")

Dim intReturn
Dim cmdname
Dim wmiccmdstr

intReturn = oShell.Run("cmd /c type nul > %temp%\owd\pc_mon_ps1.pid", 0, True)
intReturn = oShell.Run("cmd /c type nul > %temp%\owd\shutdown.pid_list", 0, True)
intReturn = oShell.Run("cmd /c type nul > %temp%\owd\owd_shutdown.vbs.log", 0, True)

For Each cmdname In cmdsarr
    
    wmiccmdstr = "wmic process where ""CommandLine like '%" & cmdname & "%'"" get commandline, processid /value /format:csv | findstr /v wmic | findstr " & cmdname & " | findstr /v findstr"
    
    'WScript.Echo wmiccmdstr
    

   ' WScript.Echo "return code "  & intReturn

    intReturn = oShell.Run("cmd /c " & wmiccmdstr & " >> %temp%\owd\shutdown.pid_list", 0, True)

    'WScript.Echo "return code "  & intReturn
    
Next

wmiccmdstr = "wmic process get processid,commandline /format:csv | findstr /v findstr | findstr pc_monitoring.ps1" ' > %temp%\owd\pc_mon_ps1.pid"
intReturn = oShell.Run("cmd /c " & wmiccmdstr & " >> %temp%\owd\shutdown.pid_list", 0, True)


filePath = oShell.ExpandEnvironmentStrings("%TEMP%") & "\owd\shutdown.pid_list"

If Not objFSO.FileExists(filePath) Then
    WScript.Quit 1
End If

Set objTextFile = objFSO.OpenTextFile(filePath, ForReading)

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

    intReturn = oShell.Run("cmd /c taskkill /F /T /PID "  & CStr(strval) & " >> %temp%\owd\owd_shutdown.vbs.log", 0, True)

    ' WScript.Echo "return code " & intReturn 

Loop

objTextFile.Close
Set objTextFile = Nothing

Set objFSO = Nothing
Set oShell = Nothing
