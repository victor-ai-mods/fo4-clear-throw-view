Scriptname CTV:ThrowQuest extends Quest

; Clear Throw View: пока удерживается бросок гранаты, оружие убрано в кобуру, чтобы оно и
; руки не закрывали траекторию. После броска оружие достаётся обратно.
;
; Бросок в Fallout 4 — контрол "Melee" (по умолчанию Alt, на геймпаде RB): короткое
; нажатие — удар прикладом, удержание дольше fThrowDelay:Controls — граната. Оружие
; убирается, когда нажатие становится броском (через fThrowDelay), поэтому удар прикладом
; не страдает. С оружием в кобуре бросок идёт без доставания — траектория видна целиком.
;
; Раздельные клавиши (MCM): fThrowDelay = 0 — клавиша броска только бросает, и оружие
; убирается сразу; удар прикладом — отдельной клавишей MCM (ActionMelee). Значение
; fThrowDelay меняется только в памяти игры и не сохраняется в ini.
;
; Проверено в игре (2026-09-25): PlayIdleAction(ActionSheath) при удержанной клавише
; убирает оружие, и граната всё равно летит при отпускании; GetEquippedWeapon(2) —
; экипированная граната или мина (None, если бросать нечего).

Action Property ActionSheath Auto Const Mandatory
Action Property ActionMelee Auto Const Mandatory
Action Property ActionThrow Auto Const Mandatory

String Property MOD_NAME = "ClearThrowView" AutoReadOnly
String Property CONTROL_THROW = "Melee" AutoReadOnly
String Property THROW_DELAY_INI = "fThrowDelay:Controls" AutoReadOnly
Int Property EQUIP_INDEX_THROWABLE = 2 AutoReadOnly
Int Property TIMER_HOLD = 1 AutoReadOnly
Int Property TIMER_REDRAW = 2 AutoReadOnly
Int Property TIMER_CHECK = 3 AutoReadOnly
Int Property TIMER_VERIFY = 4 AutoReadOnly
Float Property POLL_INTERVAL = 0.1 AutoReadOnly   ; опрос после отпускания
Float Property POLL_LIMIT = 1.5 AutoReadOnly      ; дольше не ждать: бросок либо прошёл, либо повторять нечего
Float Property VERIFY_DELAY = 1.0 AutoReadOnly    ; после повторного броска ActionThrow
Float Property SERIES_GAP = 1.0 AutoReadOnly      ; нажатия чаще — серия быстрых бросков, оружие не трогать
Float Property MIN_HOLD_DELAY = 0.05 AutoReadOnly
Float Property SPLIT_HOLD_DELAY = 0.2 AutoReadOnly ; раздельные клавиши: убирать, если держат дольше
String Property LOG_PATH = ".\\Data\\ClearThrowView\\" AutoReadOnly
String Property LOG_FILE = "ClearThrowView.log" AutoReadOnly
Int Property MAX_LOG_LINES = 100 AutoReadOnly

; --- настройки MCM ---
Bool Enabled = true
Bool Redraw = true
Float RedrawDelay = 1.0
Bool SplitKeys = false
Bool LogEnabled = false

; --- состояние ---
Float OriginalThrowDelay = -1.0     ; fThrowDelay из ini, до обнуления раздельными клавишами
Bool Holding                        ; клавиша броска удерживается
Bool WeHolstered                    ; оружие убрал мод — значит, ему и доставать
Weapon ThrowItem                    ; что было экипировано для броска при нажатии
Int CountBefore                     ; сколько его было при нажатии
Float DownTime
Float HolsterTime
Float UpTime
Float LastPressTime = -100.0        ; прошлое нажатие броска (реальное время)
Float PressGap                      ; пауза перед текущим нажатием
Bool InSeries                       ; текущее нажатие — часть серии быстрых нажатий
Bool PressHolstered                 ; на текущем нажатии мод убрал оружие
Int PressSeq                        ; номер нажатия
Int UpHandledSeq                    ; нажатие, отпускание которого уже обработано
Bool DownDone                       ; обработка текущего нажатия закончена
Bool Released                       ; текущее нажатие уже отпущено
Bool PressActive                    ; текущее нажатие мод отслеживает (есть что бросать и т. д.)
Float HeldTime
Bool ReleasedDrawn                  ; при отпускании оружие ещё в руках — шла анимация убирания
String PollTrace                    ; замеры опроса для лога: время:оружие:кол-во
String[] LogBuf

