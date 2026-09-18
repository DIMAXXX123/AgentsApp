# ============================================================
#  cast_mechanic.verse — МЕХАНИКА ЗАБРОСА ЦЕЛИКОМ.
#
#  Вход в зону → шкала силы → заброс → полёт поплавка в зону →
#  поклёвка → вылет брейнрота из воды к игроку.
#
#  ГЛАВНОЕ ОТЛИЧИЕ ОТ ПРОШЛОЙ ВЕРСИИ: зоны не вычисляются из
#  расстояний в юнитах, а берутся из маркеров, которые ты сам
#  ставишь на карте. Сколько маркеров положил — столько зон.
#  Как устроена твоя карта, коду безразлично.
#
#  Зависит от:  power_bar.verse (шкала), player_state.verse (сила,
#               удочка), brainrot_types.verse (ролл добычи).
#  Не зависит:  от game_manager.verse. Это самостоятельное
#               устройство, его можно поставить вместо него.
# ============================================================

using { /Fortnite.com/Devices }
using { /Fortnite.com/Characters }
using { /Verse.org/Simulation }
using { /Verse.org/Random }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /UnrealEngine.com/Temporary/SpatialMath }

CastCaughtMessage<localizes>(Name : string, Rar : string, Zone : int) : message =
    "{Name} ({Rar}) · зона {Zone}"

CastMissMessage<localizes>() : message = "Сорвалось!"

