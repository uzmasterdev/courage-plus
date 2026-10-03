#!/usr/bin/env bash
# Установка Courage+ 1.0 на ГУ VOYAH Courage (岚图知音) через ADB — macOS/Linux.
# Ставит один APK: модель распознавания едет внутри него и распаковывается при первом запуске
# сервиса (несколько секунд, статус «распаковываю модель из APK» на экране ассистента).
# Отдельных заливок моделей больше нет — на машине они дважды срывались (docs/results/20260903/).
# Рядом в adb/ лежит mega-installer.apk — отдельный установщик приложений (com.mega.appstore):
# без него «Магазин» и «Обновления» Courage+ ничего поставить не могут. Скрипт ставит его, если
# на ГУ такого пакета нет или его versionCode ниже INSTALLER_MIN_CODE (тогда ставит поверх);
# свежий не трогает. Право REQUEST_INSTALL_PACKAGES выдаёт ему при каждом запуске.
#
# adb берётся из PATH (бандл adb/win/adb.exe — только под Windows).
# Подготовка: включить USB Debugging (инженерное меню), кабель USB-A—USB-A,
# подтвердить отладку на экране авто.
# Использование: ./install-to-hu.sh [путь/к.apk]   (по умолчанию Courage-Plus.apk рядом)
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
ADB="${ADB:-adb}"
APK="${1:-$DIR/Courage-Plus.apk}"
PKG=dev.uzmaster.ucinjector
INSTALLER_PKG=com.mega.appstore
INSTALLER_APK="$DIR/adb/mega-installer.apk"
INSTALLER_MIN_CODE=3

[ -f "$APK" ] || { echo "[x] Нет файла: $APK"; exit 1; }
command -v "$ADB" >/dev/null 2>&1 || {
  echo "[x] adb не найден в PATH. Поставь platform-tools (brew install android-platform-tools)"
  echo "    или укажи путь: ADB=/path/to/adb ./install-to-hu.sh"
  exit 1
}

echo "Ожидание ГУ (подтверди отладку на экране авто)..."
"$ADB" wait-for-device
STATE=$("$ADB" get-state 2>/dev/null | tr -d '\r')
[ "$STATE" = "device" ] || { echo "[x] ГУ не готово (состояние: $STATE). Проверь кабель/порт и USB Debugging."; exit 1; }
echo "[ok] ГУ подключено."

# OEM-блокировка установки — частая причина "App not installed"
"$ADB" shell setprop sys.config.app_install_disabled false >/dev/null 2>&1

# Установщик приложений для «Магазина» и «Обновлений»: ставится, если его нет или он старее
# INSTALLER_MIN_CODE (1.2 = 3: принимает файлы только от Courage+; 1.1 ставил от любого приложения).
# Свежий или новее — не трогаем.
INSTALLER_PATH=$("$ADB" shell pm path $INSTALLER_PKG 2>/dev/null | tr -d '\r')
INSTALLER_CODE=$("$ADB" shell dumpsys package $INSTALLER_PKG 2>/dev/null | tr -d '\r' \
  | sed -n 's/.*versionCode=\([0-9][0-9]*\).*/\1/p' | head -1)
if [ -n "$INSTALLER_PATH" ] && [ "${INSTALLER_CODE:-0}" -ge "$INSTALLER_MIN_CODE" ]; then
  echo "[ok] Установщик приложений уже стоит"
elif [ -f "$INSTALLER_APK" ]; then
  if [ -n "$INSTALLER_PATH" ]; then
    echo "-> обновление установщика приложений (стоит версия ${INSTALLER_CODE:-?}, нужна $INSTALLER_MIN_CODE)"
  else
    echo "-> установка установщика приложений ($(basename "$INSTALLER_APK"))"
  fi
  if "$ADB" install -r "$INSTALLER_APK" >/dev/null 2>&1; then
    echo "[ok] Установщик приложений установлен"
  else
    echo "[!] Установщик приложений не установился — «Магазин» и «Обновления» в Courage+ ставить не смогут."
    echo "    Повтори с выводом: $ADB install -r \"$INSTALLER_APK\""
  fi
else
  echo "[!] Рядом нет adb/mega-installer.apk — «Магазин» и «Обновления» в Courage+ ставить не смогут."
fi
# Право установщика ставить приложения: без него система отвечает «For your security…»
# (эмулятор 2026-09-28). appop переживает перезагрузку; лишние --user молча отпадают.
for U in "" "--user 0" "--user 10"; do
  # shellcheck disable=SC2086
  "$ADB" shell appops set $U $INSTALLER_PKG REQUEST_INSTALL_PACKAGES allow >/dev/null 2>&1
done

# Перевод интерфейса (служба спец.возможностей): после install -r система её не привязывает,
# приложение само прогоняет цикл «вычеркнуть → вписать». Запоминаем, была ли служба включена, —
# только тогда после установки ждём привязки. Список служб скрипт сам не пишет: гонка с приложением.
# TRANSLATE=1 — только если в сборке включён перевод (BuildConfig.TRANSLATE в app/build.gradle);
# в 1.5.5 он выключен: служба выключена в манифесте, ждать её привязки нечего.
TRANSLATE=0
TR_WAS_ON=
if [ "$TRANSLATE" = 1 ] && "$ADB" shell "settings get secure enabled_accessibility_services | tr ':' '\n' | grep $PKG/ | grep TranslateService" 2>/dev/null \
    | grep -q TranslateService; then
  TR_WAS_ON=1
