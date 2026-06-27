@echo off
setlocal enabledelayedexpansion
REM FoggyGlass - commit all changes locally, WITHOUT pushing.
REM Runs on YOUR machine with native git, so it sidesteps the mounted-folder
REM git fragility entirely. Use it to checkpoint a role's work; run push.bat
REM (or this then push.bat) when you want it backed up to GitHub.
REM
REM A role signals "ready to commit" by writing its message into COMMIT_MSG.txt
REM and telling you in chat. This script reads that message, then deletes the
REM file. If there's no COMMIT_MSG.txt it just asks you for a message.
cd /d "%~dp0"
echo === FoggyGlass: commit (local only) ===
echo.

REM Clear stale git lock files left behind by earlier sandbox operations. In
REM this project only these helper scripts run git, one at a time, so a leftover
REM lock is always safe to remove. (Windows can delete them; the sandbox can't.)
if exist ".git\index.lock" ( del /f /q ".git\index.lock" && echo Cleared a stale .git\index.lock )
if exist ".git\HEAD.lock" ( del /f /q ".git\HEAD.lock" && echo Cleared a stale .git\HEAD.lock )

git add -A
git diff --cached --quiet
if errorlevel 1 (
  set "MSG="
  if exist COMMIT_MSG.txt set /p MSG=<COMMIT_MSG.txt
  if "!MSG!"=="" set /p MSG=Commit message:
  if "!MSG!"=="" set "MSG=checkpoint"
  git commit -m "!MSG!"
  if exist COMMIT_MSG.txt del COMMIT_MSG.txt
  echo.
  echo Committed locally. Run push.bat when you want it on GitHub.
) else (
  echo Nothing to commit - working tree is clean.
)

echo.
echo Press any key to close.
pause >nul
