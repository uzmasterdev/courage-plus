@echo off
rem UTF-8 before any Cyrillic byte: cmd must not read this file in cp866.
rem Keep this file CRLF (.gitattributes: *.bat eol=crlf) - LF-only batch dies silently.
chcp 65001 >nul
echo Courage+ 1.0: установка на ГУ через ADB ^(Windows^)
rem Установка Courage+ 1.0 на ГУ VOYAH Courage (岚图知音) через ADB — Windows.
rem Ставит один APK: модель распознавания едет внутри него и распаковывается при первом запуске
rem сервиса (несколько секунд, статус "распаковываю модель из APK" на экране ассистента).
rem Отдельных заливок моделей больше нет — на машине они дважды срывались (docs\results\20260903\).
rem Рядом в adb\ лежит mega-installer.apk — отдельный установщик приложений (com.mega.appstore):
rem без него "Магазин" и "Обновления" Courage+ ничего поставить не могут. Скрипт ставит его, если
rem на ГУ такого пакета нет или его versionCode ниже INSTALLER_MIN_CODE (тогда ставит поверх);
rem свежий не трогает. Право REQUEST_INSTALL_PACKAGES выдаёт ему при каждом запуске.
rem На флешку достаточно одной папки dist-1.0\ (см. README.md).
rem
rem Подготовка: включить USB Debugging (инженерное меню), кабель USB-A—USB-A,
rem подтвердить отладку на экране авто.
rem Использование: install-to-hu.bat [путь\к.apk]   (по умолчанию Courage-Plus.apk рядом)
rem Под enabledelayedexpansion "!" в echo съедается: маркер предупреждения пишется как [^^!].
setlocal enabledelayedexpansion
set "DIR=%~dp0"
set "PKG=dev.uzmaster.ucinjector"
set "INSTALLER_PKG=com.mega.appstore"
set "INSTALLER_APK=%DIR%adb\mega-installer.apk"
set "INSTALLER_MIN_CODE=3"

rem adb: портативный рядом (adb\win\adb.exe), иначе из PATH.
set "ADB=%DIR%adb\win\adb.exe"
if not exist "%ADB%" set "ADB=adb"

set "APK=%~1"
if "%APK%"=="" set "APK=%DIR%Courage-Plus.apk"
if not exist "%APK%" (
  echo [x] Нет файла: %APK%
  exit /b 1
)

