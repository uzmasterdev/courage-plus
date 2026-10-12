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
rem Доступ к уведомлениям - рулевому мосту (видеть медиаплееры).
rem Номер Android-user здесь позиционный, без --user; на ГУ 0, на эмуляторе 10.
"%ADB%" shell cmd notification allow_listener %PKG%/%PKG%.wheel.WheelNotificationListener 0 >nul 2>nul
"%ADB%" shell cmd notification allow_listener %PKG%/%PKG%.wheel.WheelNotificationListener 10 >nul 2>nul
rem Исключение из энергосбережения: фоновые сервисы (мост, запись "Авто", сторож сентри, "Два экрана")
rem система не придушит; хранится по имени пакета, переживает обновления. Откат: dumpsys deviceidle whitelist -%PKG%
"%ADB%" shell dumpsys deviceidle whitelist +%PKG% >nul 2>nul
rem Доступ к "Не беспокоить" - запас для автоматизаций; user позиционный, как у allow_listener.
"%ADB%" shell cmd notification allow_dnd %PKG% 0 >nul 2>nul
"%ADB%" shell cmd notification allow_dnd %PKG% 10 >nul 2>nul

rem Проверка главных прав: раньше все сбои глушились, теперь видно, что выдалось.
rem Простые строки: adb на ПК, поиск findstr на ПК, без for /f и кавычек внутри shell.
"%ADB%" shell dumpsys package %PKG% 2>nul | findstr /c:"RECORD_AUDIO: granted=true" >nul && echo [ok] Микрофон для ассистента || echo [^^!] Микрофон не выдан - запусти скрипт ещё раз
"%ADB%" shell dumpsys package %PKG% 2>nul | findstr /c:"DUMP: granted=true" >nul && echo [ok] Доступ к разделению экрана || echo [^^!] Доступ к разделению экрана не выдан - запусти скрипт ещё раз
"%ADB%" shell dumpsys package %PKG% 2>nul | findstr /c:"WRITE_SECURE_SETTINGS: granted=true" >nul && echo [ok] Системные настройки || echo [^^!] Системные настройки не выданы - запусти скрипт ещё раз

for /f "tokens=*" %%u in ('"%ADB%" shell am get-current-user 2^>nul') do set "CU=%%u"
echo.
echo Текущий Android-user на ГУ: !CU!
echo Готово. Дальше на экране авто:
echo   1) открыть Courage+ ^(значок в списке приложений^); на замке — код машины -^> ПИН от автора,
echo      там же чеклист: "Модель распознавания" — галочка ^(в составе APK^);
echo   2) значок "Ассистент" — кнопка "Включить" ^(это тумблер сервиса^); первый запуск после
echo      установки распаковывает модель — несколько секунд, статус на экране;
echo      голос вызывается словом "Hi VOYAH" или кнопкой голосового помощника на руле;
echo   3) доступ к уведомлениям ^(рулевой мост^) выдан установщиком; если нет -
echo      кнопкой на экране рулевого моста.
exit /b 0

:grants
"%ADB%" shell appops set %~1 %PKG% SYSTEM_ALERT_WINDOW allow >nul 2>nul
"%ADB%" shell pm grant %~1 %PKG% android.permission.RECORD_AUDIO >nul 2>nul
rem READ_MEDIA_VIDEO - ролики видеорегистратора ищутся в MediaStore.
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
rem PROJECT_MEDIA - "Снимок экрана" тремя пальцами: запись экрана без системного диалога.
rem Обновившиеся с экрана "Обновления" увидят диалог один раз на первом снимке после старта ГУ.
"%ADB%" shell appops set %~1 %PKG% PROJECT_MEDIA allow >nul 2>nul
rem GET_USAGE_STATS и DUMP - "Два экрана": команды разделения экрана и список задач (сервис дампа
rem проверяет оба; DUMP - development-право, adb install -g его не выдает).
"%ADB%" shell appops set %~1 %PKG% GET_USAGE_STATS allow >nul 2>nul
"%ADB%" shell pm grant %~1 %PKG% android.permission.DUMP >nul 2>nul
rem CAR_SPEED и CAR_ENERGY - запас: скорость, SOC и зарядка через Car API (2026-10-09); выдаем сейчас,
rem чтобы будущей функции хватило обновления. На прошивке без этих прав строка молча отпадет.
"%ADB%" shell pm grant %~1 %PKG% android.car.permission.CAR_SPEED >nul 2>nul
"%ADB%" shell pm grant %~1 %PKG% android.car.permission.CAR_ENERGY >nul 2>nul
rem CHANGE_CONFIGURATION - запас: язык отдельного приложения; кодом пока не используется.
"%ADB%" shell pm grant %~1 %PKG% android.permission.CHANGE_CONFIGURATION >nul 2>nul
rem ACCESS_RESTRICTED_SETTINGS - страховка ручного пути: доступ к уведомлениям и спец.возможности
rem Courage+ можно включить в настройках Android без блокировки Android 13.
"%ADB%" shell appops set %~1 %PKG% ACCESS_RESTRICTED_SETTINGS allow >nul 2>nul
rem appwidget grantbind - запас под свой лаунчер: встраивать чужие виджеты без системного диалога.
"%ADB%" shell appwidget grantbind --package %PKG% %~1 >nul 2>nul
rem Запас под лаунчер и будущие функции (2026-10-12). Только простые строки: без скобок, пайпов и
rem восклицательных знаков - сложная логика уже ломала этот скрипт у клиентов.
rem Не отзывать права у давно не открытого приложения.
"%ADB%" shell appops set %~1 %PKG% AUTO_REVOKE_PERMISSIONS_IF_UNUSED ignore >nul 2>nul
rem Медиаклавиши и долгое нажатие громкости.
"%ADB%" shell pm grant %~1 %PKG% android.permission.SET_MEDIA_KEY_LISTENER >nul 2>nul
"%ADB%" shell pm grant %~1 %PKG% android.permission.SET_VOLUME_KEY_LONG_PRESS_LISTENER >nul 2>nul
rem Самодиагностика прав.
"%ADB%" shell pm grant %~1 %PKG% android.permission.GET_APP_OPS_STATS >nul 2>nul
rem Голосовой набор и телефон: контакты, звонки, журнал вызовов.
"%ADB%" shell pm grant %~1 %PKG% android.permission.READ_CONTACTS >nul 2>nul
"%ADB%" shell pm grant %~1 %PKG% android.permission.CALL_PHONE >nul 2>nul
"%ADB%" shell pm grant %~1 %PKG% android.permission.ANSWER_PHONE_CALLS >nul 2>nul
"%ADB%" shell pm grant %~1 %PKG% android.permission.READ_CALL_LOG >nul 2>nul
"%ADB%" shell pm grant %~1 %PKG% android.permission.CAMERA >nul 2>nul
rem VPN без системного диалога.
"%ADB%" shell appops set %~1 %PKG% ACTIVATE_VPN allow >nul 2>nul
goto :eof
