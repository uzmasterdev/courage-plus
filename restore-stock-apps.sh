#!/usr/bin/env bash
# Вернуть штатные приложения ГУ, выключенные страницей Courage+ «Приложения › Штатные»
# (docs/stock-apps.md). Нужен, если Courage+ удалён, не открывается или заменён версией без этой
# функции; иначе приложения возвращает сам Courage+ — тумблером или кнопкой «Вернуть все».
# Включает все пакеты каталога (stockapps.StockAppsCatalog) — и выключенные не через Courage+.
# Метку courage_stockapps_off скрипт не стирает: номер последнего запроса в ней не даёт рабочему
# столу повторить старый запрос; выключенные снова приложения рабочий стол уберёт из метки сам.
# В install-to-hu.* этого нет намеренно: установщик запускают и при обновлении — он вернул бы
# приложения тем, кто их выключил.
# Использование: ./restore-stock-apps.sh   (adb — из PATH или ADB=/path/to/adb)
set -u
ADB="${ADB:-adb}"
# Список совпадает с каталогом (StockAppsScriptsTest).
PKGS="com.tencent.qqlive.audiobox com.arcvideo.car.iqy.video cn.cmvideo.car.play"
command -v "$ADB" >/dev/null 2>&1 || { echo "[x] adb не найден в PATH (или укажи ADB=/path/to/adb)"; exit 1; }
echo "Ожидание ГУ (подтверди отладку на экране авто)..."
"$ADB" wait-for-device
left=0
for PKG in $PKGS; do
  "$ADB" shell pm enable --user 0 "$PKG" >/dev/null 2>&1
done
DISABLED="$("$ADB" shell pm list packages -d 2>/dev/null | tr -d '\r')"
for PKG in $PKGS; do
  if printf '%s\n' "$DISABLED" | grep -qx "package:$PKG"; then
    echo "[x] Не включился: $PKG — пришлите вывод: $ADB shell pm enable --user 0 $PKG"
    left=1
  fi
done
if [ "$left" -eq 0 ]; then
  echo "[ok] Штатные приложения из списка Courage+ включены (каких нет на этой прошивке — пропущены)."
  exit 0
fi
exit 1