Event OnQuestInit()
    Setup()
EndEvent

Event Actor.OnPlayerLoadGame(Actor akSender)
    Setup()
EndEvent

Function Setup()
    LogBuf = new String[0]
    RegisterForRemoteEvent(Game.GetPlayer(), "OnPlayerLoadGame")
    RegisterForControl(CONTROL_THROW)
    RegisterForExternalEvent("OnMCMSettingChange|" + MOD_NAME, "OnMCMSettingChange")
    Holding = false
    WeHolstered = false
    LastPressTime = -100.0      ; GetCurrentRealTime считается от запуска игры, а переменная — из сейва
    ; Настоящее значение из ini. 0 — это, скорее всего, наше же обнуление из прошлого сейва
    ; этой сессии: тогда остаётся уже известное.
    Float iniDelay = GardenOfEden.GetINISetting(THROW_DELAY_INI) as Float
    If iniDelay > 0.0
        OriginalThrowDelay = iniDelay
    EndIf
    ReadSettings()
    ApplySplitKeys()
    Log("start: enabled " + Enabled + ", redraw " + Redraw + " after " + RedrawDelay + " s, split keys " + SplitKeys + \
        ", fThrowDelay " + GardenOfEden.GetINISetting(THROW_DELAY_INI) + " (ini " + OriginalThrowDelay + ")")
EndFunction

Function ReadSettings()
    If MCM.IsInstalled()
        Enabled = MCM.GetModSettingBool(MOD_NAME, "bEnabled:Main")
        Redraw = MCM.GetModSettingBool(MOD_NAME, "bRedraw:Main")
        RedrawDelay = MCM.GetModSettingFloat(MOD_NAME, "fRedrawDelay:Main")
        SplitKeys = MCM.GetModSettingBool(MOD_NAME, "bSplitKeys:Main")
        LogEnabled = MCM.GetModSettingBool(MOD_NAME, "bLog:Main")
    EndIf
EndFunction

; MCM: внешнее событие «OnMCMSettingChange|ClearThrowView» (RegisterForExternalEvent, F4SE).
; НЕ ПЕРЕИМЕНОВЫВАТЬ: имя передаётся строкой.
Function OnMCMSettingChange(String asModName, String asId)
    ReadSettings()
    ApplySplitKeys()
    Log("MCM: " + asId + " changed; fThrowDelay " + GardenOfEden.GetINISetting(THROW_DELAY_INI))
EndFunction

; Раздельные клавиши включены — fThrowDelay 0, иначе значение из ini. От переключателя
; «Убирать оружие» (Enabled) не зависит: это отдельная функция.
Function ApplySplitKeys()
    If SplitKeys
        Utility.SetINIFloat(THROW_DELAY_INI, 0.0)
    ElseIf OriginalThrowDelay > 0.0
        Utility.SetINIFloat(THROW_DELAY_INI, OriginalThrowDelay)
    EndIf
EndFunction

; Клавиша удара прикладом из MCM (keybinds.json). НЕ ПЕРЕИМЕНОВЫВАТЬ: вызывается по имени.
Function Bash()
    If Utility.IsInMenuMode()
        Return
    EndIf
    Bool ok = Game.GetPlayer().PlayIdleAction(ActionMelee)
    Log("bash key: ActionMelee " + ok)
EndFunction

; Нажатие и отпускание отмечаются ПЕРВЫМИ строками, до любого вызова наружу: при вызове
; функции другого объекта (Game.GetPlayer(), GetEquippedWeapon…) Papyrus отпускает
; блокировку скрипта, и в этот момент может выполниться OnControlUp. Раньше отпускание
; приходило, пока OnControlDown ещё не выставил Holding, и терялось — без проверки и
; повтора бросок пропадал (видно по логу). Теперь отпускание, пришедшее раньше конца
; обработки нажатия, обрабатывает сам OnControlDown, когда закончит (HandleUp — один раз
; на нажатие, по номеру PressSeq).
Event OnControlDown(String control)
    If control != CONTROL_THROW
        Return
    EndIf
    PressSeq += 1
    Int seq = PressSeq
    Holding = true
    Released = false
    DownDone = false
    PressActive = false
    PressHolstered = false
    HandleDown()
    If seq == PressSeq
        DownDone = true
        If Released
            HandleUp(seq)
        EndIf
    EndIf
EndEvent

Event OnControlUp(String control, Float time)
    If control != CONTROL_THROW
        Return
    EndIf
    Holding = false
    Released = true
    HeldTime = time
    Int seq = PressSeq
    If DownDone
        HandleUp(seq)
    EndIf
