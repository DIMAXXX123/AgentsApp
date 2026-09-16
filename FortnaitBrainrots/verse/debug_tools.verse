# ============================================================
#  debug_tools.verse — ФАЙЛ 5. Читы для тестирования.
#
#  Единственное назначение: сделать проверку любого следующего
#  шага мгновенной. Без него каждый тест фермы, магазина или
#  зоны 6 начинается с десяти минут фарма.
#
#  !!! ПЕРЕД ПУБЛИКАЦИЕЙ УДАЛИ УСТРОЙСТВО С КАРТЫ.
#      Файл из проекта удалять не надо — он понадобится на
#      следующем обновлении. Достаточно убрать с острова.
#      Страховка на случай, если забудешь: выключи Enabled.
#
#  Ни один другой файл этот не трогает: чистое дополнение,
#  правок в game_manager не требует.
# ============================================================

using { /Fortnite.com/Devices }
using { /Fortnite.com/Characters }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /UnrealEngine.com/Temporary/SpatialMath }

DebugStateMessage<localizes>(Coins : int, Str : int, Rod : int, MaxZone : int) : message =
    "Монет: {Coins}  ·  Сила: {Str}  ·  Удочка: {Rod} (зона до {MaxZone})"

debug_tools := class(creative_device):

    # Рубильник. Забыл снять устройство с карты — выключи это,
    # и все кнопки станут пустышками.
    @editable
    Enabled : logic = true

    @editable
    GiveCoinsButton : button_device = button_device{}
    @editable
    CoinsPerPress : int = 100000

    @editable
    AddStrengthButton : button_device = button_device{}
    @editable
    StrengthPerPress : int = 5

    @editable
    GiveTopRodButton : button_device = button_device{}

    @editable
    ResetSaveButton : button_device = button_device{}

    @editable
    ShowStateButton : button_device = button_device{}

    @editable
    TeleportButton : button_device = button_device{}
    # Пустой проп на пирсе — точка, куда телепортирует.
    @editable
    PierMarker : creative_prop = creative_prop{}

    @editable
    StateHud : hud_message_device = hud_message_device{}

    OnBegin<override>()<suspends> : void =
        if (not Enabled?):
            Print("debug_tools: выключен")
            return

        Print("debug_tools: АКТИВЕН — снять с карты перед публикацией")

        GiveCoinsButton.InteractedWithEvent.Subscribe(OnGiveCoins)
        AddStrengthButton.InteractedWithEvent.Subscribe(OnAddStrength)
        GiveTopRodButton.InteractedWithEvent.Subscribe(OnGiveTopRod)
        ResetSaveButton.InteractedWithEvent.Subscribe(OnResetSave)
        ShowStateButton.InteractedWithEvent.Subscribe(OnShowState)
        TeleportButton.InteractedWithEvent.Subscribe(OnTeleport)

    # ---------- Кнопки ----------

    OnGiveCoins(Agent : agent) : void =
        if (Player := player[Agent]):
            AddCoins(Player, CoinsPerPress)
            ShowState(Player)

    OnAddStrength(Agent : agent) : void =
        if (Player := player[Agent]):
            Old := GetSave(Player)
            SetSave(Player, WithStrength(Old, Old.Strength + StrengthPerPress))
            ShowState(Player)

    # Ставит последнюю удочку из каталога — какой бы она ни стала
    # после правок баланса.
    OnGiveTopRod(Agent : agent) : void =
        if (Player := player[Agent]):
            TopTier := RodCatalog.Length
            Old := GetSave(Player)
            SetSave(Player, WithRod(Old, TopTier))
            ShowState(Player)

    # Проверка первого входа и миграции сейва: сбрасывает всё
    # в дефолт, как у нового игрока.
    OnResetSave(Agent : agent) : void =
        if (Player := player[Agent]):
            SetSave(Player, save_data{})
            ShowState(Player)

    OnShowState(Agent : agent) : void =
        if (Player := player[Agent]):
            ShowState(Player)

    OnTeleport(Agent : agent) : void =
        if (Character := Agent.GetFortCharacter[]):
            MarkerTransform := PierMarker.GetTransform()
            if (Character.TeleportTo[MarkerTransform.Translation, MarkerTransform.Rotation]) {}

    # ---------- Вывод ----------

    ShowState(Player : player) : void =
        Save := GetSave(Player)
        MaxZone := MaxZoneFor(Player)
        StateHud.SetText(DebugStateMessage(Save.Coins, Save.Strength, Save.RodTier, MaxZone))
        StateHud.Show(Player)
        Print("debug: coins={Save.Coins} str={Save.Strength} rod={Save.RodTier} maxzone={MaxZone}")
