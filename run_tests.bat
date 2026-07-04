@echo off
setlocal enabledelayedexpansion
set "GODOT=C:\Users\ryans\Downloads\Godot_v4.3-stable_win64.exe"
set "TESTS=test_fp test_tick_host test_input test_sim_state test_inspection_view test_move_format test_harness test_combat test_done_bar test_overlap_boundary test_buffer_cancels test_throws_multihit"
set /a TOTAL=0
for %%T in (%TESTS%) do set /a TOTAL+=1
set "FAILED="
set /a PASSED=0
for %%T in (%TESTS%) do (
  echo ==== %%T ====
  "%GODOT%" --headless --path game -s res://tests/%%T.gd
  if errorlevel 1 (
    echo [FAIL] %%T
    set "FAILED=!FAILED! %%T"
  ) else (
    echo [PASS] %%T
    set /a PASSED+=1
  )
  echo.
)
echo ======== SUMMARY ========
if "!FAILED!"=="" (echo All !TOTAL! passed.) else (echo !PASSED!/!TOTAL! passed. FAILED:!FAILED!)
pause >nul
