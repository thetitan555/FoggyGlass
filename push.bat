@echo off
REM FoggyGlass - push committed work to GitHub.
REM The Cowork role sandboxes are network-isolated and cannot reach GitHub,
REM so they only commit locally. Double-click this on your machine to sync
REM those commits up to origin. Uses your normal GitHub credentials.
cd /d "%~dp0"
echo Pushing FoggyGlass commits to GitHub (origin/main)...
echo.
git push origin main
echo.
if %errorlevel%==0 (
  echo Done - GitHub is up to date.
) else (
  echo Push failed - see the message above. Common causes: not logged in to
  echo GitHub on this machine, or someone pushed first ^(run: git pull --rebase^).
)
echo.
echo Press any key to close.
pause >nul
