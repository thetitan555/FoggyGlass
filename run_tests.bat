@echo off
setlocal enabledelayedexpansion
set "GODOT=C:\Users\ryans\Downloads\Godot_v4.3-stable_win64.exe"
set "TESTS=test_fp test_tick_host test_input test_sim_state test_inspection_view test_move_format test_harness test_combat test_done_bar"
set "FAILED="
for %%T in (%TESTS%) do (
  echo ==== %%T ====
  "%GODOT%" --headless --path game -s res://tests/%%T.gd
  if errorlevel 1 (
    echo [FAIL] %%T
    set "FAILED=!FAILED! %%T"
  ) else (
    echo [PASS] %%T
  )
  echo.
)
echo ======== SUMMARY ========
if "!FAILED!"=="" (echo All 9 passed.) else (echo FAILED:!FAILED!)
pause >nul