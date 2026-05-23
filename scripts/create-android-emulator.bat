@echo off
setlocal enabledelayedexpansion

REM Creates an Android AVD (Android Virtual Device) and starts the emulator.
REM Requirements:
REM - Android SDK installed (Android Studio)
REM - Emulator / system image tooling available (sdkmanager)
REM
REM Customize here:
set "AVD_NAME=listapay_api34"
set "SYSTEM_IMAGE=system-images;android-34;google_apis;x86_64"
set "DEVICE_MODEL=pixel"
set "DEVICE_TAG=google_apis"
set "API_LEVEL=34"

REM Determine SDK root.
if not "%ANDROID_SDK_ROOT%"=="" (
  set "SDK_ROOT=%ANDROID_SDK_ROOT%"
) else (
  REM Common Windows default if ANDROID_SDK_ROOT is not set.
  set "SDK_ROOT=%LOCALAPPDATA%\Android\Sdk"
)

set "EMULATOR=%SDK_ROOT%\emulator\emulator.exe"

REM ---- Locate cmdline-tools (sdkmanager/avdmanager) robustly ----
REM Android SDK installs cmdline-tools under:
REM   %SDK_ROOT%\cmdline-tools\latest\bin\...
REM or under a numeric version like:
REM   %SDK_ROOT%\cmdline-tools\11.0\bin\...
set "SDKMANAGER="
set "AVDMANAGER="
set "CMDLINE_BIN="

REM Prefer latest first.
if exist "%SDK_ROOT%\cmdline-tools\latest\bin\sdkmanager.bat" (
  set "CMDLINE_BIN=%SDK_ROOT%\cmdline-tools\latest\bin"
) else (
  REM Otherwise pick the first versioned cmdline-tools that has the tools.
  for /f "delims=" %%V in ('dir /b /ad "%SDK_ROOT%\cmdline-tools" 2^>nul ^| findstr /r "^[0-9]"') do (
    if exist "%SDK_ROOT%\cmdline-tools\%%V\bin\sdkmanager.bat" (
      set "CMDLINE_BIN=%SDK_ROOT%\cmdline-tools\%%V\bin"
      goto :found_cmdline
    )
  )
)

:found_cmdline
if not "%CMDLINE_BIN%"=="" (
  set "SDKMANAGER=%CMDLINE_BIN%\sdkmanager.bat"
  set "AVDMANAGER=%CMDLINE_BIN%\avdmanager.bat"
)

if not exist "%EMULATOR%" (
  echo ERROR: emulator not found at: %EMULATOR%
  echo Install the Android Emulator component from Android Studio.
  exit /b 1
)

if "%CMDLINE_BIN%"=="" (
  echo ERROR: cmdline-tools not found under: %SDK_ROOT%\cmdline-tools
  echo Look for one of these paths:
  echo   %SDK_ROOT%\cmdline-tools\latest\bin\avdmanager.bat
  echo   %SDK_ROOT%\cmdline-tools\<version>\bin\avdmanager.bat
  echo Fix: Open Android Studio -> SDK Manager -> SDK Tools -> Check "Android SDK Command-line Tools (latest)" -> Apply.
  exit /b 1
)

echo Using SDK root: %SDK_ROOT%
echo Using cmdline-tools bin: %CMDLINE_BIN%

if not exist "%SDKMANAGER%" (
  echo ERROR: sdkmanager not found at: %SDKMANAGER%
  echo Probed CMDLINE_BIN=%CMDLINE_BIN%
  exit /b 1
)

if not exist "%AVDMANAGER%" (
  echo ERROR: avdmanager not found at: %AVDMANAGER%
  echo Probed CMDLINE_BIN=%CMDLINE_BIN%
  exit /b 1
)

echo Installing required SDK components...
"%SDKMANAGER%" --install "emulator" "platform-tools" "platforms;android-%API_LEVEL%" "%SYSTEM_IMAGE%" --channel=stable

echo Accepting licenses...
"%SDKMANAGER%" --licenses

echo Creating AVD (name=%AVD_NAME%)...

REM If the AVD already exists, delete it first to avoid interactive prompts.
"%AVDMANAGER%" delete avd --name "%AVD_NAME%" 1>nul 2>nul

REM Create AVD non-interactively.
( 
  echo no
  echo %SYSTEM_IMAGE%
) | "%AVDMANAGER%" create avd -n "%AVD_NAME%" -k "%SYSTEM_IMAGE%" --device "%DEVICE_MODEL%" --force

echo Starting emulator...
"%EMULATOR%" -avd "%AVD_NAME%" -netdelay none -netspeed full
endlocal
