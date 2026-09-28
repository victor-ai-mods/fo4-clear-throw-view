# Clear Throw View — чистый обзор при броске

Мод для Fallout 4: пока удерживается клавиша броска, оружие опущено вниз и не закрывает траекторию
гранаты — видно, куда упадёт граната или мина. При отпускании замах и бросок идут как обычно, потом оружие
поднимается. Короткое нажатие, как и раньше, — удар прикладом.

## Как работает

Логика — `papyrus/CTV/ThrowQuest.psc` (квест `CTV_Quest`, Start Game Enabled), поза — клипы из
`tools/gen_anims.py`.

- **Клавиша броска** — игровой контрол `Melee` (по умолчанию Alt, на геймпаде RB), F4SE `RegisterForControl`,
  поэтому работает при любой раскладке. Короткое нажатие — удар, удержание дольше `fThrowDelay:Controls`
  (0,3 с) — граната.
- **Когда опускается оружие**: если в слоте броска (`GetEquippedWeapon(2)`) есть граната или мина, оружие в
  руках и нажатие стало броском (таймер `fThrowDelay`, значение читается из ini через Garden of Eden).
  Опускание — ванильная поза «оружие опущено» (gun down: как у стены или при прицеле на своего),
  `PlayIdleAction(ActionGunDown)` → idle `GunDownFP` графа рук от первого лица. Поза держится, пока клавиша
  зажата; анимация броска начинается только после отпускания и сама возвращает оружие.
- **Клипы позы**: в ванильной позе оружие прижато к груди и всё ещё закрывает точку падения. Мод ставит свои
  `WPNIdleGunDown.hkx` (стоя) и `WPNRunGunDown.hkx` (в движении) для всех видов оружия, обычного тела и
  силовой брони, игры и DLC — 120 клипов. `tools/gen_anims.py` берёт их из архивов игры и опускает кость `COM`
  на 25 единиц: на ней висят корпус, руки и оружие, а камера — отдельная кость от корня. Меняются только
  числа высоты `COM`, остальное — байт в байт ванильное. Побочный эффект: там, где игра опускает оружие сама,
  оно тоже уходит ниже.
- **Оружие ближнего боя**: у их графа позы «оружие опущено» нет (`PlayIdleAction` возвращает false) — мод
  ничего не делает: в ванильном броске такое оружие отводится назад и траекторию не закрывает.
- **Бросок во время другого броска**: пока доигрывает предыдущий бросок, игра позу не включает; мод
  повторяет попытку после его `throwEnd` (до 5 раз по 0,1 с). Отпускание ловится и как контрол, и как
  клавиша (`RegisterForKey`).
- **Раздельные клавиши** (по желанию): `Utility.SetINIFloat("fThrowDelay:Controls", 0)` — только в памяти
  игры, в ini не пишется; клавиша броска бросает сразу, оружие опускается, если её держат дольше 0,2 с.
  Удар — клавиша MCM (`PlayIdleAction(ActionMelee)`). При выключении возвращается значение из ini.

История: 1.0 убирала оружие в кобуру — игра срывала броски, отпущенные во время анимации убирания или
наложившиеся на предыдущий бросок. 1.1 скрывала руки на время прицеливания (`Game.ShowFirstPersonGeometry`)
— работало, но выглядело как сбой анимации. Что ещё проверено и не работает из скрипта: `SetAnimationVariableInt("iSyncGunDown")`,
`PlayAnimation("CullWeapons")`, динамические idle во время удержания (срывают бросок).

## Формат клипов

`tools/hkx.py` — packfile Havok 2014 (64-bit): чтение и запись байт в байт. `tools/hkanim.py` — два формата
анимации, в которых лежат клипы рук от первого лица: `hkaSplineCompressedAnimation` и
`hkaLosslessCompressedAnimation` (раскладка полей — в начале файла); распаковка и сдвиг позиции кости прямо в
данных.

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
| Опускать оружие при прицеливании | вкл. |
| Клавиша броска только бросает (раздельные клавиши) | выкл. |
| Клавиша удара | не назначена |
| Лог (`Data\ClearThrowView\ClearThrowView.log`) | выкл. |

## Сборка

```
python tools/gen_esp.py                # build\ClearThrowView.esp (ESL-флаг, мастер — только Fallout4.esm)
python tools/gen_mcm.py                # mod\MCM\Config\ClearThrowView\*, mod\Interface\Translations\*
python tools/gen_anims.py              # build\anims\Meshes\... — клипы позы из архивов игры (нужна игра с DLC)
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
