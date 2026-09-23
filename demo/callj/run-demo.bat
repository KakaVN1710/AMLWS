@echo off
REM Demo CALLJ T24 -> AmlClient -> Mock AML server (Windows)
REM   run-demo.bat build
REM   run-demo.bat mock                      (de cua so nay mo)
REM   run-demo.bat run AML.CALLJ.DEMO        (o cua so khac)
REM   run-demo.bat run AML.CHECK.APPROVAL 100002 1001
REM   run-demo.bat package [AML_URL]         goi trien khai len T24 Model Bank (build\t24-deploy)
REM   set MOCK_OPTS=-Dmock.watchlist.ids=100100  (tuy chon cho mock, truoc khi chay "mock")
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
if "%1"=="package" goto package
echo Usage: run-demo.bat build ^| mock ^| run ^<PROGRAM^> [args...] ^| package [AML_URL]
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
java -Dmock.port=%MOCK_PORT% %MOCK_OPTS% -cp "%MOCK_CP%" demo.mock.MockAmlServer
exit /b %ERRORLEVEL%

:package
set AML_URL=%~2
if "%AML_URL%"=="" set AML_URL=http://localhost:8089
call :build
if errorlevel 1 exit /b 1
set OUT=%BUILD%\t24-deploy
if exist "%OUT%" rmdir /s /q "%OUT%"
mkdir "%OUT%\lib\thirdparty" "%OUT%\conf" "%OUT%\data" "%OUT%\BP" "%BUILD%\pkg-classes"
(for /f "usebackq delims=" %%L in ("%DEMO_DIR%\config\aml.properties") do (
    set "LINE=%%L"
    if "!LINE:~0,10!"=="based.url=" (echo based.url=%AML_URL%) else (echo !LINE!)
)) > "%OUT%\conf\aml.properties"
xcopy /e /i /q /y "%BUILD%\aml-classes" "%BUILD%\pkg-classes" >nul
copy /y "%OUT%\conf\aml.properties" "%BUILD%\pkg-classes\aml.properties" >nul
jar cf "%OUT%\lib\aml-integration-full.jar" -C "%BUILD%\pkg-classes" . || exit /b 1
copy /y "%BUILD%\lib\callj-training.jar" "%OUT%\lib\" >nul
for %%J in (httpclient5-5.5 httpcore5-5.3.4 httpcore5-h2-5.3.4 jackson-core-2.15.0 jackson-databind-2.15.0 jackson-annotations-2.15.0 sqlite-jdbc-3.50.1.0) do copy /y "%ROOT%\libs\%%J.jar" "%OUT%\lib\thirdparty\" >nul
copy /y "%TAFJ_HOME%\data\AMLScan.db" "%OUT%\data\" >nul
REM TAFJ BP: ten file = ten routine (bo duoi .b)
for %%F in ("%DEMO_DIR%\t24\BP\*.b") do copy /y "%%F" "%OUT%\BP\%%~nF" >nul
(
    echo(@echo off
    echo(REM Chay demo mainline tren TAFJ:  run-mb-demo.bat [CUSTOMER.ID ...]
    echo(REM OFS_SOURCE = ID mot record OFS.SOURCE co san ^(xem: tRun LIST F.OFS.SOURCE^)
    echo(if "%%OFS_SOURCE%%"=="" set OFS_SOURCE=OFSONLINE
    echo(echo OFS_SOURCE=%%OFS_SOURCE%%
    echo(call tRun AML.CALLJ.MB.DEMO %%*
) > "%OUT%\run-mb-demo.bat"
echo ^>^> Goi trien khai: %OUT%   (based.url=%AML_URL%)
dir /s /b "%OUT%"
exit /b 0

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