fi

# Привязана ли служба: её подпись «Courage+ · …» в блоке «Bound services» (до «Enabled services»,
# где она стоит и непривязанной). Компонента в блоке нет — только подпись (эмулятор 4.3.1,
# 2026-10-02); ServiceRecord не годится — он живёт и у службы, ждущей перезапуска.
tr_bound() {
  "$ADB" shell "dumpsys accessibility | sed -n '/Enabled services/q;/Bound services/,\$p'" 2>/dev/null \
    | grep -q "Courage+"
}
# Ждать привязки до $1 секунд, опрос раз в 2 с.
tr_wait() {
  local left=$1
  while ! tr_bound; do
    [ "$left" -le 0 ] && return 1
    sleep 2
    left=$((left - 2))
  done
}

echo "-> установка $(basename "$APK") (~56 МБ вместе с моделью, по USB это до минуты)"
if "$ADB" install -r -g "$APK" >/dev/null 2>&1; then
  echo "[ok] Установлено"
elif "$ADB" install -r "$APK" >/dev/null 2>&1; then
  echo "[ok] Установлено (без -g, права выдать вручную)"
else
  echo "[x] Установка не прошла. Повтори с выводом: $ADB install -r \"$APK\""
  exit 1
fi

# Права. Android-user на ГУ обычно 0 (Driver), на AAOS-эмуляторе 10 —
# выдаём и без --user, и на оба id; лишние вызовы молча отпадают.
# SYSTEM_ALERT_WINDOW нужен плашке «слушаю»: без него вне экрана ассистент не услышит.
for U in "" "--user 0" "--user 10"; do
  # shellcheck disable=SC2086
  "$ADB" shell appops set $U $PKG SYSTEM_ALERT_WINDOW allow >/dev/null 2>&1
  # shellcheck disable=SC2086
  "$ADB" shell pm grant $U $PKG android.permission.RECORD_AUDIO >/dev/null 2>&1
  # READ_MEDIA_VIDEO — сторож сентри: ролик регистратора к тревоге ищется в MediaStore.
  # shellcheck disable=SC2086
  "$ADB" shell pm grant $U $PKG android.permission.READ_MEDIA_VIDEO >/dev/null 2>&1
  # POST_NOTIFICATIONS — runtime-право с SDK 33: без него уведомления трёх foreground-сервисов
  # (рулевой мост, ассистент, запись «Авто») не показываются, если установка прошла без -g.
  # shellcheck disable=SC2086
  "$ADB" shell pm grant $U $PKG android.permission.POST_NOTIFICATIONS >/dev/null 2>&1
  # WRITE_SECURE_SETTINGS — активация («① Подтвердить») и вычёркивание старой службы микрофона:
  # adb install -g development-права не выдаёт, без явного grant активация упирается в стену.
  # shellcheck disable=SC2086
  "$ADB" shell pm grant $U $PKG android.permission.WRITE_SECURE_SETTINGS >/dev/null 2>&1
  # WRITE_SETTINGS — режим правого блока руля без похода в системный экран.
  # shellcheck disable=SC2086
  "$ADB" shell appops set $U $PKG WRITE_SETTINGS allow >/dev/null 2>&1
  # MANAGE_EXTERNAL_STORAGE — «Магазин» и «Обновления» читают .apk из «Загрузок» и с флешки;
  # без него общее хранилище приложению не видно вовсе (эмулятор 2026-09-21).
  # shellcheck disable=SC2086
  "$ADB" shell appops set $U $PKG MANAGE_EXTERNAL_STORAGE allow >/dev/null 2>&1
done

# Перевод интерфейса: ждём, пока приложение (по MY_PACKAGE_REPLACED, обычно 5-20 с) вернёт службу;
# не успело - сон/пробуждение экрана: приложение запомнит его, даже если цикл ещё идёт.
# Не вышло — сон/пробуждение экрана: по USER_PRESENT приложение повторит цикл.
if [ -n "$TR_WAS_ON" ]; then
  echo "-> перевод интерфейса: жду, пока система подключит службу..."
  if tr_wait 25 || {
    "$ADB" shell input keyevent 223 >/dev/null 2>&1   # экран выкл
    sleep 2
    "$ADB" shell input keyevent 224 >/dev/null 2>&1   # экран вкл → USER_PRESENT
    sleep 1
    tr_wait 20
  }; then
    echo "[ok] Перевод интерфейса работает"
  else
    echo "[!] Перевод интерфейса не подключился: открой Courage+ → Настройки → Перевод интерфейса"
  fi
fi

CU=$("$ADB" shell am get-current-user 2>/dev/null | tr -d '\r')
cat <<EOT

Текущий Android-user на ГУ: ${CU:-неизвестен}
Готово. Дальше на экране авто:
  1) открыть Courage+ (значок в списке приложений); на замке — код машины → ПИН от автора,
     там же чеклист: «Модель распознавания» — ✅ (в составе APK);
  2) значок 🎙 «Ассистент» — кнопка «Включить» (это тумблер сервиса); первый запуск после
     установки распаковывает модель — несколько секунд, статус на экране;
     голос вызывается словом «Hi VOYAH» или кнопкой голосового помощника на руле;
  3) для рулевого моста — выдать доступ к уведомлениям кнопкой на его экране.
EOT
