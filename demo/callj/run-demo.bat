@echo off
REM Demo CALLJ T24 -> AmlClient -> Mock AML server (Windows)
REM   run-demo.bat build
REM   run-demo.bat mock                      (de cua so nay mo)
REM   run-demo.bat run AML.CALLJ.DEMO        (o cua so khac)
REM   run-demo.bat run AML.CHECK.APPROVAL 100002 1001
setlocal EnableDelayedExpansion
set DEMO_DIR=%~dp0
set DEMO_DIR=%DEMO_DIR:~0,-1%
for %%I in ("%DEMO_DIR%\..\..") do set ROOT=%%~fI
set BUILD=%DEMO_DIR%\build
if "%MOCK_PORT%"=="" set MOCK_PORT=8089
set TAFJ_HOME=%BUILD%\tafj_home
set LIBS=%ROOT%\libs\*
set LIBMON=%ROOT%\libMonitor\*
set T24_CP=%DEMO_DIR%\config;%BUILD%\lib\aml-integration-full.jar;%BUILD%\lib\callj-training.jar;%LIBS%;%LIBMON%;%BUILD%\sim-classes
set MOCK_CP=%BUILD%\mock-classes;%LIBS%

if "%1"=="build" goto build
if "%1"=="mock" goto mock
if "%1"=="run" goto run
echo Usage: run-demo.bat build ^| mock ^| run ^<PROGRAM^> [args...]
exit /b 2

:build
if exist "%BUILD%" rmdir /s /q "%BUILD%"
mkdir "%BUILD%\lib" "%TAFJ_HOME%\data"
call :listsrc "%ROOT%\src\main" "%BUILD%\aml-src.txt"
javac -proc:none -encoding UTF-8 -nowarn -cp "%LIBS%" -d "%BUILD%\aml-classes" @"%BUILD%\aml-src.txt" || exit /b 1
jar cf "%BUILD%\lib\aml-integration-full.jar" -C "%BUILD%\aml-classes" . || exit /b 1
call :listsrc "%DEMO_DIR%\java" "%BUILD%\training-src.txt"
javac -encoding UTF-8 -d "%BUILD%\training-classes" @"%BUILD%\training-src.txt" || exit /b 1
jar cf "%BUILD%\lib\callj-training.jar" -C "%BUILD%\training-classes" . || exit /b 1
call :listsrc "%DEMO_DIR%\mock-server\src" "%BUILD%\mock-src.txt"
javac -proc:none -encoding UTF-8 -cp "%LIBS%" -d "%BUILD%\mock-classes" @"%BUILD%\mock-src.txt" || exit /b 1
call :listsrc "%DEMO_DIR%\t24-sim\src" "%BUILD%\sim-src.txt"
javac -proc:none -encoding UTF-8 -cp "%LIBS%" -d "%BUILD%\sim-classes" @"%BUILD%\sim-src.txt" || exit /b 1
java -cp "%T24_CP%" demo.t24.InitTokenDb
exit /b %ERRORLEVEL%

:mock
java -Dmock.port=%MOCK_PORT% -cp "%MOCK_CP%" demo.mock.MockAmlServer
exit /b %ERRORLEVEL%

:run
shift
set ARGS=
:collect
if "%~1"=="" goto dorun
set ARGS=!ARGS! %1
shift
goto collect
:dorun
java -cp "%T24_CP%" demo.t24.JbcRunner --bp "%DEMO_DIR%\t24\BP" %ARGS%
exit /b %ERRORLEVEL%

:listsrc
REM Ghi danh sach *.java vao argfile cho javac: moi duong dan dat trong "..." va doi '\' thanh '/'
REM (thu muc co dau cach nhu "Woori Cambodia"; trong argfile '\' la ky tu escape nen phai dung '/')
if exist "%~2" del "%~2"
for /r "%~1" %%F in (*.java) do (
    set "SRC=%%F"
    >>"%~2" echo "!SRC:\=/!"
)
exit /b 0