EndEvent

Function HandleDown()
    If !Enabled || Utility.IsInMenuMode()
        Return
    EndIf
    Actor player = Game.GetPlayer()
    If !player.GetEquippedWeapon(EQUIP_INDEX_THROWABLE)
        Log("down: nothing to throw")
        Return
    EndIf
    Float now = Utility.GetCurrentRealTime()
    PressGap = now - LastPressTime
    LastPressTime = now
    InSeries = PressGap < SERIES_GAP
    If WeHolstered
        ; Следующий бросок, пока оружие ещё не достали: подождать и его.
        CancelTimer(TIMER_REDRAW)
        CancelTimer(TIMER_CHECK)
        CancelTimer(TIMER_VERIFY)
        If !player.IsWeaponDrawn()
            RememberThrowItem(player)
            PressActive = true
            Log("down: next throw, redraw postponed")
            Return
        EndIf
        ; Оружие снова в руках: ActionThrow бросает с оружием (видно по логу) — убрать заново.
        Log("down: next throw, weapon is drawn again")
    EndIf
    If !player.IsWeaponDrawn()
        Log("down: weapon already holstered")
        Return
    EndIf
    RememberThrowItem(player)
    PressActive = true
    ; Без раздельных клавиш — когда нажатие становится броском (fThrowDelay). С раздельными
    ; бросок начинается сразу, но убирать оружие сразу нельзя: короткое нажатие тогда всегда
    ; срывалось и шло через повтор. Короткие нажатия в логе — 0,05–0,15 с.
    Float delay = SPLIT_HOLD_DELAY
    If !SplitKeys
        delay = OriginalThrowDelay
    EndIf
    If delay < MIN_HOLD_DELAY
        delay = MIN_HOLD_DELAY
    EndIf
    StartTimer(delay, TIMER_HOLD)
EndFunction

Function HandleUp(Int seq)
    If UpHandledSeq == seq
        Return
    EndIf
    UpHandledSeq = seq
    If !PressActive
        Return
    EndIf
    CancelTimer(TIMER_HOLD)
    UpTime = Utility.GetCurrentRealTime()
    Log("up after " + HeldTime + " s, holstered by mod " + WeHolstered + " (" + (UpTime - HolsterTime) + " s after holster)")
    If WeHolstered
        ReleasedDrawn = Game.GetPlayer().IsWeaponDrawn()
        PollTrace = ""
        CheckThrow()
    EndIf
EndFunction

Function RememberThrowItem(Actor player)
    DownTime = Utility.GetCurrentRealTime()
    ThrowItem = player.GetEquippedWeapon(EQUIP_INDEX_THROWABLE)
    CountBefore = player.GetItemCount(ThrowItem)
EndFunction

; Бросок сорвался? Если отпустить клавишу, пока идёт анимация убирания оружия, игра
; отменяет бросок (проверено по логу: отпускание через 0,29–0,36 с после ActionSheath).
; Опрос каждые POLL_INTERVAL после отпускания:
;   граната ушла из инвентаря            -> бросок прошёл сам;
;   отпущено во время убирания, и оружие
;   уже убрано                           -> бросить сразу (ActionThrow);
;   прошло POLL_LIMIT                    -> больше не ждать, ничего не делать.
; Повтора «по таймауту» нет: бросок с оружием в руках уходит через 0,7–0,8 с после
; отпускания, и повтор по времени бросал бы вторую гранату.
; Коротким нажатием (удар, не бросок) это не считается: без раздельных клавиш бросок
; начинается только после fThrowDelay.
Function CheckThrow()
    If Holding
        Return      ; уже новое нажатие — проверит его отпускание (таймер мог прийти после CancelTimer)
    EndIf
    Actor player = Game.GetPlayer()
    Float elapsed = Utility.GetCurrentRealTime() - UpTime
    Bool wasThrow = SplitKeys || HeldTime >= OriginalThrowDelay
    If !wasThrow || !ThrowItem || player.GetEquippedWeapon(EQUIP_INDEX_THROWABLE) != ThrowItem
        Log("check: not a throw (held " + HeldTime + " s)")
        FinishThrow(RedrawDelay - elapsed)
        Return
    EndIf
    Int count = player.GetItemCount(ThrowItem)
    Bool drawn = player.IsWeaponDrawn()
    PollTrace += " " + (Math.Floor(elapsed * 100.0) / 100.0) + ":" + drawn + ":" + count
    If count < CountBefore
        Log("check: thrown by game; released drawn " + ReleasedDrawn + ", " + (UpTime - HolsterTime) + " s after holster; trace" + PollTrace)
        FinishThrow(RedrawDelay - elapsed)
    ElseIf PressHolstered && ReleasedDrawn && !drawn
        Bool ok = player.PlayIdleAction(ActionThrow)
        Log("check: NOT thrown, ActionThrow " + ok + "; released " + (UpTime - HolsterTime) + \
            " s after holster; trace" + PollTrace)
        StartTimer(VERIFY_DELAY, TIMER_VERIFY)
    ElseIf elapsed >= POLL_LIMIT
        Log("check: gave up; released drawn " + ReleasedDrawn + ", " + (UpTime - HolsterTime) + \
            " s after holster; trace" + PollTrace)
        FinishThrow(RedrawDelay - elapsed)
    Else
        StartTimer(POLL_INTERVAL, TIMER_CHECK)
    EndIf