cast_mechanic := class(creative_device):

    # ---------- Девайсы ----------
    @editable
    CastZone : mutator_zone_device = mutator_zone_device{}

    @editable
    CastInput : input_trigger_device = input_trigger_device{}

    @editable
    CatchHud : hud_message_device = hud_message_device{}

    @editable
    SplashSound : audio_player_device = audio_player_device{}

    @editable
    PerfectSound : audio_player_device = audio_player_device{}

    # ---------- Маркеры зон ----------
    # Пустые пропы, расставленные по воде. ПОРЯДОК В МАССИВЕ =
    # НОМЕР ЗОНЫ: первый элемент — зона 1 (ближняя), последний —
    # самая дальняя и самая жирная. Ставь их там, где у тебя вода,
    # хоть по кругу, хоть змейкой.
    @editable
    ZoneMarkers : []creative_prop = array{}

    # ---------- Пулы пропов ----------
    # По одному поплавку и одному брейнроту на игрока, который
    # может ловить ОДНОВРЕМЕННО с другими. Четыре слота = четыре
    # человека ловят разом, пятый ждёт.
    #
    # Пул, а не спавн на каждый заброс: спавн к сотому забросу
    # забивает карту пропами и жрёт память.
    @editable
    FloatProps : []creative_prop = array{}

    @editable
    BrainrotProps : []creative_prop = array{}

    # Куда пропы прячутся между забросами. Поставь глубоко под картой.
    @editable
    StashMarker : creative_prop = creative_prop{}

    # ---------- Настройки ----------
    # Сколько единиц силы открывают следующую зону.
    @editable
    StrengthPerZone : int = 4

    @editable
    FlightTime : float = 1.0

    @editable
    ArcHeight : float = 600.0

    # ---------- Состояние ----------
    var IsCasting  : [player]logic = map{}
    var PressLatch : [player]logic = map{}
    var InZone     : [player]logic = map{}
    var SlotBusy   : [int]logic    = map{}

    OnBegin<override>()<suspends> : void =
        CastZone.AgentEntersEvent.Subscribe(OnEnterZone)
        CastZone.AgentExitsEvent.Subscribe(OnExitZone)
        CastInput.PressedEvent.Subscribe(OnCastPressed)

        for (Index := 0..FloatProps.Length - 1):
            if (set SlotBusy[Index] = false) {}

        StashAll()
        Print("cast_mechanic: зон {ZoneMarkers.Length}, слотов {FloatProps.Length}")

    # ---------- Зона ----------
    OnEnterZone(Agent : agent) : void =
        if (Player := player[Agent]):
            if (set InZone[Player] = true) {}
            CastInput.Register(Player)

    OnExitZone(Agent : agent) : void =
        if (Player := player[Agent]):
            if (set InZone[Player] = false) {}

    # ---------- Ввод ----------
    # Одна кнопка на два действия: первое нажатие запускает шкалу,
    # второе её останавливает. Защёлка читается и сбрасывается
    # атомарно, иначе быстрый двойной клик съедает заброс.
    OnCastPressed(Agent : agent) : void =
        if (Player := player[Agent], InZone[Player]?):
            if (IsCasting[Player]?):
                if (set PressLatch[Player] = true) {}
            else if (Slot := TakeSlot()?):
                spawn{ CastLoop(Player, Slot) }
            else:
                Print("cast: все слоты заняты")

    TakeLatch(Player : player) : logic =
        if (PressLatch[Player]?):
            if (set PressLatch[Player] = false) {}
            true
        else:
            false

    # ---------- Слоты ----------
    TakeSlot() : ?int =
        for (Index := 0..FloatProps.Length - 1):
            if (Busy := SlotBusy[Index], not Busy?):
                if (set SlotBusy[Index] = true) {}
                return option{Index}
        false

    FreeSlot(Index : int) : void =
        if (set SlotBusy[Index] = false) {}

    # ---------- Сила → зона ----------
    # Два разных числа, которые легко перепутать:
    #
    #   ReachableZone — до какой зоны игрок ДОСТАЁТ в принципе.
    #                   Это прокачка: сила и удочка.
    #   ZoneFromPower — до какой зоны он реально добросил сейчас.
    #                   Это скилл: попадание по шкале.
    #
    # Идеальный бросок = максимум из доступного, не больше.
    # Прокачка поднимает потолок, шкала решает, дотянулся ли ты
    # до него в этот раз.
    ReachableZone(Player : player) : int =
        Save := GetSave(Player)
        ByStrength := 1 + Floor(Save.Strength * 1.0 / (StrengthPerZone * 1.0))
        ByRod := MaxZoneFor(Player)
        Min(Min(ByStrength, ByRod), ZoneMarkers.Length)

    ZoneFromPower(Player : player, Power : float) : int =
        Reach := ReachableZone(Player)
        Raw := Ceil(Power * (Reach * 1.0))
        # Недолёт не даёт пустой бросок: минимум зона 1.
        # Пустой заброс без награды ломает темп сильнее, чем
        # мусорный дроп.
        Min(Max(Raw, 1), Max(Reach, 1))

    # ---------- Шкала ----------
    # Синусоида, а не линейный пинг-понг: у краёв полоса
    # замедляется, и верх читается как навык, а не как лотерея.
    RunBar(Player : player, Bar : power_bar)<suspends> : float =
        Save := GetSave(Player)
        Speed := Max(0.8, 3.2 - (Save.Strength * 0.06))
        var T : float = 0.0
        var Result : float = 0.0
        loop:
            Power := Abs(Sin(T))
            Bar.SetPower(Power)
            if (TakeLatch(Player)?):
                set Result = Power
                break
            set T += Speed * 0.02
            Sleep(0.02)
        Result

    # ---------- Полёт поплавка ----------
    # Дуга из двух отрезков: вверх к вершине, потом вниз к воде.
    # Одним MoveTo получилась бы прямая — читается как телепорт.
    FlyFloat(Prop : creative_prop, From : vector3, To : vector3)<suspends> : void =
        Apex := vector3:
            X := (From.X + To.X) * 0.5
            Y := (From.Y + To.Y) * 0.5
            Z := Max(From.Z, To.Z) + ArcHeight
        Rot := IdentityRotation()
        if (Prop.TeleportTo[From, Rot]) {}
        Prop.MoveTo(Apex, Rot, FlightTime * 0.45)
        Prop.MoveTo(To,   Rot, FlightTime * 0.55)

    # ---------- Вылет брейнрота ----------
    # Выныривает из-под воды рывком, летит по дуге к игроку,
    # прячется. Рывок вверх короткий (0.25 с) — именно он читается
    # как "выпрыгнул", всё остальное уже полёт.
    PopOutBrainrot(Slot : int, WaterPos : vector3, PlayerPos : vector3)<suspends> : void =
        if (Prop := BrainrotProps[Slot]):
            Rot := IdentityRotation()
            Under := vector3{ X := WaterPos.X, Y := WaterPos.Y, Z := WaterPos.Z - 250.0 }
            if (Prop.TeleportTo[Under, Rot]) {}

            Prop.MoveTo(WaterPos, Rot, 0.25)

            Apex := vector3:
                X := (WaterPos.X + PlayerPos.X) * 0.5
                Y := (WaterPos.Y + PlayerPos.Y) * 0.5
                Z := Max(WaterPos.Z, PlayerPos.Z) + ArcHeight * 0.8
            Prop.MoveTo(Apex, Rot, 0.35)

            Above := vector3{ X := PlayerPos.X, Y := PlayerPos.Y, Z := PlayerPos.Z + 150.0 }
            Prop.MoveTo(Above, Rot, 0.4)

            Sleep(0.3)
            StashProp(Prop)

    # ---------- Главная петля заброса ----------
    CastLoop(Player : player, Slot : int)<suspends> : void =
        if (set IsCasting[Player] = true) {}
        if (set PressLatch[Player] = false) {}

        Bar := power_bar{}
        Bar.Show(Player)
        Power := RunBar(Player, Bar)
        Bar.Hide()

        Save := GetSave(Player)
        if (IsPerfect(Power, Save.Strength)?):
            PerfectSound.Play(Player)

        Zone := ZoneFromPower(Player, Power)

        if:
            Character := Player.GetFortCharacter[]
            Marker := ZoneMarkers[Zone - 1]
            FloatProp := FloatProps[Slot]
        then:
            PlayerPos := Character.GetTransform().Translation
            WaterPos := Marker.GetTransform().Translation

            FlyFloat(FloatProp, PlayerPos, WaterPos)
            SplashSound.Play(Player)

            # Пауза перед результатом — это драматургия.
            # Мгновенная выдача убивает ожидание.
            Sleep(GetRandomFloat(1.0, 2.5))

            if (Def := PickBrainrot(Zone)?):
                PopOutBrainrot(Slot, WaterPos, PlayerPos)
                AddCoins(Player, Def.SellPrice)
                CatchHud.SetText(CastCaughtMessage(Def.Name, RarityName(Def.Rarity), Zone))
                CatchHud.Show(Player)
                Print("cast: {Def.Name} zone={Zone} power={Power}")
            else:
                CatchHud.SetText(CastMissMessage())
                CatchHud.Show(Player)

            StashProp(FloatProp)
        else:
            Print("cast: нет маркера зоны {Zone} или поплавка в слоте {Slot}")

        FreeSlot(Slot)
        if (set IsCasting[Player] = false) {}

    # ---------- Пропы ----------
    StashProp(Prop : creative_prop) : void =
        StashTransform := StashMarker.GetTransform()
        if (Prop.TeleportTo[StashTransform.Translation, StashTransform.Rotation]) {}

    StashAll() : void =
        for (Prop : FloatProps):
            StashProp(Prop)
        for (Prop : BrainrotProps):
            StashProp(Prop)
