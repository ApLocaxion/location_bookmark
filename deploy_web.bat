@echo off
setlocal enabledelayedexpansion

set FLUTTER_BIN=flutter
set BASE_HREF=/location_bookmark/
set COMMIT_MESSAGE=Update web build

where %FLUTTER_BIN% >nul 2>nul
if %errorlevel% neq 0 (
  echo Flutter not found on PATH. Update FLUTTER_BIN in deploy_web.bat.
  exit /b 1
)

echo Running flutter pub get...
%FLUTTER_BIN% pub get || exit /b 1

echo Building web with base href %BASE_HREF%...
%FLUTTER_BIN% build web --base-href %BASE_HREF% || exit /b 1

echo Syncing build/web to docs...
robocopy build\web docs /MIR
if %errorlevel% GEQ 8 (
  echo Robocopy failed with errorlevel %errorlevel%.
  exit /b %errorlevel%
)

echo Checking git status...
git add -A
git diff --cached --quiet
if %errorlevel%==0 (
  echo No changes to commit.
  exit /b 0
)

echo Committing and pushing...
git commit -m "%COMMIT_MESSAGE%" || exit /b 1
git push || exit /b 1

echo Done.
