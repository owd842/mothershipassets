Option Explicit
'On Error Resume Next

' cscript //B //nologo find_file.vbs owdkbdlog.txt C:\ .\find_file.vbs.out


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


Dim strFileName, startPath, outputPath
Dim arrFoundFiles, i
const ForReading = 1

If WScript.Arguments.Count > 0 Then
    strFileName = WScript.Arguments(0)
Else
    WScript.Quit 1
End If

startPath = "-"


If WScript.Arguments.Count > 1 Then
    startPath = WScript.Arguments(1)
End If

If startPath = "-" Then
    startPath = "C:\"
End If

outputPath = "-"

If WScript.Arguments.Count > 2 Then
    outputPath = WScript.Arguments(2)
End If


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


Dim objFSO : Set objFSO = CreateObject("Scripting.FileSystemObject")

Dim scriptFullPath : scriptFullPath = WScript.ScriptFullName
Dim scriptFileName : scriptFileName = objFSO.GetFileName(scriptFullPath)
Dim scriptDirFullPath : scriptDirFullPath = objFSO.GetParentFolderName(scriptFullPath)

Sub SearchFolders(SourceFolderName, FileName)
    On Error Resume Next
    
    Dim objFolder, objSubFolder, objFile

    Set objFolder = objFSO.GetFolder(SourceFolderName)

    For Each objFile In objFolder.Files
    
        If Err.Number = 0 Then
            If objFile.Name = FileName Then
                Call WriteOutput(objFile.ParentFolder.Path)
                WScript.Quit 0
            End If        
        End If
    Next

    For Each objSubFolder In objFolder.SubFolders
        Call SearchFolders(objSubFolder.Path, FileName)
    Next
End Sub

Function WriteOutput(ByVal response)
    If IsNullEmptyOrWhiteSpace(response) Then
        Exit Function
    End If
    
    Dim fso : Set fso = CreateObject("Scripting.FileSystemObject")

    Dim fullpath
    
    fullpath = scriptDirFullPath & "\" & scriptFileName & ".out"
    
    If outputPath = "-" Then
        outputPath = fullpath
    Else
        If IsNullEmptyOrWhiteSpace(outputPath) Then
            outputPath = fullpath
        ElseIf IsNullEmptyOrWhiteSpace(objFSO.GetParentFolderName(outputPath)) Then
            outputPath = scriptDirFullPath & "\" & outputPath
        End If
    End If
    
    Dim objOutFile: Set objOutFile = fso.CreateTextFile(outputPath, True)

    objOutFile.WriteLine(response)

    objOutFile.Close

    Set objOutFile = Nothing
    Set fso = Nothing

End Function

Call SearchFolders(startPath, strFileName)
