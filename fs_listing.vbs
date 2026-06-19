Option Explicit
' On Error Resume Next

' cscript fs_listing.vbs <start folder path> <log file path>
' cscript fs_listing.vbs - <log file path>
' start folder path [optional] -->
' log file path [optional]     --> scriptdirpath & "\" & scriptfname & ".out"

Function IsWScriptRunning()
    Dim hostName
    hostName = LCase(Right(WScript.FullName, 11))

    IsWScriptRunning = False
    
    If hostName = "wscript.exe" Then
        IsWScriptRunning = True
    End If
    
End Function

Function GetTimestamp()
    Dim dt, ms, ts
    dt = Now()

    ms = Right("000" & Fix((Timer - Fix(Timer)) * 10000), 4)
    
    ts = Year(dt) & _
         Right("0" & Month(dt), 2) & _
         Right("0" & Day(dt), 2) & _
         Right("0" & Hour(dt), 2) & _
         Right("0" & Minute(dt), 2) & _
         Right("0" & Second(dt), 2) & _
         "." & ms
    GetTimestamp = ts
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

Class Logger

    Public fso 
    Public hLogFile
    Public logfpath
    
    Public scriptfname
    Public scriptfullpath
    Public scriptdirpath
    
    Public t_IsWScriptRunning
    
    Private Sub Class_Initialize()
        Set fso = CreateObject("Scripting.FileSystemObject")
    
        t_IsWScriptRunning = IsWScriptRunning()
        
        scriptfname = WScript.ScriptName
        scriptfullpath = WScript.ScriptFullName
        scriptdirpath = fso.GetParentFolderName(scriptfullpath)

        If Wscript.Arguments.Count > 1 Then
            logfpath = Wscript.Arguments(1)
            Dim l_dirpath : l_dirpath = fso.GetParentFolderName(logfpath)
            Dim l_fname : l_fname = fso.GetFileName(logfpath)
            
            If IsNullOrEmpty(l_dirpath) Then
                logfpath = scriptdirpath & "\" & l_fname
            End If
        Else
            logfpath = scriptdirpath & "\" & scriptfname & ".out"
        End If
        
        set hLogFile = fso.CreateTextFile(logfpath, 8, True) 

    End Sub

    Function LogMsg(ByVal msg)
        Call LogMsgX(msg, True)
    End Function

    Function LogMsgX(ByVal msg, ByVal markup)
        If IsNullOrEmpty(msg) Then
            Exit Function
        End If
        
        If IsEmpty(markup) Then
            markup = True
        End If
        
        If markup Then
            msg = "[" & GetTimestamp() & "]|[" & scriptfname & "]|" & msg
        End If
        
        If Not t_IsWScriptRunning Then
            WScript.Echo msg
        End If

        If Not hLogFile Is Nothing Then
            hLogFile.WriteLine(msg)
        End If
        
    End Function
    
    Function WriteLine(ByVal msg)
        Call Me.LogMsgX(msg, False)
    End Function
    
End Class

Dim mylogger : set mylogger = new Logger

Dim fso : Set fso = CreateObject("Scripting.FileSystemObject")
Dim colDrives, objDrive
Set colDrives = fso.Drives

mylogger.LogMsg("starting fs_listing")

mylogger.LogMsg("--- Available Drives (FSO) ---")

For Each objDrive In colDrives
    mylogger.LogMsg "Drive letter: " & objDrive.DriveLetter
    mylogger.LogMsg "Drive type: " & objDrive.DriveType
    
    If objDrive.IsReady Then
        mylogger.LogMsg "Volume name: " & objDrive.VolumeName
        mylogger.LogMsg "File system: " & objDrive.FileSystem
        mylogger.LogMsg "Total size: " & FormatNumber(objDrive.TotalSize / (1024^3), 2) & " GB"
        mylogger.LogMsg "Free space: " & FormatNumber(objDrive.FreeSpace / (1024^3), 2) & " GB"
    Else
        mylogger.LogMsg "Drive is not ready (e.g., no media in a removable drive)"
    End If
    mylogger.LogMsg "----------------------------------"
Next


Dim startPath : startPath = "C:\"

If Wscript.Arguments.Count > 0 Then
    If Not Wscript.Arguments(0) = "-" Then
        startPath = Wscript.Arguments(0)
    End If
End If

If Not fso.FolderExists(startPath) Then
    mylogger.LogMsg "Starting folder/drive not found: " & objStartFolder
    Wscript.Quit 1
End If

Sub ListFilesInFolder(SourceFolderName)
    On Error Resume Next
    
    Dim objFolder, objSubFolder, objFile

    Set objFolder = fso.GetFolder(SourceFolderName)

    For Each objFile In objFolder.Files
        mylogger.WriteLine("""" & objFile.ParentFolder.Path & """,""" & _
                   objFile.Name & """,""" & objFile.Size & """,""" & _
                   objFile.DateLastModified & """,""" & objFile.DateCreated & """,""" & _
                   objFile.Attributes & """")
    Next

    For Each objSubFolder In objFolder.SubFolders
        Call ListFilesInFolder(objSubFolder.Path)
    Next
End Sub

mylogger.WriteLine("Path,FileName,Size(Bytes),DateLastModified,DateCreated,Attributes")

Call ListFilesInFolder(startPath)
