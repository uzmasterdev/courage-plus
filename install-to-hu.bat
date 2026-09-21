@echo off
rem UTF-8 before any Cyrillic byte: cmd must not read this file in cp866.
rem Keep this file CRLF (.gitattributes: *.bat eol=crlf) - LF-only batch dies silently.
chcp 65001 >nul
echo Courage+ 1.0: установка на ГУ через ADB ^(Windows^)
rem Установка Courage+ 1.0 на ГУ VOYAH Courage (岚图知音) через ADB — Windows.
rem Ставит один APK: модель распознавания едет внутри него и распаковывается при первом запуске
rem сервиса (несколько секунд, статус "распаковываю модель из APK" на экране ассистента).
rem Отдельных заливок моделей больше нет — на машине они дважды срывались (docs\results\20260903\).
rem
rem Папка dist\ заморожена как релиз 0.17.1; здесь — мажорная 1.0. adb\win — копия из dist\.
rem На флешку достаточно одной папки dist-1.0\ (см. README.md).
rem
rem Подготовка: включить USB Debugging (инженерное меню), кабель USB-A—USB-A,
rem подтвердить отладку на экране авто.
rem Использование: install-to-hu.bat [путь\к.apk]   (по умолчанию Courage-Plus.apk рядом)
setlocal enabledelayedexpansion
set "DIR=%~dp0"
set "PKG=dev.uzmaster.ucinjector"

rem adb: портативный рядом, иначе из ..\dist\, иначе из PATH.
set "ADB=%DIR%adb\win\adb.exe"
if not exist "%ADB%" set "ADB=%DIR%..\dist\adb\win\adb.exe"
if not exist "%ADB%" set "ADB=adb"

set "APK=%~1"
if "%APK%"=="" set "APK=%DIR%Courage-Plus.apk"
if not exist "%APK%" (
  echo [x] Нет файла: %APK%
  exit /b 1
)

"%ADB%" version >nul 2>nul
if errorlevel 1 (
  echo [x] adb не найден. Ожидался adb\win\adb.exe рядом, в ..\dist\adb\win\ или adb в PATH.
  exit /b 1
)

echo Ожидание ГУ ^(подтверди отладку на экране авто^)...
"%ADB%" wait-for-device
for /f "tokens=*" %%s in ('"%ADB%" get-state 2^>nul') do set "STATE=%%s"
if not "%STATE%"=="device" (
  echo [x] ГУ не готово ^(состояние: %STATE%^). Проверь кабель/порт и USB Debugging.
  exit /b 1
)
echo [ok] ГУ подключено.

rem OEM-блокировка установки — частая причина "App not installed"
"%ADB%" shell setprop sys.config.app_install_disabled false >nul 2>nul

for %%a in ("%APK%") do echo -^> установка %%~nxa ^(~56 МБ вместе с моделью, по USB это до минуты^)
"%ADB%" install -r -g "%APK%" >nul 2>nul
if errorlevel 1 (
  "%ADB%" install -r "%APK%" >nul 2>nul
  if errorlevel 1 (
    echo [x] Установка не прошла. Повтори с выводом: "%ADB%" install -r "%APK%"
    exit /b 1
  ) else (
    echo [ok] Установлено ^(без -g, права выдать вручную^)
  )
) else (
  echo [ok] Установлено
)

rem --- права. Android-user на ГУ обычно 0 (Driver), на AAOS-эмуляторе 10 —
rem     поэтому выдаём и без --user, и на оба id; лишние вызовы молча отпадают.
rem     SYSTEM_ALERT_WINDOW нужен плашке "слушаю": без него вне экрана ассистент не услышит.
call :grants ""
call :grants "--user 0"
call :grants "--user 10"

for /f "tokens=*" %%u in ('"%ADB%" shell am get-current-user 2^>nul') do set "CU=%%u"
echo.
echo Текущий Android-user на ГУ: !CU!
echo Готово. Дальше на экране авто:
echo   1) открыть Courage+ ^(значок в списке приложений^); на замке — код машины -^> ПИН от автора,
echo      там же чеклист: "Модель распознавания" — галочка ^(в составе APK^);
echo   2) значок "Ассистент" — кнопка "Включить" ^(это тумблер сервиса^); первый запуск после
echo      установки распаковывает модель — несколько секунд, статус на экране;
echo      голос вызывается словом "Hi VOYAH" или кнопкой голосового помощника на руле;
echo   3) для рулевого моста — выдать доступ к уведомлениям кнопкой на его экране.
exit /b 0

:grants
"%ADB%" shell appops set %~1 %PKG% SYSTEM_ALERT_WINDOW allow >nul 2>nul
"%ADB%" shell pm grant %~1 %PKG% android.permission.RECORD_AUDIO >nul 2>nul
rem READ_MEDIA_VIDEO - сторож сентри: ролик регистратора к тревоге ищется в MediaStore.
"%ADB%" shell pm grant %~1 %PKG% android.permission.READ_MEDIA_VIDEO >nul 2>nul
rem POST_NOTIFICATIONS - runtime-право с SDK 33: без него уведомления трёх foreground-сервисов
rem (рулевой мост, ассистент, запись "Авто") не показываются, если установка прошла без -g.
"%ADB%" shell pm grant %~1 %PKG% android.permission.POST_NOTIFICATIONS >nul 2>nul
rem WRITE_SECURE_SETTINGS - активация и вычёркивание старой службы микрофона: adb install -g
rem development-права не выдаёт, без явного grant активация упирается в стену.
"%ADB%" shell pm grant %~1 %PKG% android.permission.WRITE_SECURE_SETTINGS >nul 2>nul
rem WRITE_SETTINGS - режим правого блока руля без похода в системный экран.
"%ADB%" shell appops set %~1 %PKG% WRITE_SETTINGS allow >nul 2>nul
goto :eof
