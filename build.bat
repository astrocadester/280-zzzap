@echo off
setlocal
cd /d "%~dp0"
rem 280-ZZZAP original Intel 8080 ROM build; project zmac v1.3, no Python.
if defined ZMAC (
    set "ZMAC_BIN=%ZMAC%"
) else (
    set "ZMAC_BIN=tools\zmac.exe"
)
if not exist "%ZMAC_BIN%" (
    where "%ZMAC_BIN%" >nul 2>&1
    if errorlevel 1 (echo ERROR: Missing zmac v1.3 assembler.& exit /b 1)
)
if not exist "src\280zzzap.asm" (echo ERROR: Missing RE source src\280zzzap.asm& exit /b 1)
if not exist "roms\original\280zzzap.zip" (echo ERROR: Missing original ROM archive.& exit /b 1)
if not exist build mkdir build
del /q "build\280zzzap.bin" "build\280zzzap.lst" "roms\280zzzap.zip" >nul 2>&1
echo [1/3] Assemble 280-ZZZAP
"%ZMAC_BIN%" -c -o "build\280zzzap.bin" -x "build\280zzzap.lst" "src\280zzzap.asm"
if errorlevel 1 (echo ERROR: Assembly failed.& exit /b 1)
if not exist "build\280zzzap.bin" (echo ERROR: Missing ROM output.& exit /b 1)
echo [2/3] Split and SHA-1 verify six 1 KB devices
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
 "$ErrorActionPreference='Stop';" ^
 "$b=[IO.File]::ReadAllBytes('build\280zzzap.bin');if($b.Length -ne 6144){throw 'Expected 6144 bytes'};" ^
 "$n=@('zzzaph','zzzapg','zzzapf','zzzape','zzzapd','zzzapc');" ^
 "$s=@('b9cf16eb037ada73631ed24297e9e3b3bf6ab3cd','b2e2497e421e79a411d07ebf2eed2bb8dc227003','206bf2575696c4b14437f3db37a215ba33211943','ae5cf4481ee4b78ca0d2f4d560d295e922aa04a7','972475f80253bb0d24773a10aec26a12f28e7c23','ffa6bb84ef1f7c2d72fd26c24bd33aa014aeab7e');" ^
 "for($i=0;$i -lt 6;$i++){ $part=[byte[]]::new(1024);[Array]::Copy($b,$i*1024,$part,0,1024);$path=Join-Path build $n[$i];[IO.File]::WriteAllBytes($path,$part);$h=(Get-FileHash $path -Algorithm SHA1).Hash.ToLowerInvariant();if($h -ne $s[$i]){throw ($n[$i]+' SHA1 mismatch '+$h)};Write-Host ('PASS '+$n[$i]) }"
if errorlevel 1 (echo ERROR: ROM verification failed.& exit /b 1)
echo [3/3] Package roms\280zzzap.zip
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
 "$ErrorActionPreference='Stop';Compress-Archive -LiteralPath @('build\zzzaph','build\zzzapg','build\zzzapf','build\zzzape','build\zzzapd','build\zzzapc') -DestinationPath 'roms\280zzzap.zip' -Force"
if errorlevel 1 (echo ERROR: ROM packaging failed.& exit /b 1)
echo PASS: roms\280zzzap.zip
exit /b 0
