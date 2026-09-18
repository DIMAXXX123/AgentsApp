# ============================================================
#  throw_charge.verse — БРОСОК С ЗАРЯДОМ ОТ УДЕРЖАНИЯ.
#
#  Схема "как с мячиком":
#    зажал кнопку → шкала набирается → отпустил → полетело
#    туда, куда смотришь, на дальность по заряду.
#
#  Чем отличается от cast_mechanic.verse:
#    там    — полоска сама бегает вверх-вниз, ловишь момент,
#             направление фиксированное (зона по номеру).
#    здесь  — заряд растёт, пока держишь, отпускаешь сам,
#             ЦЕЛИШЬСЯ СВОБОДНО, зона определяется тем, куда упало.
#
#  Второй вариант ощущается физичнее и как раз читается как
#  бросок. Под удочку переделывается заменой пропа и анимации —
#  логика заряда и полёта не меняется.
#
#  Зависит от: player_state.verse (сила, удочка),
#              brainrot_types.verse (ролл добычи),
#              power_bar.verse (индикатор заряда).
# ============================================================

using { /Fortnite.com/Devices }
using { /Fortnite.com/Characters }
using { /Verse.org/Simulation }
using { /Verse.org/Random }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /UnrealEngine.com/Temporary/SpatialMath }

ThrowCaughtMessage<localizes>(Name : string, Rar : string, Zone : int) : message =
    "{Name} ({Rar}) · зона {Zone}"

ThrowMissMessage<localizes>() : message = "Мимо воды"