"%ADB%" version >nul 2>nul
if errorlevel 1 (
  echo [x] adb не найден. Ожидался adb\win\adb.exe рядом или adb в PATH.
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

rem Установщик приложений для "Магазина" и "Обновлений": ставится, если его нет или он старее
rem INSTALLER_MIN_CODE ^(1.2 = 3: принимает файлы только от Courage+; 1.1 ставил от любого^).
set "INSTALLER_PATH="
for /f "tokens=*" %%p in ('"%ADB%" shell pm path %INSTALLER_PKG% 2^>nul') do set "INSTALLER_PATH=%%p"
set "INSTALLER_CODE=0"
rem Внутри for /f — ровно две кавычки: при большем числе cmd /c срезает крайние и ломает вызов.
for /f "tokens=2 delims== " %%v in ('"%ADB%" shell dumpsys package %INSTALLER_PKG% 2^>nul ^| findstr versionCode') do if "!INSTALLER_CODE!"=="0" set "INSTALLER_CODE=%%v"
set "INSTALLER_OK="
if not "!INSTALLER_PATH!"=="" if !INSTALLER_CODE! GEQ %INSTALLER_MIN_CODE% set "INSTALLER_OK=1"
if defined INSTALLER_OK (
  echo [ok] Установщик приложений уже стоит
) else if exist "%INSTALLER_APK%" (
  if not "!INSTALLER_PATH!"=="" (
    echo -^> обновление установщика приложений ^(стоит версия !INSTALLER_CODE!, нужна %INSTALLER_MIN_CODE%^)
  ) else (
    echo -^> установка установщика приложений ^(mega-installer.apk^)
  )
  "%ADB%" install -r "%INSTALLER_APK%" >nul 2>nul
  if errorlevel 1 (
    echo [^^!] Установщик приложений не установился — "Магазин" и "Обновления" в Courage+ ставить не смогут.
    echo     Повтори с выводом: "%ADB%" install -r "%INSTALLER_APK%"
  ) else (
    echo [ok] Установщик приложений установлен
  )
) else (
  echo [^^!] Рядом нет adb\mega-installer.apk — "Магазин" и "Обновления" в Courage+ ставить не смогут.
)
rem Право установщика ставить приложения: без него система отвечает "For your security..."
rem ^(эмулятор 2026-09-28^). appop переживает перезагрузку; лишние --user молча отпадают.
"%ADB%" shell appops set %INSTALLER_PKG% REQUEST_INSTALL_PACKAGES allow >nul 2>nul
"%ADB%" shell appops set --user 0 %INSTALLER_PKG% REQUEST_INSTALL_PACKAGES allow >nul 2>nul
"%ADB%" shell appops set --user 10 %INSTALLER_PKG% REQUEST_INSTALL_PACKAGES allow >nul 2>nul

rem Перевод интерфейса (служба спец.возможностей): после install -r система её не привязывает,
rem приложение само прогоняет цикл "вычеркнуть -> вписать". Запоминаем, была ли служба включена, —
rem только тогда после установки ждём привязки. Список служб скрипт сам не пишет: гонка с приложением.
rem TRANSLATE=1 - только если в сборке включён перевод (BuildConfig.TRANSLATE в app/build.gradle);
rem в 1.5.5 он выключен: служба выключена в манифесте, ждать её привязки нечего.
set "TRANSLATE=0"
set "TR_WAS_ON="
if not "%TRANSLATE%"=="1" goto :tr_skip
"%ADB%" shell "settings get secure enabled_accessibility_services | tr ':' '\n' | grep %PKG%/ | grep TranslateService" 2>nul | findstr /c:"TranslateService" >nul
if not errorlevel 1 set "TR_WAS_ON=1"
:tr_skip

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

rem Перевод интерфейса: ждём, пока приложение (по MY_PACKAGE_REPLACED, обычно 5-20 с) вернёт службу;
rem не успело - сон/пробуждение экрана: приложение запомнит его, даже если цикл ещё идёт.
rem Не вышло — сон/пробуждение экрана: по USER_PRESENT приложение повторит цикл.
if defined TR_WAS_ON (
  echo -^> перевод интерфейса: жду, пока система подключит службу...
  call :trwait 25
  if errorlevel 1 (
    rem экран выкл, пауза, экран вкл: по USER_PRESENT приложение повторит цикл
    "%ADB%" shell input keyevent 223 >nul 2>nul
    ping -n 3 127.0.0.1 >nul
    "%ADB%" shell input keyevent 224 >nul 2>nul
    ping -n 2 127.0.0.1 >nul
    call :trwait 20
  )
  if errorlevel 1 (
    echo [^^!] Перевод интерфейса не подключился: открой Courage+ → Настройки → Перевод интерфейса
  ) else (
    echo [ok] Перевод интерфейса работает
  )
)

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
rem MANAGE_EXTERNAL_STORAGE - "Магазин" и "Обновления" читают .apk из "Загрузок" и с флешки;
rem без него общее хранилище приложению не видно вовсе.
"%ADB%" shell appops set %~1 %PKG% MANAGE_EXTERNAL_STORAGE allow >nul 2>nul
goto :eof

rem Ждать привязки службы перевода до %1 секунд, опрос раз в 2 с; errorlevel 0 — привязана.
rem Признак: подпись "Courage+" в блоке "Bound services" (до "Enabled services", где служба есть
rem и непривязанной). Компонента там нет, только подпись; ServiceRecord живёт и у ждущей службы.
:trwait
set /a TR_LEFT=%~1
:trwait_loop
"%ADB%" shell "dumpsys accessibility | sed -n '/Enabled services/q;/Bound services/,$p'" 2>nul | findstr /c:"Courage+" >nul
if not errorlevel 1 exit /b 0
if !TR_LEFT! LEQ 0 exit /b 1
ping -n 3 127.0.0.1 >nul
set /a TR_LEFT-=2
goto trwait_loop
