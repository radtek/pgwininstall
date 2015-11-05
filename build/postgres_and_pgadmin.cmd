REM BUILD DEPENDS
REM 1. .NET 4.0
REM 2. MICROSOFT SDK 7.1
REM 3. ACTIVE PERL <= 5.14
REM 4. PYTHON 2.7
REM 5. MSYS2
REM 6. 7Z

REM If you have already built dependencies archive this must be set YES
SET HAVE_DEPS_ZIP=NO

REM Set 1C build (YES or NO)
SET ONEC=NO

REM SET POSTGRESQL VERSION
SET PGVER=9.4.5

REM SET ARCH: X86 or X64
SET ARCH=X64

REM Magic to set root directory of those scripts
@echo off&setlocal
FOR %%i in ("%~dp0..") do set "ROOT=%%~fi"

SET PATH=%PATH%;C:\Program Files\7-Zip;C:\msys32\usr\bin
IF %ARCH% == X86 SET PATH=C:\Perl\Bin;%PATH%
IF %ARCH% == X64 SET PATH=C:\Perl64\Bin;%PATH%
CALL "C:\Program Files\Microsoft SDKs\Windows\v7.1\Bin\SetEnv" /%ARCH% || GOTO :ERROR

pacman --noconfirm --sync flex bison tar wget patch

SET BUILD_DIR=c:\pg
SET DOWNLOADS_DIR=%BUILD_DIR%\downloads
MKDIR %DOWNLOADS_DIR%
SET DEPENDENCIES_DIR=%BUILD_DIR%\dependencies

IF %HAVE_DEPS_ZIP%==YES (
  IF EXIST %DOWNLOADS_DIR%\deps_%ARCH%.zip (
    7z x %DOWNLOADS_DIR%\deps_%ARCH%.zip -o%DEPENDENCIES_DIR% -y
    REM Go to last build
    GOTO :BUILD_ALL
  ) ELSE (
    ECHO "You need to build dependencies first!"
  )
) ELSE (
  ECHO "You need to build dependencies first!"
  REM Go to last build
  GOTO :BUILD_ALL
)

:BUILD_ALL

:BUILD_POSTGRESQL
CD %DOWNLOADS_DIR%
wget --no-check-certificate -c https://ftp.postgresql.org/pub/source/v%PGVER%/postgresql-%PGVER%.tar.bz2 -O postgresql-%PGVER%.tar.bz2
rm -rf %BUILD_DIR%\postgresql
MKDIR %BUILD_DIR%\postgresql
tar xf postgresql-%PGVER%.tar.bz2 -C %BUILD_DIR%\postgresql
CD %BUILD_DIR%\postgresql\postgresql-%PGVER%

IF %ONEC% == YES (
  cp -va %ROOT%/patches/postgresql/%PGVER%/series.for1c .
  IF NOT EXIST series.for1c GOTO :ERROR
  FOR /F %%I IN (series.for1c) DO (
    ECHO %%I
    cp -va %ROOT%/patches/postgresql/%PGVER%/%%I .
    patch -p1 < %%I || GOTO :ERROR
  )
)

