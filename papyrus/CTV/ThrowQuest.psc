Scriptname CTV:ThrowQuest extends Quest

; Clear Throw View: пока удерживается бросок гранаты, руки и оружие от первого лица скрыты
; (Game.ShowFirstPersonGeometry), чтобы они не закрывали траекторию. Сам бросок (замах
; рукой) виден: руки возвращаются при отпускании клавиши.
;
; Бросок в Fallout 4 — контрол "Melee" (по умолчанию Alt, на геймпаде RB): короткое
; нажатие — удар прикладом, удержание дольше fThrowDelay:Controls — граната. Руки
; скрываются, когда нажатие становится броском (через fThrowDelay), поэтому удар прикладом
; не страдает.
;
; Раздельные клавиши (MCM): fThrowDelay = 0 — клавиша броска только бросает; удар
; прикладом — отдельной клавишей MCM (ActionMelee). Значение fThrowDelay меняется только в
; памяти игры и не сохраняется в ini.
;
; Проверено в игре (2026-09-28): ShowFirstPersonGeometry(false) во время удержания прячет
; руки и оружие, траектория видна целиком, броски не срываются и идут быстро. Клип броска
; (WPNGrenadeThrow.hkx) играет после отпускания: вылет гранаты — через ~0,7 с, throwEnd —
; через ~1,4 с. Во время удержания граф анимации рук ничего не знает о прицеливании
; (bIsThrowing и прочие переменные меняются только при отпускании).
;
; Версия 1.0 вместо этого убирала оружие в кобуру; игра срывала броски, отпущенные во время
; анимации убирания или наложившиеся на предыдущий бросок, — всё это ушло вместе с кобурой.

Action Property ActionMelee Auto Const Mandatory

String Property MOD_NAME = "ClearThrowView" AutoReadOnly
String Property CONTROL_THROW = "Melee" AutoReadOnly
String Property THROW_DELAY_INI = "fThrowDelay:Controls" AutoReadOnly
Int Property EQUIP_INDEX_THROWABLE = 2 AutoReadOnly
Int Property TIMER_HOLD = 1 AutoReadOnly
Int Property TIMER_WATCH = 2 AutoReadOnly
Int Property TIMER_FLUSH = 8 AutoReadOnly
Float Property MIN_HOLD_DELAY = 0.05 AutoReadOnly
Float Property SPLIT_HOLD_DELAY = 0.2 AutoReadOnly ; раздельные клавиши: короткие нажатия (0,05–0,15 с) не скрывать
Float Property WATCH_STEP = 0.25 AutoReadOnly      ; пока руки скрыты — проверка, не пора ли показать
; Лог
Float Property LOG_FLUSH_DELAY = 0.5 AutoReadOnly
String Property LOG_PATH = ".\\Data\\ClearThrowView\\" AutoReadOnly
String Property LOG_FILE = "ClearThrowView.log" AutoReadOnly
Int Property MAX_LOG_LINES = 120 AutoReadOnly  ; массив Papyrus — не больше 128 элементов, Add сверх молча не добавляет
Float Property DIAG_WINDOW = 5.0 AutoReadOnly  ; анимационные события в лог — столько секунд после нажатия

; --- настройки MCM ---
Bool Enabled = true
Bool SplitKeys = false
Bool LogEnabled = false

; --- нажатия ---
Float OriginalThrowDelay = -1.0     ; fThrowDelay из ini, до обнуления раздельными клавишами
Bool Holding                        ; клавиша броска удерживается
Int PressSeq                        ; номер нажатия
Int UpHandledSeq                    ; нажатие, отпускание которого уже обработано
Bool DownDone                       ; обработка текущего нажатия закончена
Bool Released                       ; текущее нажатие уже отпущено
Float PressTime                     ; момент нажатия (до любых вызовов наружу)
Float HeldTime
Weapon PressItem                    ; что было экипировано для броска при нажатии
Int[] ThrowKeys                     ; клавиши контрола броска — запасной источник отпускания

