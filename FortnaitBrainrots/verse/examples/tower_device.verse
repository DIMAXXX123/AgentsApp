# ============================================================
#  tower_device.verse — УЧЕБНЫЙ ПРИМЕР.
#
#  Башня с зоной действия: держит список целей, раз в интервал
#  бьёт ближайшую, качается за монеты.
#
#  Здесь собраны все четыре способа, которыми Verse говорит
#  с девайсами. Каждый помечен в комментарии цифрой:
#    [1] @editable — ссылка на девайс с карты
#    [2] Subscribe — подписка на событие девайса
#    [3] вызов метода девайса
#    [4] spawn/loop — собственная петля времени
# ============================================================

using { /Fortnite.com/Devices }
using { /Fortnite.com/Characters }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/Diagnostics }

tower_device := class(creative_device):

    # ---------- [1] Ссылки на девайсы ----------
    # @editable создаёт поле в панели Details у этого устройства
    # на карте. Значение справа от "=" — это НЕ девайс, это пустая
    # заглушка, чтобы поле имело тип. Реальный девайс ты выбираешь
    # мышкой в редакторе. Забыл выбрать — подписка молча не сработает.

    @editable
    RangeZone : mutator_zone_device = mutator_zone_device{}

    @editable
    UpgradeButton : button_device = button_device{}

    @editable
    ShotSound : audio_player_device = audio_player_device{}

    # Числа тоже выносятся в Details — так дизайнер крутит баланс
    # без перекомпиляции Verse.
    @editable
    FireInterval : float = 1.0

    @editable
    BaseDamage : float = 10.0

    # Массив тоже можно: в Details получится список, куда кладёшь
    # сколько угодно девайсов.
    @editable
    Decorations : []creative_prop = array{}

    # ---------- Рантайм-состояние ----------
    var TargetsInRange : []agent = array{}
    var Level : int = 1

    # ---------- Жизненный цикл ----------
    # OnBegin вызывается один раз при старте игры, на КАЖДОМ
    # экземпляре устройства, лежащем на карте.
    OnBegin<override>()<suspends> : void =

        # [2] Подписка. RangeZone.AgentEntersEvent — это listenable,
        # то есть "сюда можно подписать функцию". Функция-обработчик
        # обязана принимать ровно тот тип, который шлёт событие
        # (здесь agent), и НЕ может быть <suspends>.
        RangeZone.AgentEntersEvent.Subscribe(OnEnterRange)
        RangeZone.AgentExitsEvent.Subscribe(OnExitRange)
        UpgradeButton.InteractedWithEvent.Subscribe(OnUpgrade)

        # [4] Собственная петля времени. spawn запускает её параллельно
        # и сразу возвращает управление. Без spawn башня зависла бы
        # тут навсегда и не дошла бы до конца OnBegin.
        spawn{ FireLoop() }

    # ---------- Обработчики событий ----------
    # Сигнатура жёсткая: (agent) : void. Ни suspends, ни decides.
    OnEnterRange(Agent : agent) : void =
        set TargetsInRange += array{Agent}

    OnExitRange(Agent : agent) : void =
        # Удаления из массива в Verse нет — пересобираем без ушедшего.
        var Kept : []agent = array{}
        for (A : TargetsInRange, A <> Agent):
            set Kept += array{A}
        set TargetsInRange = Kept

    OnUpgrade(Agent : agent) : void =
        # player[Agent] — приведение agent → player. Failable:
        # агентом может быть NPC, у которого player нет.
        # TrySpend объявлен <decides>, поэтому зовётся в [] и
        # откатывается целиком, если денег не хватило.
        if (Player := player[Agent], TrySpend[Player, UpgradeCost()]):
            set Level += 1
            Print("tower upgraded to {Level}")

    UpgradeCost() : int = 100 * Level * Level

    # ---------- Петля стрельбы ----------
    # <suspends> = функция умеет ждать. Такие вызываются только
    # из других <suspends> либо через spawn.
    FireLoop()<suspends> : void =
        loop:
            Sleep(FireInterval)
            if (Target := TargetsInRange[0]):
                Fire(Target)

    Fire(Target : agent) : void =
        # agent — это "кто-то в игре". Чтобы нанести урон, нужен
        # его физический персонаж: fort_character. Его может не
        # быть (умер, вышел), поэтому доступ failable.
        if (Character := Target.GetFortCharacter[]):
            Character.Damage(BaseDamage * (Level * 1.0))
            # [3] Вызов метода девайса. Play(Agent) проигрывает
            # звук конкретному игроку, Play() — всем.
            ShotSound.Play(Target)
