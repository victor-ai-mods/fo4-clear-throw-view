# Clear Throw View — чистый обзор при броске

Мод для Fallout 4: пока удерживается клавиша броска, руки и оружие скрыты и не закрывают траекторию
гранаты — видно, куда упадёт граната или мина. При отпускании руки возвращаются, и замах виден как обычно.
Короткое нажатие, как и раньше, — удар прикладом.

## Как работает

Вся логика — `papyrus/CTV/ThrowQuest.psc` (квест `CTV_Quest`, Start Game Enabled).

- **Клавиша броска** — игровой контрол `Melee` (по умолчанию Alt, на геймпаде RB), F4SE `RegisterForControl`,
  поэтому работает при любой раскладке. Короткое нажатие — удар, удержание дольше `fThrowDelay:Controls`
  (0,3 с) — граната.
- **Когда скрываются руки**: если в слоте броска (`GetEquippedWeapon(2)`) есть граната или мина и нажатие
  стало броском (таймер `fThrowDelay`, значение читается из ini через Garden of Eden). Скрытие — ванильная
  `Game.ShowFirstPersonGeometry(false)`, возврат — при отпускании клавиши. Анимация броска (замах рукой)
  начинается только после отпускания, поэтому она видна целиком.
- **Страховки**: руки возвращаются при открытии меню (Pip-Boy, пауза, избранное…), загрузке сохранения,
  выключении мода в MCM; пока руки скрыты, каждые 0,25 с проверяется, что клавиша ещё держится. Отпускание
  ловится и как контрол, и как клавиша (`RegisterForKey` на клавиши контрола).
- **Раздельные клавиши** (по желанию): `Utility.SetINIFloat("fThrowDelay:Controls", 0)` — только в памяти
  игры, в ini не пишется; клавиша броска бросает сразу, руки скрываются, если её держат дольше 0,2 с.
  Удар — клавиша MCM (`PlayIdleAction(ActionMelee)`). При выключении возвращается значение из ini.

Версия 1.0 убирала оружие в кобуру. Игра срывала броски, отпущенные во время анимации убирания или
наложившиеся на предыдущий бросок, а мод потом доставал оружие обратно — от всего этого 1.1 избавлена.

Особенность Papyrus: вызов функции другого объекта (`Game.GetPlayer()`, `GetEquippedWeapon`…) отпускает
блокировку скрипта, и `OnControlUp` может выполниться посреди `OnControlDown`. Поэтому оба события первыми
строками отмечают нажатие/отпускание, а отпускание, пришедшее раньше конца обработки нажатия, обрабатывает
сам `OnControlDown` (номер нажатия `PressSeq`).

## Требования

- F4SE (со скриптами: `RegisterForControl`, `RegisterForExternalEvent`)
- Mod Configuration Menu (MCM)
- Garden of Eden Papyrus Script Extender (`GetINISetting`, запись лога)

Проверено на версии игры 1.10.163 (до Next-Gen). DLC не нужны.

## Настройки (MCM → Clear Throw View)

| Настройка | По умолчанию |
|---|---|
| Скрывать руки при прицеливании | вкл. |
| Клавиша броска только бросает (раздельные клавиши) | выкл. |
| Клавиша удара | не назначена |
| Лог (`Data\ClearThrowView\ClearThrowView.log`) | выкл. |

## Сборка

```
python tools/gen_esp.py                # build\ClearThrowView.esp (ESL-флаг, мастер — только Fallout4.esm)
python tools/gen_mcm.py                # mod\MCM\Config\ClearThrowView\*, mod\Interface\Translations\*
"<игра>\Papyrus Compiler\PapyrusCompiler.exe" papyrus ^
    -i="papyrus;<F4SE Scripts\Source>;<игра>\Data\Scripts\Source\User;<игра>\Data\Scripts\Source\Base" ^
    -o="build\scripts" -f="Institute_Papyrus_Flags.flg" -all
python tools/deploy.py                 # в игру (оба Plugins.txt); --remove — убрать
python tools/gen_cover.py              # images\cover.png, images\banner.png из vanila.png и mod.png
```

`<F4SE Scripts\Source>` — `Data\Scripts\Source` из архива F4SE (объявления `RegisterForControl` и др.).
В `Data\Scripts\Source\User` должны быть `MCM.psc` и `GardenOfEden*.psc`.

Папка `mod\ClearThrowView\` с `ReadMe.txt` нужна для лога: Garden of Eden не создаёт папки сам.

## Лицензия

The Unlicense — общественное достояние. Сделано с помощью Claude Code.
