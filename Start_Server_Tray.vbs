Set fso = CreateObject("Scripting.FileSystemObject")
strPath = fso.GetParentFolderName(WScript.ScriptFullName)
Set WshShell = CreateObject("WScript.Shell")
WshShell.CurrentDirectory = strPath

' Launch pythonw with pc_server/main.py silently in the background
WshShell.Run "pythonw.exe " & Chr(34) & strPath & "\pc_server\main.py" & Chr(34), 0, False
