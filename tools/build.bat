@echo off
setlocal

call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat" x64 >nul 2>&1
if errorlevel 1 (
    echo [FAIL] Could not initialize VS2022 x64 environment.
    exit /b 1
)

echo Building verify_module.exe...
cl.exe /nologo /EHsc /W3 /O2 "%~dp0verify_module.cpp" bcrypt.lib /Fe:"%~dp0verify_module.exe" /Fo:"%~dp0verify_module.obj"
if errorlevel 1 (
    echo [FAIL] verify_module.exe
    exit /b 1
)
echo [OK] verify_module.exe

echo Building sign_module.exe...
cl.exe /nologo /EHsc /W3 /O2 "%~dp0sign_module.cpp" bcrypt.lib /Fe:"%~dp0sign_module.exe" /Fo:"%~dp0sign_module.obj"
if errorlevel 1 (
    echo [FAIL] sign_module.exe
    exit /b 1
)
echo [OK] sign_module.exe

del /q "%~dp0verify_module.obj" "%~dp0sign_module.obj" 2>nul

echo.
echo Done. Binaries are in %~dp0
