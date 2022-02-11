@echo off
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Unrestricted -Command ""%~dp0\AppLauncher.ps1" -LaunchTarget 'login.bat' -EnableDebug; Read-Host -Prompt 'press enter to exit'"
