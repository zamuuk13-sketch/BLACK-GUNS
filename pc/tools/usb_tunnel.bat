@echo off
title BLACK GUNS - USB VR TUNNEL
echo ==========================================
echo       BLACK GUNS - USB CONNECTION
echo ==========================================
echo.
echo Verificando ADB...
adb version
if errorlevel 1 (
    echo.
    echo ERRO: adb nao foi encontrado no PATH.
    echo Instale o Android SDK Platform-Tools e coloque o adb no PATH.
    pause
    exit /b 1
)
echo.
echo Removendo tunel anterior...
adb reverse --remove tcp:39100 >nul 2>&1
echo Criando tunel USB...
adb reverse tcp:39100 tcp:39100
if errorlevel 1 (
    echo.
    echo ERRO ao criar o tunel. Confirme a Depuracao USB no celular.
    pause
    exit /b 1
)
echo.
echo TUNEL USB ATIVO.
echo Celular localhost:39100 -> USB -> PC localhost:39100
echo.
pause
