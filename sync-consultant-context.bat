@echo off
REM Copies the foundational docs into the Consultant's workspace so it has its
REM standing context. /docs/*.md is the single source of truth; the copies in
REM consultant-corner are derived (and git-ignored). Re-run this after editing
REM any of the originals to keep the Consultant up to date.
cd /d "%~dp0"
set "DEST=docs\roles\consultant-corner"
echo Syncing foundational docs into %DEST% ...
copy /Y "docs\charter.md"          "%DEST%\charter.md"          >nul && echo    charter.md
copy /Y "docs\principles.md"       "%DEST%\principles.md"       >nul && echo    principles.md
copy /Y "docs\technical-tenets.md" "%DEST%\technical-tenets.md" >nul && echo    technical-tenets.md
echo.
if %errorlevel%==0 (echo Done - Consultant context is up to date.) else (echo Something failed - check the paths above.)
echo.
echo Press any key to close.
pause >nul
