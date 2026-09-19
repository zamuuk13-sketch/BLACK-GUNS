@echo off
setlocal
cd /d "%~dp0android\black_guns_hand_tracking"
echo ==========================================
echo BLACK GUNS - HAND TRACKING BACKEND
echo ==========================================
echo.
where gradle >nul 2>nul
if errorlevel 1 (
  echo ERRO: Gradle nao foi encontrado no PATH.
  echo Instale/configure Gradle ou use Android Studio.
  exit /b 1
)
echo [1/1] Compilando plugin MediaPipe...
call gradle :plugin:assemble
if errorlevel 1 (
  echo.
  echo BUILD FALHOU.
  exit /b 1
)
echo.
echo BUILD CONCLUIDO.
echo O plugin foi copiado para addons\BlackGunsHandTracking.
endlocal
