# ============================================================
#  fishing_cast.verse — ЗАБРОС ПО РЕФЕРЕНСУ "KICK A LUCKY ROT".
#
#  Разобрано с видео покадрово. Последовательность один в один,
#  удар ногой заменён на заброс удочки, мяч — на поплавок:
#
#    1. Вход в зону → подсказка "ЗАБРОС!"
#    2. Нажал → справа сегментная шкала, она ОСЦИЛЛИРУЕТ
#    3. Нажал второй раз → шкала замирает, баннер качества
#    4. Поплавок летит по коридору, камера едет за ним
#    5. По ходу полёта показывается текущая зона и множитель удачи
#    6. Приземление → выныривает брейнрот, редкость с учётом удачи
#
#  ЧТО ВЗЯТО ИЗ РЕФЕРЕНСА И ПОЧЕМУ:
#
#  · Шкала ОСЦИЛЛИРУЕТ, а не набирается удержанием. На кадрах
#    006/007/008 она полная → пустая → полная за секунду.
#  · Шкала СЕГМЕНТНАЯ. Дискретные ступени легче читаются на
#    скорости, чем гладкая заливка.
#  · Главное число — ДИСТАНЦИЯ В САНТИМЕТРАХ, а не номер зоны.
#    Игрок соревнуется с прошлым броском, а не сверяется с таблицей.
#  · У каждой зоны свой МНОЖИТЕЛЬ УДАЧИ, и он виден в полёте.
#    Это то, что объясняет, зачем бить дальше. Без него дальность
#    выглядит просто цифрой.
#
#  Зависит от: cast_hud.verse, player_state.verse, brainrot_types.verse
# ============================================================

using { /Fortnite.com/Devices }
using { /Fortnite.com/Characters }
using { /Verse.org/Simulation }
using { /Verse.org/Random }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /UnrealEngine.com/Temporary/SpatialMath }

CastPromptMessage<localizes> : message = "ЗАБРОС!"
CaughtLine<localizes>(Name : string, Rar : string) : message = "{Name} ({Rar})"

# Одна зона коридора: маркер на карте, имя и множитель удачи.
# Множитель поднимает шанс верхних редкостей — ровно то, что
# в референсе показано как "17.2x Luck".
cast_zone_def := class<concrete>:
    Name : string = "Zone"
    Luck : float  = 1.0