EndFunction

Function FinishThrow(Float afRedrawIn)
    If Redraw
        If afRedrawIn < 0.1
            afRedrawIn = 0.1
        EndIf
        StartTimer(afRedrawIn, TIMER_REDRAW)
    Else
        WeHolstered = false
    EndIf
EndFunction

Event OnTimer(Int aiTimerID)
    If aiTimerID == TIMER_HOLD
        If Holding
            Holster("after hold")
        EndIf
    ElseIf aiTimerID == TIMER_CHECK
        CheckThrow()
    ElseIf aiTimerID == TIMER_VERIFY
        Int left = Game.GetPlayer().GetItemCount(ThrowItem)
        String note = ""
        If left < CountBefore - 1
            note = "  DOUBLE THROW"
        ElseIf left >= CountBefore
            note = "  NO THROW"
        EndIf
        Log("verify: count after ActionThrow " + left + " (was " + CountBefore + ")" + note)
        FinishThrow(RedrawDelay)
    ElseIf aiTimerID == TIMER_REDRAW
        WeHolstered = false
        Actor player = Game.GetPlayer()
        If player.IsWeaponDrawn()
            Log("redraw: already drawn")
        ElseIf Utility.IsInMenuMode()
            Log("redraw: skipped, menu open")
        Else
            player.DrawWeapon()
            Log("redraw: DrawWeapon")
        EndIf
    EndIf
EndEvent

; Только на первом нажатии серии (перед ним SERIES_GAP без нажатий): при частых нажатиях
; каждое новое убирание прерывало уже начатый бросок (видно по логу), и бросок не проходил,
; пока не перестать жать. Пауза «после своего действия» не помогала — истекала посреди серии.
; Во время серии оружие остаётся как есть, броски целиком на игре.
Function Holster(String reason)
    Actor player = Game.GetPlayer()
    If !player.IsWeaponDrawn()
        Return
    EndIf
    If InSeries
        Log("holster (" + reason + "): skipped, " + PressGap + " s after previous press")
        Return
    EndIf
    Float now = Utility.GetCurrentRealTime()
    ; После вызовов наружу клавишу могли уже отпустить — тогда не убирать: бросок уже идёт.
    ; Флаги — до ActionSheath: отпускание во время этого вызова должно увидеть, что оружие
    ; убирается, и запустить проверку броска.
    If !Holding
        Log("holster (" + reason + "): skipped, already released")
        Return
    EndIf
    WeHolstered = true
    PressHolstered = true
    HolsterTime = now
    Bool ok = player.PlayIdleAction(ActionSheath)
    Log("holster (" + reason + ", " + (HolsterTime - DownTime) + " s after down): ActionSheath " + ok)
EndFunction

; Data\ClearThrowView\ClearThrowView.log (Papyrus-лог в игре обычно выключен). Включается
; в MCM. WriteLinesToFile не дописывает, поэтому файл каждый раз пишется целиком из буфера.
Function Log(String text)
    If !LogEnabled
        Return
    EndIf
    If LogBuf == None
        LogBuf = new String[0]
    EndIf
    If LogBuf.Length >= MAX_LOG_LINES
        LogBuf.Remove(0)
    EndIf
    LogBuf.Add(GardenOfEden2.GetCurrentDateAndTimeAsString() + "  " + text)
    GardenOfEden3.WriteLinesToFile(LOG_FILE, LOG_PATH, LogBuf, true)
EndFunction