; --- руки ---
Bool Hidden                         ; руки и оружие скрыты модом
Float ReleaseTime = -100.0

String[] LogBuf
Bool FlushPending

Event OnQuestInit()
    Setup()
EndEvent

Event Actor.OnPlayerLoadGame(Actor akSender)
    Setup()
EndEvent

Function Setup()
    LogBuf = new String[0]
    FlushPending = false
    ; Сохранились со скрытыми руками — вернуть.
    Game.ShowFirstPersonGeometry(true)
    Hidden = false
    Actor player = Game.GetPlayer()
    RegisterForRemoteEvent(player, "OnPlayerLoadGame")
    RegisterForControl(CONTROL_THROW)
    RegisterThrowKeys()
    RegisterForExternalEvent("OnMCMSettingChange|" + MOD_NAME, "OnMCMSettingChange")
    RegisterMenus()
    ; GetCurrentRealTime считается от запуска игры, а переменные — из сейва.
    Holding = false
    PressTime = -100.0
    ReleaseTime = -100.0
    ; Настоящее значение из ini. 0 — это, скорее всего, наше же обнуление из прошлого сейва
    ; этой сессии: тогда остаётся уже известное.
    Float iniDelay = GardenOfEden.GetINISetting(THROW_DELAY_INI) as Float
    If iniDelay > 0.0
        OriginalThrowDelay = iniDelay
    EndIf
    ReadSettings()
    ApplySplitKeys()
    RegisterAnimEvents()
    Log("start: enabled " + Enabled + ", split keys " + SplitKeys + \
        ", fThrowDelay " + GardenOfEden.GetINISetting(THROW_DELAY_INI) + " (ini " + OriginalThrowDelay + \
        "), throw keys " + ThrowKeys)
EndFunction

Function ReadSettings()
    If MCM.IsInstalled()
        Enabled = MCM.GetModSettingBool(MOD_NAME, "bEnabled:Main")
        SplitKeys = MCM.GetModSettingBool(MOD_NAME, "bSplitKeys:Main")
        LogEnabled = MCM.GetModSettingBool(MOD_NAME, "bLog:Main")
    EndIf
EndFunction

; MCM: внешнее событие «OnMCMSettingChange|ClearThrowView» (RegisterForExternalEvent, F4SE).
; НЕ ПЕРЕИМЕНОВЫВАТЬ: имя передаётся строкой.
Function OnMCMSettingChange(String asModName, String asId)
    ReadSettings()
    ApplySplitKeys()
    If !Enabled
        Show("turned off")
    EndIf
    Log("MCM: " + asId + " changed; fThrowDelay " + GardenOfEden.GetINISetting(THROW_DELAY_INI))
EndFunction

; Раздельные клавиши включены — fThrowDelay 0, иначе значение из ini. От переключателя
; «Скрывать руки» (Enabled) не зависит: это отдельная функция.
Function ApplySplitKeys()
    If SplitKeys
        Utility.SetINIFloat(THROW_DELAY_INI, 0.0)
    ElseIf OriginalThrowDelay > 0.0
        Utility.SetINIFloat(THROW_DELAY_INI, OriginalThrowDelay)
    EndIf
EndFunction

; Клавиши того же контрола (клавиатура, мышь, геймпад) — запасной источник отпускания: если
; OnControlUp потеряется, руки не должны остаться скрытыми. По логу OnKeyUp приходит даже раньше.
Function RegisterThrowKeys()
    If ThrowKeys
        Int j = 0
        While j < ThrowKeys.Length
            UnregisterForKey(ThrowKeys[j])
            j += 1
        EndWhile
    EndIf
    ThrowKeys = new Int[0]
    Int device = 0
    While device <= 2
        Int code = Input.GetMappedKey(CONTROL_THROW, device)
        If code > 0 && code != 255
            ThrowKeys.Add(code)
            RegisterForKey(code)
        EndIf
        device += 1
    EndWhile
