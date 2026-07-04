@echo off
setlocal enabledelayedexpansion
REM FoggyGlass - commit all changes, then push to GitHub.
REM Your manual push gate: work is committed with native git during a session;
REM run this when you want the branch backed up to origin/main. Prompts for a
REM commit message if there is anything still uncommitted.
cd /d "%~dp0"
echo === FoggyGlass: commit ^& push ===
echo.

git add -A
git diff --cached --quiet
if errorlevel 1 (
  set "MSG="
  set /p MSG=Commit message:
  if "!MSG!"=="" set "MSG=checkpoint"
  git commit -m "!MSG!"
) else (
  echo Nothing to commit - pushing existing commits.
)

echo.
echo Pushing to origin/main...
git push origin main
echo.
if errorlevel 1 (
  echo Push failed - see above. If it mentions non-fast-forward, run:
  echo     git pull --rebase
  echo and then run this again.
) else (
  echo Done - committed and pushed.
)
echo.
echo Press any key to close.
pause >nul
