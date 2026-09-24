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
Float Property CHECK_DELAY = 0.8 AutoReadOnly     ; после отпускания: граната уже должна уйти из инвентаря
Float Property VERIFY_DELAY = 1.0 AutoReadOnly    ; после повторного броска ActionThrow
Float Property MIN_HOLD_DELAY = 0.05 AutoReadOnly
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
Float HeldTime
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

Event OnControlDown(String control)
    If control != CONTROL_THROW || !Enabled || Utility.IsInMenuMode()
        Return
    EndIf
    Actor player = Game.GetPlayer()
    If !player.GetEquippedWeapon(EQUIP_INDEX_THROWABLE)
        Log("down: nothing to throw")
        Return
    EndIf
    If WeHolstered
        ; Следующий бросок, пока оружие ещё не достали: подождать и его.
        CancelTimer(TIMER_REDRAW)
        CancelTimer(TIMER_CHECK)
        CancelTimer(TIMER_VERIFY)
        RememberThrowItem(player)
        Holding = true
        Log("down: next throw, redraw postponed")
        Return
    EndIf
    If !player.IsWeaponDrawn()
        Log("down: weapon already holstered")
        Return
    EndIf
    RememberThrowItem(player)
    Holding = true
    If SplitKeys
        Holster("on press")
    Else
        Float delay = OriginalThrowDelay
        If delay < MIN_HOLD_DELAY
            delay = MIN_HOLD_DELAY
        EndIf
        StartTimer(delay, TIMER_HOLD)
    EndIf
EndEvent

Event OnControlUp(String control, Float time)
    If control != CONTROL_THROW || !Holding
        Return
    EndIf
    Holding = false
    CancelTimer(TIMER_HOLD)
    UpTime = Utility.GetCurrentRealTime()
    HeldTime = time
    Log("up after " + time + " s, holstered by mod " + WeHolstered + " (" + (UpTime - HolsterTime) + " s after holster)")
    If WeHolstered
        StartTimer(CHECK_DELAY, TIMER_CHECK)
    EndIf
EndEvent

Function RememberThrowItem(Actor player)
    DownTime = Utility.GetCurrentRealTime()
    ThrowItem = player.GetEquippedWeapon(EQUIP_INDEX_THROWABLE)
    CountBefore = player.GetItemCount(ThrowItem)
EndFunction

; Бросок сорвался? Если отпустить клавишу, пока идёт анимация убирания оружия, игра
; отменяет бросок. Признак — граната не ушла из инвентаря. Коротким нажатием (удар, не
; бросок) это не считается: без раздельных клавиш бросок начинается только после fThrowDelay.
Function CheckThrow()
    Actor player = Game.GetPlayer()
    Bool wasThrow = SplitKeys || HeldTime >= OriginalThrowDelay
    Int count = player.GetItemCount(ThrowItem)
    If wasThrow && ThrowItem && count >= CountBefore && player.GetEquippedWeapon(EQUIP_INDEX_THROWABLE) == ThrowItem
        Bool ok = player.PlayIdleAction(ActionThrow)
        Log("check: NOT thrown (count " + count + "), released " + (UpTime - HolsterTime) + " s after holster; ActionThrow " + ok)
        StartTimer(VERIFY_DELAY, TIMER_VERIFY)
    Else
        Log("check: ok (count " + CountBefore + " -> " + count + ", was throw " + wasThrow + ")")
        FinishThrow(RedrawDelay - CHECK_DELAY)
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
        Log("verify: count after ActionThrow " + Game.GetPlayer().GetItemCount(ThrowItem) + " (was " + CountBefore + ")")
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

Function Holster(String reason)
    Actor player = Game.GetPlayer()
    If !player.IsWeaponDrawn()
        Return
    EndIf
    Bool ok = player.PlayIdleAction(ActionSheath)
    WeHolstered = true
    HolsterTime = Utility.GetCurrentRealTime()
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