throw_charge := class(creative_device):

    # ---------- Девайсы ----------
    @editable
    ThrowZone : mutator_zone_device = mutator_zone_device{}

    # Input Trigger. Нужны ОБА события: Pressed и Released.
    @editable
    ThrowInput : input_trigger_device = input_trigger_device{}

    @editable
    CatchHud : hud_message_device = hud_message_device{}

    @editable
    SplashSound : audio_player_device = audio_player_device{}

    @editable
    FullChargeSound : audio_player_device = audio_player_device{}

    # ---------- Маркеры ----------
    # Маркеры зон. Порядок = номер зоны. Но теперь они работают
    # иначе, чем в cast_mechanic: зона выбирается не по номеру,
    # а по тому, к какому маркеру ближе всего упал снаряд.
    # Расставляй их по воде как хочешь — хоть дугой, хоть кругом.
    @editable
    ZoneMarkers : []creative_prop = array{}

    # Задаёт высоту воды. Снаряд всегда падает на этот уровень Z.
    @editable
    WaterLevelMarker : creative_prop = creative_prop{}

    @editable
    ProjectileProps : []creative_prop = array{}

    @editable
    BrainrotProps : []creative_prop = array{}

    @editable
    StashMarker : creative_prop = creative_prop{}

    # ---------- Настройки броска ----------
    # Сколько секунд держать до полного заряда.
    @editable
    FullChargeTime : float = 1.2

    # Дальность при нулевом и полном заряде, в юнитах.
    @editable
    MinThrowDistance : float = 800.0
    @editable
    MaxThrowDistance : float = 4000.0

    # Сколько юнитов дальности добавляет единица силы.
    # ЭТО ГЛАВНЫЙ РЫЧАГ ПРОКАЧКИ: сила не ускоряет заряд,
    # а увеличивает дальность при том же заряде.
    @editable
    DistancePerStrength : float = 180.0

    @editable
    FlightTime : float = 1.0
    @editable
    ArcHeight : float = 700.0

    # ---------- Состояние ----------
    var InZone     : [player]logic = map{}
    var IsHolding  : [player]logic = map{}
    var IsThrowing : [player]logic = map{}
    var SlotBusy   : [int]logic    = map{}

    OnBegin<override>()<suspends> : void =
        ThrowZone.AgentEntersEvent.Subscribe(OnEnterZone)
        ThrowZone.AgentExitsEvent.Subscribe(OnExitZone)
        ThrowInput.PressedEvent.Subscribe(OnPressed)
        ThrowInput.ReleasedEvent.Subscribe(OnReleased)

        for (Index := 0..ProjectileProps.Length - 1):
            if (set SlotBusy[Index] = false) {}

        StashAll()
        Print("throw_charge: зон {ZoneMarkers.Length}, слотов {ProjectileProps.Length}")

    # ---------- Зона ----------
    OnEnterZone(Agent : agent) : void =
        if (Player := player[Agent]):
            if (set InZone[Player] = true) {}
            ThrowInput.Register(Player)

    OnExitZone(Agent : agent) : void =
        if (Player := player[Agent]):
            if (set InZone[Player] = false) {}
            # Вышел на середине заряда — заряд сбрасывается.
            if (set IsHolding[Player] = false) {}

    # ---------- Заряд ----------
    # Зажал: пошла петля набора. Отпустил: петля видит флаг
    # и выходит, бросок летит с накопленным зарядом.
    OnPressed(Agent : agent) : void =
        if (Player := player[Agent], InZone[Player]?, not IsThrowing[Player]?):
            if (set IsHolding[Player] = true) {}
            spawn{ ChargeAndThrow(Player) }

    OnReleased(Agent : agent) : void =
        if (Player := player[Agent]):
            if (set IsHolding[Player] = false) {}

    ChargeAndThrow(Player : player)<suspends> : void =
        if (set IsThrowing[Player] = true) {}

        Bar := power_bar{}
        Bar.Show(Player)

        var Charge : float = 0.0
        var PlayedFullSound : logic = false

        loop:
            if (not IsHolding[Player]?):
                break
            set Charge = Min(1.0, Charge + (0.02 / FullChargeTime))
            Bar.SetPower(Charge)

            # Звук полного заряда — единственный сигнал, что
            # дальше держать бессмысленно. Без него игрок держит
            # кнопку "на всякий случай" и теряет темп.
            if (Charge >= 1.0, not PlayedFullSound?):
                FullChargeSound.Play(Player)
                set PlayedFullSound = true

            Sleep(0.02)

        Bar.Hide()

        if (Slot := TakeSlot()?):
            DoThrow(Player, Charge, Slot)
        else:
            Print("throw: слотов нет")

        if (set IsThrowing[Player] = false) {}

    # ---------- Сам бросок ----------
    DoThrow(Player : player, Charge : float, Slot : int)<suspends> : void =
        if:
            Character := Player.GetFortCharacter[]
            Projectile := ProjectileProps[Slot]
        then:
            Save := GetSave(Player)

            # Дальность = база от заряда + прибавка от силы.
            Spread := MaxThrowDistance - MinThrowDistance
            Distance := MinThrowDistance
                      + (Charge * Spread)
                      + (Save.Strength * 1.0 * DistancePerStrength)

            # Направление — куда смотрит игрок. Отсюда свободное
            # прицеливание: одна и та же сила в разные стороны
            # даёт разные зоны.
            ViewRotation := Character.GetViewRotation()
            Forward := ViewRotation.GetLocalForward()
            Start := Character.GetViewLocation()

            WaterZ := WaterLevelMarker.GetTransform().Translation.Z

            Landing := vector3:
                X := Start.X + (Forward.X * Distance)
                Y := Start.Y + (Forward.Y * Distance)
                Z := WaterZ

            FlyArc(Projectile, Start, Landing, FlightTime)
            SplashSound.Play(Player)

            # Зона — по ближайшему маркеру к точке падения.
            # Так карта может быть устроена как угодно: важно
            # не расстояние в юнитах, а куда именно упало.
            if (Zone := NearestZone(Landing)?):
                Sleep(GetRandomFloat(1.0, 2.5))
                if (Def := PickBrainrot(Zone)?):
                    PopOut(Slot, Landing, Start)
                    AddCoins(Player, Def.SellPrice)
                    CatchHud.SetText(ThrowCaughtMessage(Def.Name, RarityName(Def.Rarity), Zone))
                    CatchHud.Show(Player)
                    Print("throw: {Def.Name} zone={Zone} charge={Charge} dist={Distance}")
            else:
                CatchHud.SetText(ThrowMissMessage())
                CatchHud.Show(Player)

            StashProp(Projectile)

        FreeSlot(Slot)

    # ---------- Ближайшая зона ----------
    # Считаем по XY, высоту игнорируем: вода плоская, а разница
    # по Z только испортила бы результат на склоне берега.
    NearestZone(Landing : vector3) : ?int =
        var BestIndex : int = -1
        var BestDist : float = 0.0
        for (Index -> Marker : ZoneMarkers):
            MarkerPos := Marker.GetTransform().Translation
            DX := MarkerPos.X - Landing.X
            DY := MarkerPos.Y - Landing.Y
            DistSq := (DX * DX) + (DY * DY)
            if (BestIndex < 0 or DistSq < BestDist):
                set BestIndex = Index
                set BestDist = DistSq
        if (BestIndex >= 0):
            option{BestIndex + 1}
        else:
            false

    # ---------- Полёт ----------
    FlyArc(Prop : creative_prop, From : vector3, To : vector3, Time : float)<suspends> : void =
        Apex := vector3:
            X := (From.X + To.X) * 0.5
            Y := (From.Y + To.Y) * 0.5
            Z := Max(From.Z, To.Z) + ArcHeight
        Rot := IdentityRotation()
        if (Prop.TeleportTo[From, Rot]) {}
        Prop.MoveTo(Apex, Rot, Time * 0.45)
        Prop.MoveTo(To,   Rot, Time * 0.55)

    PopOut(Slot : int, WaterPos : vector3, PlayerPos : vector3)<suspends> : void =
        if (Prop := BrainrotProps[Slot]):
            Rot := IdentityRotation()
            Under := vector3{ X := WaterPos.X, Y := WaterPos.Y, Z := WaterPos.Z - 250.0 }
            if (Prop.TeleportTo[Under, Rot]) {}
            Prop.MoveTo(WaterPos, Rot, 0.25)
            FlyArc(Prop, WaterPos, PlayerPos, 0.75)
            Sleep(0.3)
            StashProp(Prop)

    # ---------- Слоты и пропы ----------
    TakeSlot() : ?int =
        for (Index := 0..ProjectileProps.Length - 1):
            if (Busy := SlotBusy[Index], not Busy?):
                if (set SlotBusy[Index] = true) {}
                return option{Index}
        false

    FreeSlot(Index : int) : void =
        if (set SlotBusy[Index] = false) {}

    StashProp(Prop : creative_prop) : void =
        StashTransform := StashMarker.GetTransform()
        if (Prop.TeleportTo[StashTransform.Translation, StashTransform.Rotation]) {}

    StashAll() : void =
        for (Prop : ProjectileProps):
            StashProp(Prop)
        for (Prop : BrainrotProps):
            StashProp(Prop)
