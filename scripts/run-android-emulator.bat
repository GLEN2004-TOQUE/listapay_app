@echo off
setlocal

REM Starts an existing AVD.
set "AVD_NAME=listapay_api34"

if not "%ANDROID_SDK_ROOT%"=="" (
  set "SDK_ROOT=%ANDROID_SDK_ROOT%"
) else (
  set "SDK_ROOT=%LOCALAPPDATA%\Android\Sdk"
)

set "EMULATOR=%SDK_ROOT%\emulator\emulator.exe"

if not exist "%EMULATOR%" (
  echo ERROR: emulator not found at: %EMULATOR%
  exit /b 1
)

REM Check if the AVD actually exists.
set "AVD_EXISTS=0"
for /f "tokens=*" %%i in ('"%EMULATOR%" -list-avds') do (
  if "%%i"=="%AVD_NAME%" set "AVD_EXISTS=1"
)

if "%AVD_EXISTS%"=="0" (
  echo ERROR: AVD "%AVD_NAME%" not found.
  echo Please run: scripts\create-android-emulator.bat
  exit /b 1
)

echo Starting emulator: %AVD_NAME%
"%EMULATOR%" -avd "%AVD_NAME%" -netdelay none -netspeed full
endlocal
