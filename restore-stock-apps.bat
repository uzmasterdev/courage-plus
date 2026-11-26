@echo off
rem UTF-8 before any Cyrillic byte: cmd must not read this file in cp866.
rem Keep this file CRLF (.gitattributes: *.bat eol=crlf). Flat lines only: no brackets, pipes, for.
chcp 65001 >nul
rem Вернуть штатные приложения ГУ, выключенные страницей Courage+ «Приложения › Штатные» (docs/stock-apps.md).
rem Нужен, если Courage+ удалён, не открывается или заменён версией без этой функции.
rem Включает все пакеты каталога stockapps.StockAppsCatalog; список совпадает с ним - StockAppsScriptsTest.
rem Метку courage_stockapps_off скрипт не стирает. В install-to-hu.* этого нет намеренно.
set "DIR=%~dp0"
set "ADB=%DIR%adb\win\adb.exe"
if not exist "%ADB%" set "ADB=adb"
echo Ожидание ГУ - подтверди отладку на экране авто...
"%ADB%" wait-for-device
"%ADB%" shell pm enable --user 0 com.tencent.qqlive.audiobox >nul 2>nul
"%ADB%" shell pm enable --user 0 com.arcvideo.car.iqy.video >nul 2>nul
"%ADB%" shell pm enable --user 0 cn.cmvideo.car.play >nul 2>nul
echo Проверка: в списке выключенных ниже не должно быть ни одного из этих пакетов:
echo com.tencent.qqlive.audiobox com.arcvideo.car.iqy.video cn.cmvideo.car.play
"%ADB%" shell pm list packages -d
pause