EndFunction

; В меню руки нужны (Pip-Boy), а отпускание клавиши в меню может не прийти.
Function RegisterMenus()
    UnregisterForAllMenuOpenCloseEvents()
    RegisterForMenuOpenCloseEvent("PipboyMenu")
    RegisterForMenuOpenCloseEvent("PauseMenu")
    RegisterForMenuOpenCloseEvent("FavoritesMenu")
    RegisterForMenuOpenCloseEvent("VATSMenu")
    RegisterForMenuOpenCloseEvent("LoadingMenu")
    RegisterForMenuOpenCloseEvent("ContainerMenu")
    RegisterForMenuOpenCloseEvent("BarterMenu")
    RegisterForMenuOpenCloseEvent("DialogueMenu")
    RegisterForMenuOpenCloseEvent("ExamineMenu")
    RegisterForMenuOpenCloseEvent("WorkshopMenu")
    RegisterForMenuOpenCloseEvent("TerminalMenu")
EndFunction

Event OnMenuOpenCloseEvent(String asMenuName, Bool abOpening)
    If abOpening && Hidden
        Show("menu " + asMenuName)
    EndIf
EndEvent

Function RegisterAnimEvents()
    Actor player = Game.GetPlayer()
    String[] names = new String[0]
    names.Add("weaponFire")
    names.Add("throwEnd")
    String failed = ""
    Int i = 0
    While i < names.Length
        If !RegisterForAnimationEvent(player, names[i])
            failed += " " + names[i]
        EndIf
        i += 1
    EndWhile
    If failed != ""
        Log("anim events NOT registered:" + failed)
    EndIf
EndFunction

; Сравнение строк в Papyrus без учёта регистра (в лог событие приходит как "WeaponFire").
Event OnAnimationEvent(ObjectReference akSource, String asEventName)
    If LogEnabled && Utility.GetCurrentRealTime() - PressTime < DIAG_WINDOW
        Log("anim " + asEventName)
    EndIf
EndEvent

Event OnAnimationEventUnregistered(ObjectReference akSource, String asEventName)
    Log("anim " + asEventName + " unregistered by game, re-registering")
    RegisterForAnimationEvent(akSource, asEventName)
EndEvent

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
; блокировку скрипта, и в этот момент может выполниться отпускание. Отпускание, пришедшее
; раньше конца обработки нажатия, обрабатывает сам OnControlDown, когда закончит
; (HandleUp — один раз на нажатие, по номеру PressSeq).
Event OnControlDown(String control)
    If control != CONTROL_THROW
        Return
    EndIf
    PressSeq += 1
    Int seq = PressSeq
    Holding = true
    Released = false
    DownDone = false
    PressTime = Utility.GetCurrentRealTime()
    HandleDown(seq)
    If seq == PressSeq
        DownDone = true
        If Released
            HandleUp(seq)
        EndIf
    EndIf
EndEvent

Event OnControlUp(String control, Float time)
    If control == CONTROL_THROW
        KeyReleased(time, "control")
    EndIf
EndEvent

Event OnKeyUp(Int keyCode, Float time)
    If ThrowKeys.Find(keyCode) >= 0
        KeyReleased(time, "key " + keyCode)
    EndIf
EndEvent

; Отпускание приходит и как контрол, и как клавиша — обрабатывается первое.
Function KeyReleased(Float time, String source)
    If !Holding
        Return
    EndIf
    Holding = false
    Released = true
    HeldTime = time
    Int seq = PressSeq
    Log("key up #" + seq + " after " + time + " s (" + source + ")")
    If DownDone
        HandleUp(seq)
    EndIf
EndFunction