fishing_cast := class(creative_device):

    # ---------- Девайсы ----------
    @editable
    PierZone : mutator_zone_device = mutator_zone_device{}

    @editable
    CastInput : input_trigger_device = input_trigger_device{}

    @editable
    PromptHud : hud_message_device = hud_message_device{}

    @editable
    CatchHud : hud_message_device = hud_message_device{}

    @editable
    SplashSound : audio_player_device = audio_player_device{}

    @editable
    PerfectSound : audio_player_device = audio_player_device{}

    # ---------- Коридор ----------
    # Маркеры вдоль коридора, ОТ БЛИЖНЕГО К ДАЛЬНЕМУ.
    # Расстояние между ними задаёшь ты, расставляя их на карте;
    # код меряет реальные расстояния, а не считает по формуле.
    @editable
    ZoneMarkers : []creative_prop = array{}

    # Имена и множители удачи по зонам. Порядок совпадает с
    # ZoneMarkers. Если короче — недостающие получат Luck = 1.0.
    ZoneDefs : []cast_zone_def = array:
        cast_zone_def{ Name := "Tree Zone",     Luck := 1.0  }
        cast_zone_def{ Name := "Jungle",        Luck := 1.6  }
        cast_zone_def{ Name := "Desert",        Luck := 2.8  }
        cast_zone_def{ Name := "Gold City",     Luck := 5.5  }
        cast_zone_def{ Name := "VIP",           Luck := 11.0 }
        cast_zone_def{ Name := "ALPHA",         Luck := 17.2 }

    # Точка, откуда стартует поплавок — кончик удочки на пирсе.
    @editable
    CastOrigin : creative_prop = creative_prop{}

    @editable
    FloatProps : []creative_prop = array{}

    @editable
    BrainrotProps : []creative_prop = array{}

    @editable
    StashMarker : creative_prop = creative_prop{}

    # ---------- Настройки ----------
    # Период полного цикла шкалы, секунд. В референсе ~1 с.
    @editable
    GaugeCycleTime : float = 1.0

    # Верхняя доля шкалы, считающаяся идеальным забросом.
    # Меньше 0.04 — злит, больше 0.10 — перестаёт ощущаться скиллом.
    # Часть окна съедает сетевая задержка, поэтому не занижай.
    @editable
    PerfectBand : float = 0.07

    # Сколько юнитов дальности добавляет единица силы.
    @editable
    DistancePerStrength : float = 220.0

    # Время полёта поплавка до самой дальней зоны.
    @editable
    MaxFlightTime : float = 5.0

    @editable
    ArcHeight : float = 900.0

    # Камера едет за поплавком: персонаж телепортируется вдоль
    # траектории. Выключи, если хочешь оставить игрока на пирсе.
    @editable
    RideAlongCamera : logic = true

    # ---------- Состояние ----------
    var InZone     : [player]logic = map{}
    var IsCasting  : [player]logic = map{}
    var PressLatch : [player]logic = map{}
    var SlotBusy   : [int]logic    = map{}

    OnBegin<override>()<suspends> : void =
        PierZone.AgentEntersEvent.Subscribe(OnEnterPier)
        PierZone.AgentExitsEvent.Subscribe(OnExitPier)
        CastInput.PressedEvent.Subscribe(OnCastPressed)

        for (Index := 0..FloatProps.Length - 1):
            if (set SlotBusy[Index] = false) {}

        StashAll()
        Print("fishing_cast: зон {ZoneMarkers.Length}, слотов {FloatProps.Length}")

    # ---------- Пирс ----------
    OnEnterPier(Agent : agent) : void =
        if (Player := player[Agent]):
            if (set InZone[Player] = true) {}
            CastInput.Register(Player)
            PromptHud.SetText(CastPromptMessage)
            PromptHud.Show(Player)

    OnExitPier(Agent : agent) : void =
        if (Player := player[Agent]):
            if (set InZone[Player] = false) {}

    # ---------- Ввод ----------
    # Одна кнопка на два действия, как в референсе: первое нажатие
    # запускает шкалу, второе её ловит.
    OnCastPressed(Agent : agent) : void =
        if (Player := player[Agent], InZone[Player]?):
            if (IsCasting[Player]?):
                if (set PressLatch[Player] = true) {}
            else if (Slot := TakeSlot()?):
                spawn{ CastSequence(Player, Slot) }

    TakeLatch(Player : player) : logic =
        if (PressLatch[Player]?):
            if (set PressLatch[Player] = false) {}
            true
        else:
            false

    # ---------- Полная последовательность ----------
    CastSequence(Player : player, Slot : int)<suspends> : void =
        if (set IsCasting[Player] = true) {}
        if (set PressLatch[Player] = false) {}

        Hud := cast_hud{}
        Hud.Show(Player)

        Power := RunGauge(Player, Hud)

        # Шкала замирает на пойманном значении, как в референсе:
        # игрок должен увидеть, что именно он поймал.
        Hud.SetPower(Power)
        Hud.ShowQuality(Power, 1.0 - PerfectBand)
        if (Power >= 1.0 - PerfectBand):
            PerfectSound.Play(Player)

        Sleep(0.5)

        Distance := DistanceFor(Player, Power)
        Zone := ZoneFromDistance(Distance)
        Luck := LuckOf(Zone)
        Hud.ShowResult(Round[Distance], NameOf(Zone), Luck)

        DoFlight(Player, Slot, Zone, Distance, Hud)

        Hud.Hide()
        FreeSlot(Slot)
        if (set IsCasting[Player] = false) {}

    # ---------- Шкала ----------
    # Синусоида: у краёв полоса замедляется, верх читается как
    # навык, а не как лотерея. Сила игрока НЕ ускоряет шкалу —
    # она добавляет дальность. Иначе прокачка сокращала бы окно
    # и качаться было бы неприятно.
    RunGauge(Player : player, Hud : cast_hud)<suspends> : float =
        Step := 0.02
        Speed := (2.0 * 3.14159) / Max(0.2, GaugeCycleTime)
        var T : float = 0.0
        var Result : float = 0.0
        loop:
            Power := Abs(Sin(T))
            Hud.SetPower(Power)
            if (TakeLatch(Player)?):
                set Result = Power
                break
            set T += Speed * Step
            Sleep(Step)
        Result

    # ---------- Дальность ----------
    # Дистанция считается в юнитах от точки заброса, показывается
    # как сантиметры: в Unreal 1 юнит = 1 см, так что число из
    # референса ("+1 814 см") получается без пересчёта.
    DistanceFor(Player : player, Power : float) : float =
        Save := GetSave(Player)
        MaxReach := FarthestDistance()
        Bonus := Save.Strength * 1.0 * DistancePerStrength
        Min(MaxReach, (Power * MaxReach) + Bonus)

    FarthestDistance() : float =
        Origin := CastOrigin.GetTransform().Translation
        var Best : float = 1000.0
        for (Marker : ZoneMarkers):
            D := Distance2D(Origin, Marker.GetTransform().Translation)
            if (D > Best):
                set Best = D
        Best

    # Зона — та, чей маркер ближе всего к точке падения по дальности.
    # Меряем реальные расстояния до маркеров, поэтому коридор можно
    # размечать неравномерно: дальние зоны пусть будут реже.
    ZoneFromDistance(Dist : float) : int =
        Origin := CastOrigin.GetTransform().Translation
        var BestIndex : int = 0
        var BestDelta : float = -1.0
        for (Index -> Marker : ZoneMarkers):
            MarkerDist := Distance2D(Origin, Marker.GetTransform().Translation)
            Delta := Abs(MarkerDist - Dist)
            if (BestDelta < 0.0 or Delta < BestDelta):
                set BestIndex = Index
                set BestDelta = Delta
        BestIndex + 1

    LuckOf(Zone : int) : float =
        if (Def := ZoneDefs[Zone - 1]):
            Def.Luck
        else:
            1.0

    NameOf(Zone : int) : string =
        if (Def := ZoneDefs[Zone - 1]):
            Def.Name
        else:
            "Zone {Zone}"

    Distance2D(A : vector3, B : vector3) : float =
        DX := A.X - B.X
        DY := A.Y - B.Y
        Sqrt((DX * DX) + (DY * DY))

    # ---------- Полёт ----------
    # Время полёта пропорционально дальности: ближняя зона — быстро,
    # ALPHA — долгие пять секунд. Именно это в референсе и есть
    # зрелище: чем дальше улетело, тем дольше ты это смотришь.
    DoFlight(Player : player, Slot : int, Zone : int, Dist : float, Hud : cast_hud)<suspends> : void =
        if:
            Marker := ZoneMarkers[Zone - 1]
            FloatProp := FloatProps[Slot]
        then:
            Origin := CastOrigin.GetTransform().Translation
            Target := Marker.GetTransform().Translation
            MaxD := FarthestDistance()
            Time := Max(1.0, MaxFlightTime * (Dist / Max(1.0, MaxD)))

            Steps := Max(12, Round[Time / 0.05])
            Rot := IdentityRotation()

            for (Step := 0..Steps):
                Alpha := (Step * 1.0) / (Steps * 1.0)
                Pos := ArcPoint(Origin, Target, Alpha)
                if (FloatProp.TeleportTo[Pos, Rot]) {}

                # Камера едет за поплавком. В UEFN нет камеры,
                # привязываемой к пропу, поэтому вместе с поплавком
                # везём самого персонажа — вид следует за ним сам.
                if (RideAlongCamera?, Character := Player.GetFortCharacter[]):
                    Behind := vector3:
                        X := Pos.X
                        Y := Pos.Y
                        Z := Pos.Z + 150.0
                    if (Character.TeleportTo[Behind, Rot]) {}

                Sleep(0.05)

            SplashSound.Play(Player)
            Sleep(GetRandomFloat(0.8, 2.0))

            if (Def := PickWithLuck(Zone, LuckOf(Zone))?):
                PopOut(Slot, Target, Origin)
                Reward := Round[Def.SellPrice * 1.0 * LuckOf(Zone)]
                AddCoins(Player, Reward)
                CatchHud.SetText(CaughtLine(Def.Name, RarityName(Def.Rarity)))
                CatchHud.Show(Player)
                Print("cast: {Def.Name} zone={Zone} dist={Dist} luck={LuckOf(Zone)}")

            # Возвращаем игрока на пирс после полёта.
            if (RideAlongCamera?, Character := Player.GetFortCharacter[]):
                if (Character.TeleportTo[Origin, IdentityRotation()]) {}

            StashProp(FloatProp)

    # Парабола по параметру 0..1. Одним MoveTo вышла бы прямая,
    # она читается как телепорт.
    ArcPoint(From : vector3, To : vector3, Alpha : float) : vector3 =
        Height := ArcHeight * 4.0 * Alpha * (1.0 - Alpha)
        vector3:
            X := From.X + ((To.X - From.X) * Alpha)
            Y := From.Y + ((To.Y - From.Y) * Alpha)
            Z := From.Z + ((To.Z - From.Z) * Alpha) + Height

    # ---------- Ролл с удачей ----------
    # Множитель удачи делает N попыток ролла и оставляет лучшую.
    # Это честнее, чем крутить веса: ровно так же ведут себя
    # "luck"-механики в референсных картах, и игрок это чувствует.
    PickWithLuck(Zone : int, Luck : float) : ?brainrot_def =
        Rolls := Max(1, Round[Luck])
        var Best : ?brainrot_def = false
        for (Index := 0..Rolls - 1):
            if (Candidate := PickBrainrot(Zone)?):
                if (Current := Best?):
                    if (RarityRank(Candidate.Rarity) > RarityRank(Current.Rarity)):
                        set Best = option{Candidate}
                else:
                    set Best = option{Candidate}
        Best

    RarityRank(R : rarity) : int =
        case (R):
            rarity.Common    => 0
            rarity.Uncommon  => 1
            rarity.Rare      => 2
            rarity.Epic      => 3
            rarity.Legendary => 4
            rarity.Mythic    => 5

    # ---------- Вылет брейнрота ----------
    PopOut(Slot : int, WaterPos : vector3, PlayerPos : vector3)<suspends> : void =
        if (Prop := BrainrotProps[Slot]):
            Rot := IdentityRotation()
            Under := vector3{ X := WaterPos.X, Y := WaterPos.Y, Z := WaterPos.Z - 250.0 }
            if (Prop.TeleportTo[Under, Rot]) {}
            # Короткий рывок вверх — именно он читается как
            # "выпрыгнул". Растянешь — получится всплытие.
            Prop.MoveTo(WaterPos, Rot, 0.25)
            Sleep(1.2)
            StashProp(Prop)

    # ---------- Слоты и пропы ----------
    TakeSlot() : ?int =
        for (Index := 0..FloatProps.Length - 1):
            if (Busy := SlotBusy[Index], not Busy?):
                if (set SlotBusy[Index] = true) {}
                return option{Index}
        false

    FreeSlot(Index : int) : void =
        if (set SlotBusy[Index] = false) {}

    StashProp(Prop : creative_prop) : void =
        T := StashMarker.GetTransform()
        if (Prop.TeleportTo[T.Translation, T.Rotation]) {}

    StashAll() : void =
        for (Prop : FloatProps):
            StashProp(Prop)
        for (Prop : BrainrotProps):
            StashProp(Prop)
