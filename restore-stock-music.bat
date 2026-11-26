@echo off
rem UTF-8 before any Cyrillic byte: cmd must not read this file in cp866.
rem Keep this file CRLF (.gitattributes: *.bat eol=crlf).
chcp 65001 >nul
rem Вернуть штатный музыкальный плеер ГУ (com.voyah.cockpit.voyahmusic), выключенный функцией
rem Courage+ «Кнопка музыки» (docs/dock-music.md). Нужен, если Courage+ удалён, не открывается или
rem заменён версией без этой функции; иначе плеер возвращает сам Courage+.
rem Скрипт ещё и блокирует функцию (courage_dockmusic_block), снять — выключить и включить тумблер.
rem В install-to-hu.* этого нет намеренно: установщик запускают и при обновлении.
set "DIR=%~dp0"
set "ADB=%DIR%adb\win\adb.exe"
if not exist "%ADB%" set "ADB=adb"
echo Ожидание ГУ ^(подтверди отладку на экране авто^)...
"%ADB%" wait-for-device
"%ADB%" shell settings put global courage_dockmusic_block 1 >nul 2>nul
"%ADB%" shell pm enable --user 0 com.voyah.cockpit.voyahmusic
"%ADB%" shell settings delete global courage_dockmusic_off >nul 2>nul
echo Проверка: в списке ниже должна быть строка package:com.voyah.cockpit.voyahmusic
"%ADB%" shell pm list packages -e com.voyah.cockpit.voyahmusic
pause
