Option Explicit

' dump_process_list.vbs <output_path>
' outPath = GetTempPath() & "\" & "dump_process_list.txt"
' uses Win32_Process, doesn't use wmic


Function IsRunningWScript()
    Dim iswscript
    Dim host
    host = WScript.FullName

    If InStrRev(host, "\") > 0 Then
        host = Mid(host, InStrRev(host, "\") + 1)
    End If

    host = LCase(host)

    IsRunningWScript = False
    
    ' cscript.exe
    If host = "wscript.exe" Then
        IsRunningWScript = True
    End If

End Function

Function IIf(blnExpression, vTrueResult, vFalseResult)
    If blnExpression Then
        IIf = vTrueResult
    Else
        IIf = vFalseResult
    End If
End Function

Function IsNullOrWhiteSpace(ByVal strValue)
    If IsNull(strValue) Then
        IsNullOrWhiteSpace = True
        Exit Function
    End If
    
    If IsEmpty(strValue) Or Len(strValue) = 0 Then
        IsNullOrWhiteSpace = True
        Exit Function
    End If
    
    If Len(Trim(strValue)) = 0 Then
        IsNullOrWhiteSpace = True
        Exit Function
    End If
    
    IsNullOrWhiteSpace = False
End Function

Function GetTimeStamp()
    Dim dt, ms, ts
    dt = Now()
    
    ' Timer returns seconds passed since midnight
    ms = Right(FormatNumber(Timer(), 3), 3) 
    
    ' Format: YYYYMMDDHHMMSS + MS
    ts = Year(dt) & _
         Right("0" & Month(dt), 2) & _
         Right("0" & Day(dt), 2) & _
         Right("0" & Hour(dt), 2) & _
         Right("0" & Minute(dt), 2) & _
         Right("0" & Second(dt), 2) & _
         ms
         
    GetTimeStamp = ts
End Function

Class FileIO
    Public fso
	Public hFile
    Public fullPath
    
    Public Function Init(ByVal pFullPath)
        Me.fullPath = pFullPath
        Set fso = CreateObject("Scripting.FileSystemObject")
		Set hFile = Me.fso.OpenTextFile(Me.fullPath, 8, True)
    End Function
    
    Public Function WriteLine(msgStr)
		call Me.hFile.WriteLine(msgStr)
	End Function

End Class

Class LogFile
    Public fso
	Private logFileHandle
	
	Public logFileBaseName
    Public logFileExt
    Public logFileDirPath
	
	Public logFilePath
    Public logFileFilename

    Private Sub Class_Initialize()
        Set fso = CreateObject("Scripting.FileSystemObject")
        
        logFileDirPath = Me.GetTempPath()
        logFileBaseName = "logger"
        logFileExt = ".log"
		
    End Sub

    Public Function GetTempPath
        Dim tempfolder: Set tempfolder = fso.GetSpecialFolder(2)
        
        GetTempPath = tempfolder.Path 

    End Function

    Public Function PathExists(targetPath) 
    
        PathExists =  False
        
        If fso.FolderExists(targetPath) Or fso.FileExists(targetPath) Then
            PathExists = True
        End If
        
    End Function
    
    public sub BuildDir(strPath)

        If Me.PathExists(strPath) Then
            Exit Sub
        End if
        
        Dim parentDirPath : parentDirPath = Me.fso.GetParentFolderName(strPath)
        
        If Not Me.fso.FolderExists(parentDirPath) Then
            BuildDir Me.fso.GetParentFolderName(parentDirPath)
        End If

        Me.fso.CreateFolder(strPath)
        
    End sub

    Public Function BuildPath()
        BuildPath = Me.logFileDirPath & "\" & Me.logFileFilename
    End Function


    Public Function Init(plogFileBaseName, plogFileExt, plogFileDirPath)
	
		Me.logFileBaseName = IIf(IsNullOrWhiteSpace(plogFileBaseName), Me.logFileBaseName, plogFileBaseName)
        Me.logFileExt = IIf(IsNullOrWhiteSpace(pLogFileExt), Me.logFileExt, pLogFileExt)
        Me.logFileDirPath = IIf(IsNullOrWhiteSpace(pLogFileDirPath), Me.logFileDirPath, pLogFileDirPath)

	    Me.logFileFilename = Me.logFileBaseName & "_" & GetTimeStamp() & Me.logFileExt
		
		Me.logFilePath = Me.BuildPath()
		
		Me.BuildDir(Me.fso.GetParentFolderName(Me.logFilePath))
		
		Set logFileHandle = Me.fso.OpenTextFile(Me.logFilePath, 8, True)
	End Function
    
	Public Function Write(msgStr)
		call logFileHandle.WriteLine(msgStr)
	End Function
	
End Class

Class Logger
	Public hLogFile
    Private msgIndex
    ' [Public | Private] Const CONSTANT_NAME = Value

    
    Private Sub Class_Initialize()
        msgIndex = 0
    End Sub
    
    'Private Sub Class_Terminate()
    '    Me.logFile.Close
    'End Sub
    
    Public Function Init(plogFileBaseName, pLogFileExt, pLogFileDirPath)
        
        Set Me.hLogFile = New LogFile
		
		Call Me.hLogFile.Init(plogFileBaseName, plogFileExt, plogFileDirPath)

        Set Init = Me
    End Function
    
    Public Function LogMsg(msgStr)
        If IsNullOrWhiteSpace(msgStr) Then
            Exit Function
        End If
        
        msgIndex = msgIndex + 1
        msgStr = "[" & GetTimeStamp() & "]|[" & CStr(msgIndex) & "]|[" & Wscript.ScriptName & "]|" & msgStr
        
        Me.hLogFile.Write(msgStr)
        
        if Not iswscript Then
            WScript.Echo msgStr
        end if
        
    end function

End Class

Dim mylogger : Set mylogger = New Logger

If not mylogger Is nothing Then
    mylogger.Init "","",""
End if

Function Coalesce(value, defaultValue)
    ' Check if value is Null or Empty
    If IsNull(value) Or IsEmpty(value) Then
        Coalesce = defaultValue
    ElseIf Trim(value) = "" Then
        ' Optional: treat empty string as null
        Coalesce = defaultValue
    Else
        Coalesce = value
    End If
End Function


Public Function GetTempPath
    Dim fso : set fso = CreateObject("Scripting.FileSystemObject")

    Dim tempfolder: Set tempfolder = fso.GetSpecialFolder(2)
    
    GetTempPath = tempfolder.Path 
End Function

REM -----

Dim outFile : Set outFile = New FileIO
Dim outPath : outPath = GetTempPath() & "\" & "dump_process_list.txt"

If Wscript.Arguments.Count > 0 Then
    outPath = Wscript.Arguments(0)
End If

outFile.Init(outPath)

Dim objWMIService, objProcess, colProcesses
Dim strComputer, strList

strComputer = "."

Set objWMIService = GetObject("winmgmts:{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")

Set colProcesses = objWMIService.ExecQuery("Select * from Win32_Process")

Dim sep : sep = ", "

For Each objProcess in colProcesses
    strList = strList & vbCrLf 
    strList = strList & "Name=" & Coalesce(objProcess.Name,"EMPTY") & sep
    strList = strList & "PID=" & Coalesce(objProcess.ProcessId, "EMPTY") & sep
    strList = strList & "Path=" & Coalesce(objProcess.ExecutablePath,"EMPTY") & sep
    strList = strList & "CmdLine=" & Coalesce(objProcess.CommandLine,"EMPTY")
Next

outFile.WriteLine(strList)

Set objProcess = Nothing
Set colProcesses = Nothing
Set objWMIService = Nothing
