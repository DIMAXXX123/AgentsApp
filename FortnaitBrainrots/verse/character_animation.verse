# ============================================================
#  character_animation.verse — АНИМАЦИЯ НА ПЕРСОНАЖА ИГРОКА.
#
#  Требует UEFN 41.10+: именно там play_animation_controller
#  научился работать с персонажем игрока, а не только с пропами
#  и NPC. На старой версии файл не соберётся — обнови редактор.
#
#  Цепочка: fort_character → GetPlayAnimationController → Play
#
#  ВАЖНО ПРО УСТРОЙСТВО ЭТОГО ФАЙЛА.
#  Я намеренно НЕ пишу свою функцию вида PlayAnim(Agent, Anim),
#  потому что для неё пришлось бы объявить тип аргумента-анимации,
#  а он у Epic различается между системами (обычные ассеты против
#  Scene Graph). Вместо этого хелпер отдаёт контроллер, а сам вызов
#  Play/PlayAndAwait стоит там, где написано имя ассета — тип тогда
#  выводится компилятором, и ошибиться негде.
# ============================================================

using { /Fortnite.com/Characters }
using { /Fortnite.com/Devices }
using { /Fortnite.com/Animation/PlayAnimation }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/Diagnostics }

# Достаёт контроллер анимаций у персонажа агента.
# Возвращает false, если тела нет: игрок умер, вышел или ещё
# не заспавнился. Петлю это не роняет.
GetAnimController(Agent : agent) : ?play_animation_controller =
    if:
        Character := Agent.GetFortCharacter[]
        Controller := Character.GetPlayAnimationController[]
        # ЕСЛИ КОМПИЛЯТОР СКАЖЕТ, ЧТО ЗДЕСЬ НЕ НУЖНЫ СКОБКИ [] —
        # замени строку выше на:
        #     Controller := Character.GetPlayAnimationController()
        # Это единственное место, где документация Epic расходится
        # сама с собой: часть страниц показывает failable-форму,
        # часть — обычную.
    then:
        option{Controller}
    else:
        Print("anim: у агента нет fort_character или контроллера")
        false

# ============================================================
#  Тестовое устройство: одна кнопка.
#  Ставится на карту, жмёшь — сразу видно, играет анимация или нет.
#  Проверяй здесь ДО того, как встраивать анимацию в петлю рыбалки.
# ============================================================

anim_test := class(creative_device):

    @editable
    PlayButton : button_device = button_device{}

    OnBegin<override>()<suspends> : void =
        PlayButton.InteractedWithEvent.Subscribe(OnPressed)

    # Обработчик события не может ждать — уводим работу в spawn.
    OnPressed(Agent : agent) : void =
        spawn{ PlayOnce(Agent) }

    PlayOnce(Agent : agent)<suspends> : void =
        if (Controller := GetAnimController(Agent)?):

            # ↓↓↓ ЕДИНСТВЕННАЯ СТРОКА ПОД ЗАМЕНУ ↓↓↓
            #
            # Анимация видна в Verse как:
            #     <ИмяПроекта>.<Папка>.<ИмяАссета>_animation
            #
            # Суффикс _animation UEFN дописывает сам. То есть файл
            # Content/Anims/FishingCast в проекте MyIsland станет
            #     MyIsland.Anims.FishingCast_animation
            #
            # Точное имя проще всего не угадывать, а взять
            # автодополнением: начни печатать имя проекта и точку,
            # Verse покажет список доступных ассетов.
            #
            # Анимаций в проекте ещё нет? Импортируй любую .fbx
            # в Content — она появится здесь автоматически.

            Result := Controller.PlayAndAwait(MyIsland.Anims.FishingCast_animation)

            # ↑↑↑ ЗАМЕНИ НА СВОЁ ↑↑↑

            case (Result):
                play_animation_result.Completed   => Print("anim: доиграла")
                play_animation_result.Interrupted => Print("anim: прервана")
                play_animation_result.Error       => Print("anim: ошибка")

    # ---------- Второй режим: запустить и не ждать ----------
    # Для фоновых реакций: получил добычу, махнул рукой, а логика
    # уже поехала дальше. Play возвращает play_animation_instance,
    # через него анимацию можно остановить.
    PlayNoWait(Agent : agent) : void =
        if (Controller := GetAnimController(Agent)?):
            Controller.Play(
                MyIsland.Anims.FishingCast_animation,
                ?PlayRate := 1.0,
                ?BlendInTime := 0.15,
                ?BlendOutTime := 0.25,
                ?StartPositionSeconds := 0.0)