Function HandleDown(Int seq)
    PressItem = None
    If !Enabled || Utility.IsInMenuMode()
        Return
    EndIf
    PressItem = Game.GetPlayer().GetEquippedWeapon(EQUIP_INDEX_THROWABLE)
    If !PressItem
        Log("down #" + seq + ": nothing to throw")
        Return
    EndIf
    ; Скрыть, когда нажатие становится броском (fThrowDelay); с раздельными клавишами — после
    ; SPLIT_HOLD_DELAY, чтобы короткие броски не мигали руками.
    Float delay = SPLIT_HOLD_DELAY
    If !SplitKeys
        delay = OriginalThrowDelay
    EndIf
    delay -= Utility.GetCurrentRealTime() - PressTime
    If delay < MIN_HOLD_DELAY
        delay = MIN_HOLD_DELAY
    EndIf
    Log("down #" + seq + ", hidden " + Hidden)
    If Holding
        StartTimer(delay, TIMER_HOLD)
    EndIf
EndFunction

Function HandleUp(Int seq)
    If UpHandledSeq == seq
        Return
    EndIf
    UpHandledSeq = seq
    CancelTimer(TIMER_HOLD)
    ReleaseTime = Utility.GetCurrentRealTime()
    ; Замах рукой после отпускания — уже с руками (пробовали прятать до throwEnd: без рук
    ; весь бросок выглядит хуже).
    Show("release")
EndFunction

Event OnTimer(Int aiTimerID)
    If aiTimerID == TIMER_HOLD
        If Holding && PressItem && !Utility.IsInMenuMode()
            Hide()
        EndIf
    ElseIf aiTimerID == TIMER_WATCH
        Watch()
    ElseIf aiTimerID == TIMER_FLUSH
        FlushLog()
    EndIf
EndEvent

Function Hide()
    If !Hidden
        Hidden = true
        Game.ShowFirstPersonGeometry(false)
        Log("hide (" + (Utility.GetCurrentRealTime() - PressTime) + " s after down)")
    EndIf
    StartTimer(WATCH_STEP, TIMER_WATCH)
EndFunction

Function Show(String reason)
    If !Hidden
        Return
    EndIf
    Hidden = false
    CancelTimer(TIMER_WATCH)
    Game.ShowFirstPersonGeometry(true)
    Log("show (" + reason + ", " + (Utility.GetCurrentRealTime() - ReleaseTime) + " s after release)")
EndFunction

; Страховка: руки не должны остаться скрытыми, если обработка отпускания потерялась.
Function Watch()
    If !Hidden
        Return
    EndIf
    If Utility.IsInMenuMode()
        Show("menu")
        Return
    EndIf
    If !Holding
        Show("released")
        Return
    EndIf
    StartTimer(WATCH_STEP, TIMER_WATCH)
EndFunction

; Секунды с тремя знаками после запятой (для отметок в логе).
String Function Ms(Float t)
    If t < 0.0 || t > 99999.0
        Return "-"
    EndIf
    Int ms = Math.Floor(t * 1000.0)
    Int frac = ms % 1000
    String pad = ""
    If frac < 10
        pad = "00"
    ElseIf frac < 100
        pad = "0"
    EndIf
    Return (ms / 1000) + "." + pad + frac
EndFunction

; Data\ClearThrowView\ClearThrowView.log (Papyrus-лог в игре обычно выключен). Включается
; в MCM. Строки копятся в буфере, файл пишется целиком (WriteLinesToFile не дописывает) не
; чаще раза в LOG_FLUSH_DELAY: запись на каждую строку тормозит скрипт.
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
    Float now = Utility.GetCurrentRealTime()
    LogBuf.Add(Ms(now) + " +" + Ms(now - PressTime) + "  " + text)
    If !FlushPending
        FlushPending = true
        StartTimer(LOG_FLUSH_DELAY, TIMER_FLUSH)
    EndIf
EndFunction

Function FlushLog()
    FlushPending = false
    If LogBuf.Length > 0
        GardenOfEden3.WriteLinesToFile(LOG_FILE, LOG_PATH, LogBuf, true)
    EndIf
EndFunction
