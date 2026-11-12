#!/usr/bin/env bash
# Вернуть штатный музыкальный плеер ГУ (com.voyah.cockpit.voyahmusic), выключенный функцией
# Courage+ «Кнопка музыки» (docs/dock-music.md). Нужен, если Courage+ удалён, не открывается или
# заменён версией без этой функции; иначе плеер возвращает сам Courage+ — выключите тумблер или
# нажмите «Вернуть штатный плеер».
# Скрипт ещё и блокирует функцию (courage_dockmusic_block): иначе стоящий Courage+ с включённым
# тумблером мог бы выключить плеер снова. Снять блокировку — выключить и включить тумблер на экране.
# В install-to-hu.* этого нет намеренно: установщик запускают и при обновлении — он вернул бы
# плеер тем, кто его выключил.
# Использование: ./restore-stock-music.sh   (adb — из PATH или ADB=/path/to/adb)
set -u
ADB="${ADB:-adb}"
PKG=com.voyah.cockpit.voyahmusic
command -v "$ADB" >/dev/null 2>&1 || { echo "[x] adb не найден в PATH (или укажи ADB=/path/to/adb)"; exit 1; }
echo "Ожидание ГУ (подтверди отладку на экране авто)..."
"$ADB" wait-for-device
"$ADB" shell settings put global courage_dockmusic_block 1 >/dev/null 2>&1
"$ADB" shell pm enable --user 0 $PKG
"$ADB" shell settings delete global courage_dockmusic_off >/dev/null 2>&1
if "$ADB" shell pm list packages -e 2>/dev/null | tr -d '\r' | grep -qx "package:$PKG"; then
  echo "[ok] Штатный плеер включён. Функция «Кнопка музыки» заблокирована до нового включения тумблера."
  exit 0
fi
echo "[x] Плеер не включился — пришлите вывод: $ADB shell pm enable --user 0 $PKG"
exit 1
