@echo off
rem Arranca el servidor dedicado de Velvet Heist 84 sin ventana. Uso: servidor.bat [puerto]
set PORT=%1
if "%PORT%"=="" set PORT=7777
cd /d "%~dp0"
VelvetHeist84.console.exe --headless --server --port %PORT%
