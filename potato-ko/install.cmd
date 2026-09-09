@echo off
chcp 65001 >nul
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
set "PATCH_EXIT=%ERRORLEVEL%"
echo.
if not "%PATCH_EXIT%"=="0" echo 설치하지 못했습니다. 위 오류를 확인해 주세요.
if "%POTATO_KO_NO_PAUSE%"=="1" exit /b %PATCH_EXIT%
pause
exit /b %PATCH_EXIT%
