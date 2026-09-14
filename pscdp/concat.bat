FOR /L %%i IN (1, 1, 5) DO (
    echo Current index is %%i > run.ps1_%%i
)

copy nul combined.out >nul

SET cmd=dir /B /O:N run.ps1_*
FOR /f "tokens=*" %%f IN ('%cmd%') DO (
    echo combining %%f
    copy /b combined.out + "%%f" combined.out >nul
)
