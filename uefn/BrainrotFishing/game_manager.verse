# ============================================================
#  game_manager.verse — КОРНЕВОЕ УСТРОЙСТВО.
#  Один экземпляр на карте. Держит подписки на девайсы и
#  запускает петлю рыбалки на каждого игрока отдельно.
#
#  Каркас закрывает этапы 00–05 (заброс → шкала → зона → клёв).
#  Ферма, магазины и акула помечены TODO и подключаются сюда же.
# ============================================================

using { /Fortnite.com/Devices }
using { /Fortnite.com/Characters }
using { /Fortnite.com/Playspaces }
using { /Verse.org/Simulation }
using { /Verse.org/Random }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /UnrealEngine.com/Temporary/SpatialMath }

CaughtMessage<localizes>(Name : string, Rar : string, Coins : int) : message =
    "Поймал: {Name} ({Rar}) +{Coins}"

MissMessage<localizes>() : message = "Сорвалось!"

game_manager := class(creative_device):

    # ---------- Девайсы с карты ----------
    # Все проставляются в Details корневого устройства после размещения.
    @editable
    CastZone : mutator_zone_device = mutator_zone_device{}      # зелёная зона на пирсе
    @editable
    CastInput : input_trigger_device = input_trigger_device{}   # кнопка заброса
    @editable
    CatchHud : hud_message_device = hud_message_device{}        # текст результата
    @editable
    CastSound : audio_player_device = audio_player_device{}     # всплеск
    @editable
    PerfectSound : audio_player_device = audio_player_device{}  # идеальный бросок

    # ---------- Рантайм-состояние ----------
    # logic-флаги вместо очередей: игрок не должен начать второй
    # заброс, пока не закончился первый.
    var InZone      : [player]logic = map{}
    var IsFishing   : [player]logic = map{}
    var PressLatch  : [player]logic = map{}

    OnBegin<override>()<suspends> : void =
        CastZone.AgentEntersEvent.Subscribe(OnEnterZone)
        CastZone.AgentExitsEvent.Subscribe(OnExitZone)
        CastInput.PressedEvent.Subscribe(OnCastPressed)

        # Инициализируем сейв на входе, чтобы GetSave не отдавал пустышку.
        for (Player : GetPlayspace().GetPlayers()):
            SetSave(Player, GetSave(Player))
            CastInput.Register(Player)

    # ---------- Зона ----------
    OnEnterZone(Agent : agent) : void =
        if (Player := player[Agent]):
            if (set InZone[Player] = true) {}
            CastInput.Register(Player)

    OnExitZone(Agent : agent) : void =
        if (Player := player[Agent]):
            if (set InZone[Player] = false) {}

    # ---------- Ввод ----------
    # Подписка не может быть <suspends>, поэтому она только ставит
    # защёлку либо стартует петлю через spawn.
    OnCastPressed(Agent : agent) : void =
        if (Player := player[Agent], InZone[Player]?):
            if (IsFishing[Player]?):
                if (set PressLatch[Player] = true) {}   # это нажатие = стоп шкалы
            else:
                spawn{ FishingLoop(Player) }

    TakeLatch(Player : player) : logic =
        if (PressLatch[Player]?):
            if (set PressLatch[Player] = false) {}
            true
        else:
            false

    # ---------- Главная петля ----------
    FishingLoop(Player : player)<suspends> : void =
        if (set IsFishing[Player] = true) {}
        if (set PressLatch[Player] = false) {}

        Bar := power_bar{}
        Bar.Show(Player)
        Power := RunPowerBar(Player, Bar)
        Bar.Hide()

        Save := GetSave(Player)
        Zone := ZoneFromPower(Player, Power)

        CastSound.Play(Player)
        if (IsPerfect(Power, Save.Strength)?):
            PerfectSound.Play(Player)

        # TODO этап 04: анимация полёта поплавка (проп + MoveTo по дуге).
        Sleep(1.0)

        # Пауза перед результатом — это драматургия, не выдавай мгновенно.
        Sleep(GetRandomFloat(1.0, 2.5))

        if (Def := PickBrainrot(Zone)?):
            # TODO этап 06: здесь вставляется погоня с акулой.
            # Провал должен отдавать ~25% цены, а не ноль.
            Reward := Def.SellPrice
            AddCoins(Player, Reward)
            CatchHud.SetText(CaughtMessage(Def.Name, RarityName(Def.Rarity), Reward))
            CatchHud.Show(Player)
            Print("catch: {Def.Name} zone={Zone} power={Power}")
        else:
            CatchHud.SetText(MissMessage())
            CatchHud.Show(Player)

        if (set IsFishing[Player] = false) {}

    # ---------- Шкала ----------
    # Синусоида, а не линейный пинг-понг: у краёв полоса замедляется,
    # и попадание в верх читается как навык, а не как лотерея.
    RunPowerBar(Player : player, Bar : power_bar)<suspends> : float =
        Save := GetSave(Player)
        Speed := Max(0.8, 3.2 - (Save.Strength * 1.0 * 0.06))
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

    # ---------- Сила → зона ----------
    # Потолок = удочка. Недолёт НЕ даёт пустой бросок: минимум зона 1.
    # Пустой бросок ломает темп сильнее, чем плохая награда.
    ZoneFromPower(Player : player, Power : float) : int =
        RodCap := MaxZoneFor(Player)
        Raw := Floor(Power * (RodCap * 1.0)) + 1
        Min(Max(Raw, 1), Min(RodCap, MaxZoneIndex))
