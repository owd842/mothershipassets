Option Explicit
' On Error Resume Next

Dim objShell : Set objShell = CreateObject("WScript.Shell")
Dim fso : Set fso = CreateObject("Scripting.FileSystemObject")

Dim strScriptHost : strScriptHost = LCase(WScript.FullName)
Dim iscscript : iscscript = False

If Right(strScriptHost, 11) = "cscript.exe" Then
    iscscript = True
End If


Dim csvFilePath, outFilePath

If WScript.Arguments.Count > 1 Then
    csvFilePath = WScript.Arguments.Item(0)
    outFilePath = WScript.Arguments.Item(1)
Else
    WScript.Quit 1
End If


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

Dim tempPath : tempPath = objShell.ExpandEnvironmentStrings("%TEMP%")

tempPath = objShell.CurrentDirectory


Dim logfile : Set logfile = fso.CreateTextFile(tempPath & "\" & "get_macaddr_" & timestamp & ".log", True)

Function LogMsg(msg)
    If Not logfile Is Nothing Then
        logfile.WriteLine msg
    End If

    If iscscript Then
        WScript.Echo msg
    End IF
    
End Function

Function IsQuoted(str)
    ' Check if the string has a minimum length of 2 characters (opening and closing quotes)
    If Len(str) >= 2 Then
        ' Check if the first character is a double quote (Chr(34))
        If Left(str, 1) = Chr(34) Then
            ' Check if the last character is a double quote (Chr(34))
            If Right(str, 1) = Chr(34) Then
                IsQuoted = True
                Exit Function
            End If
        End If
    End If
    IsQuoted = False
End Function


If Not fso.FileExists(csvFilePath) Then
    LogMsg "Error: File not found at " & csvFilePath
    Wscript.Quit
End If

Dim objFile : Set objFile = fso.OpenTextFile(csvFilePath, 1) ' 1 = ForReading
Dim outFile : Set outFile = fso.OpenTextFile(outFilePath, 2, True) ' 2 = ForWriting 


LogMsg "Extracting 3rd column data:"

Do Until objFile.AtEndOfStream
    Dim strLine : strLine = objFile.ReadLine
    
    If Len(Trim(strLine)) > 0 Then
        
        LogMsg strLine
        
        Dim arrFields : arrFields = Split(strLine, ",")
        
        If UBound(arrFields) >= 2 Then
            Dim fieldstr : fieldstr = arrFields(2)
            
            If Len(fieldstr) >= 2 Then
                If IsQuoted(fieldstr) Then
                    fieldstr = Mid(fieldstr, 2, Len(fieldstr) - 2)
                End If
            End If            
        
            LogMsg "field: " & fieldstr
            
            outFile.WriteLine fieldstr
        End If
        
    End If
    
Loop

objFile.Close
outFile.Close

Set objFile = Nothing
Set outFile = Nothing

Set fso = Nothing