cp -va %ROOT%/patches/postgresql/%PGVER%/series .
IF NOT EXIST series GOTO :DONE_POSTGRESQL_PATCH
FOR /F %%I IN (series) do (
  ECHO %%I
  cp -va %ROOT%/patches/postgresql/%PGVER%/%%I .
  patch -p1 < %%I || GOTO :ERROR
)
:DONE_POSTGRESQL_PATCH
>src\tools\msvc\config.pl  ECHO use strict;
>>src\tools\msvc\config.pl ECHO use warnings;
>>src\tools\msvc\config.pl ECHO our $config = {
>>src\tools\msvc\config.pl ECHO asserts ^=^> 0^,    ^# --enable-cassert
>>src\tools\msvc\config.pl ECHO ^# integer_datetimes^=^>1,
>>src\tools\msvc\config.pl ECHO ^# float4byval^=^>1,
>>src\tools\msvc\config.pl ECHO ^# float8byval^=^>0,
>>src\tools\msvc\config.pl ECHO ^# blocksize ^=^> 8,
>>src\tools\msvc\config.pl ECHO ^# wal_blocksize ^=^> 8,
>>src\tools\msvc\config.pl ECHO ^# wal_segsize ^=^> 16,
>>src\tools\msvc\config.pl ECHO ldap    ^=^> 1,
>>src\tools\msvc\config.pl ECHO nls     ^=^> '%DEPENDENCIES_DIR%\libintl',
>>src\tools\msvc\config.pl ECHO tcl     ^=^> undef,
IF %ARCH% == X64 (>>src\tools\msvc\config.pl ECHO perl    ^=^> 'C:\Perl64',   )
IF %ARCH% == X86 (>>src\tools\msvc\config.pl ECHO perl    ^=^> 'C:\Perl',     )
IF %ARCH% == X64 (>>src\tools\msvc\config.pl ECHO python  ^=^> 'C:\Python27x64', )
IF %ARCH% == X86 (>>src\tools\msvc\config.pl ECHO python  ^=^> 'C:\Python27x86', )
>>src\tools\msvc\config.pl ECHO openssl ^=^> '%DEPENDENCIES_DIR%\openssl',
>>src\tools\msvc\config.pl ECHO uuid    ^=^> '%DEPENDENCIES_DIR%\uuid',
>>src\tools\msvc\config.pl ECHO xml     ^=^> '%DEPENDENCIES_DIR%\libxml2',
>>src\tools\msvc\config.pl ECHO xslt    ^=^> '%DEPENDENCIES_DIR%\libxslt',
>>src\tools\msvc\config.pl ECHO iconv   ^=^> '%DEPENDENCIES_DIR%\iconv',
>>src\tools\msvc\config.pl ECHO zlib    ^=^> '%DEPENDENCIES_DIR%\zlib'
>>src\tools\msvc\config.pl ECHO ^};
>>src\tools\msvc\config.pl ECHO 1^;
IF %ONEC% == YES (
  mv -v contrib\fulleq\fulleq.sql.in.in contrib\fulleq\fulleq.sql.in
  cp -va %DEPENDENCIES_DIR%/icu/include/* src\include\
  cp -va %DEPENDENCIES_DIR%/icu/lib/*     .
)

perl src\tools\msvc\build.pl || GOTO :ERROR
IF %ARCH% == X86 SET PERL5LIB=C:\Perl\lib;src\tools\msvc
IF %ARCH% == X64 SET PERL5LIB=C:\Perl64\lib;src\tools\msvc
rm -rf %BUILD_DIR%\distr_%ARCH%_%PGVER%\postgresql
MKDIR %BUILD_DIR%\distr_%ARCH%_%PGVER%\postgresql
CD %BUILD_DIR%\postgresql\postgresql-%PGVER%\src\tools\msvc
cp -v %DEPENDENCIES_DIR%/libintl/lib/*.dll  %BUILD_DIR%\postgresql\postgresql-%PGVER%\ || GOTO :ERROR
cp -v %DEPENDENCIES_DIR%/iconv/lib/*.dll    %BUILD_DIR%\postgresql\postgresql-%PGVER%\ || GOTO :ERROR

perl install.pl %BUILD_DIR%\distr_%ARCH%_%PGVER%\postgresql || GOTO :ERROR
cp -v %DEPENDENCIES_DIR%/libintl/lib/*.dll    %BUILD_DIR%\distr_%ARCH%_%PGVER%\postgresql\bin || GOTO :ERROR
cp -v %DEPENDENCIES_DIR%/iconv/lib/*.dll      %BUILD_DIR%\distr_%ARCH%_%PGVER%\postgresql\bin || GOTO :ERROR
cp -v %DEPENDENCIES_DIR%/libxml2/lib/*.dll    %BUILD_DIR%\distr_%ARCH%_%PGVER%\postgresql\bin || GOTO :ERROR
cp -v %DEPENDENCIES_DIR%/libxslt/lib/*.dll    %BUILD_DIR%\distr_%ARCH%_%PGVER%\postgresql\bin || GOTO :ERROR
cp -v %DEPENDENCIES_DIR%/openssl/lib/VC/*.dll %BUILD_DIR%\distr_%ARCH%_%PGVER%\postgresql\bin || GOTO :ERROR
cp -v %DEPENDENCIES_DIR%/zlib/lib/*.dll       %BUILD_DIR%\distr_%ARCH%_%PGVER%\postgresql\bin || GOTO :ERROR
IF %ONEC% == YES cp -va %DEPENDENCIES_DIR%/icu/bin/*.dll %BUILD_DIR%\distr_%ARCH%_%PGVER%\postgresql\bin || GOTO :ERROR

REM Copy libraries headers to "include" directory for a God sake
cp -va %DEPENDENCIES_DIR%/libintl/include/*  %BUILD_DIR%\distr_%ARCH%_%PGVER%\postgresql\include || GOTO :ERROR
cp -va %DEPENDENCIES_DIR%/iconv/include/*    %BUILD_DIR%\distr_%ARCH%_%PGVER%\postgresql\include || GOTO :ERROR
cp -va %DEPENDENCIES_DIR%/libxml2/include/*  %BUILD_DIR%\distr_%ARCH%_%PGVER%\postgresql\include || GOTO :ERROR
cp -va %DEPENDENCIES_DIR%/libxslt/include/*  %BUILD_DIR%\distr_%ARCH%_%PGVER%\postgresql\include || GOTO :ERROR
cp -va %DEPENDENCIES_DIR%/openssl/include/*  %BUILD_DIR%\distr_%ARCH%_%PGVER%\postgresql\include || GOTO :ERROR
cp -va %DEPENDENCIES_DIR%/zlib/include/*     %BUILD_DIR%\distr_%ARCH%_%PGVER%\postgresql\include || GOTO :ERROR
cp -va %DEPENDENCIES_DIR%/uuid/include/*     %BUILD_DIR%\distr_%ARCH%_%PGVER%\postgresql\include || GOTO :ERROR

7z a -r %DOWNLOADS_DIR%\pgsql_%ARCH%_%PGVER%.zip %BUILD_DIR%\distr_%ARCH%_%PGVER%\postgresql


:BUILD_PGADMIN
CD %DOWNLOADS_DIR%
wget --no-check-certificate -c https://ftp.postgresql.org/pub/pgadmin3/release/v1.20.0/src/pgadmin3-1.20.0.tar.gz -O pgadmin3-1.20.0.tar.gz
rm -rf %BUILD_DIR%\pgadmin
MKDIR %BUILD_DIR%\pgadmin
tar xf pgadmin3-1.20.0.tar.gz -C %BUILD_DIR%\pgadmin
CD %BUILD_DIR%\pgadmin\pgadmin3-*
SET OPENSSL=%DEPENDENCIES_DIR%\openssl
SET WXWIN=%DEPENDENCIES_DIR%\wxwidgets
SET PGBUILD=%DEPENDENCIES_DIR%
SET PGDIR=%BUILD_DIR%\distr_%ARCH%_%PGVER%\postgresql
SET PROJECTDIR=
cp -a %DEPENDENCIES_DIR%/libssh2/include/* pgadmin\include\libssh2 || GOTO :ERROR
IF %ARCH% == X64 sed -i 's/Win32/x64/g' xtra\png2c\png2c.vcxproj
IF %ARCH% == X64 sed -i 's/Win32/x64/g' pgadmin\pgAdmin3.vcxproj
sed -i "/<Bscmake>/,/<\/Bscmake>/d" pgadmin\pgAdmin3.vcxproj
IF %ARCH% == X86 msbuild xtra/png2c/png2c.vcxproj /p:Configuration="Release (3.0)" || GOTO :ERROR
IF %ARCH% == X64 msbuild xtra/png2c/png2c.vcxproj /p:Configuration="Release (3.0)" /p:Platform=x64 || GOTO :ERROR
cp -va xtra pgadmin || GOTO :ERROR
IF %ARCH% == X86 msbuild pgadmin/pgAdmin3.vcxproj /p:Configuration="Release (3.0)"
IF %ARCH% == X64 msbuild pgadmin/pgAdmin3.vcxproj /p:Configuration="Release (3.0)" /p:Platform=x64 || echo todo fix
rm -rf %BUILD_DIR%\distr_%ARCH%_%PGVER%\pgadmin
MKDIR %BUILD_DIR%\distr_%ARCH%_%PGVER%\pgadmin %BUILD_DIR%\distr_%ARCH%_%PGVER%\pgadmin\bin %BUILD_DIR%\distr_%ARCH%_%PGVER%\pgadmin\lib
cp -va pgadmin/Release*/*.exe %BUILD_DIR%\distr_%ARCH%_%PGVER%\pgadmin\bin  || GOTO :ERROR
cp -va i18n c:/pg/distr_%ARCH%_%PGVER%/pgadmin/bin  || GOTO :ERROR
cp -va c:/pg/distr_%ARCH%_%PGVER%/postgresql/bin/*.dll %BUILD_DIR%\distr_%ARCH%_%PGVER%\pgadmin\bin  || GOTO :ERROR
cp -va %DEPENDENCIES_DIR%/wxwidgets/lib/vc_dll/*.dll  %BUILD_DIR%\distr_%ARCH%_%PGVER%\pgadmin\bin  || GOTO :ERROR


GOTO :DONE

:ERROR
ECHO Failed with error #%errorlevel%.
PAUSE
EXIT /b %errorlevel%

:DONE
ECHO Done.
PAUSE
