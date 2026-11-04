@echo off
cd /d "%~dp0..\.."
python -B -X utf8 report\demo\show_evidence.py %*
echo.
pause
