#!/usr/bin/env bash
# Установка Courage+ 1.0 на ГУ VOYAH Courage (岚图知音) через ADB — macOS/Linux.
# Ставит один APK: модель распознавания едет внутри него и распаковывается при первом запуске
# сервиса (несколько секунд, статус «распаковываю модель из APK» на экране ассистента).
# Отдельных заливок моделей больше нет — на машине они дважды срывались (docs/results/20260903/).
#
# ⚠️ Папка dist/ заморожена как релиз 0.17.1; здесь — мажорная 1.0. adb/win — копия из dist/.
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
done

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
