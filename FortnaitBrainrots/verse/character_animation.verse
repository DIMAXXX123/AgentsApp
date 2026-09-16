# ============================================================
#  character_animation.verse — АНИМАЦИЯ НА ПЕРСОНАЖА ИГРОКА.
#
#  Требует UEFN 41.10 или новее: именно там play_animation_controller
#  научился работать с персонажем игрока, а не только с пропами и NPC.
#  Если версия старее — этот файл не соберётся, обновляй редактор.
#
#  Как получить анимацию:
#    fort_character → GetPlayAnimationController[] → Play / PlayAndAwait
#
#  Обе функции failable на первом шаге: у агента может не быть тела
#  (умер, вышел, ещё не заспавнился).
# ============================================================

using { /Fortnite.com/Characters }
using { /Fortnite.com/Devices }
using { /Fortnite.com/Animation/PlayAnimation }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/Diagnostics }

# ---------- Вариант 1: запустить и ждать окончания ----------
# Используй, когда следующее действие должно начаться ПОСЛЕ анимации:
# замах удочкой → потом полёт поплавка.
# Возвращает true, только если анимация доиграла до конца.
PlayAnimAndWait(Agent : agent, Anim : animation_sequence)<suspends> : logic =
    if:
        Character := Agent.GetFortCharacter[]
        Controller := Character.GetPlayAnimationController[]
    then:
        Result := Controller.PlayAndAwait(Anim)
        case (Result):
            play_animation_result.Completed   => true
            play_animation_result.Interrupted => false
            play_animation_result.Error       => false
    else:
        # Тела нет — не роняем петлю, просто говорим "не проиграли".
        Print("anim: нет fort_character или контроллера")
        false

# ---------- Вариант 2: запустить и не ждать ----------
# Для реакций, которые идут фоном: получил добычу, махнул рукой,
# а логика уже поехала дальше.
PlayAnimNow(Agent : agent, Anim : animation_sequence, Rate : float) : void =
    if:
        Character := Agent.GetFortCharacter[]
        Controller := Character.GetPlayAnimationController[]
    then:
        Controller.Play(
            Anim,
            ?PlayRate := Rate,
            ?BlendInTime := 0.15,
            ?BlendOutTime := 0.25,
            ?StartPositionSeconds := 0.0)

# ============================================================
#  Тестовое устройство.
#  Ставится на карту с одной кнопкой — жмёшь и сразу видишь,
#  играет анимация или нет. Проверяй на нём ДО того, как
#  встраивать анимацию в петлю рыбалки.
# ============================================================

anim_test := class(creative_device):

    @editable
    PlayButton : button_device = button_device{}

    # Скорость: 1.0 — как есть, 2.0 — вдвое быстрее.
    @editable
    PlayRate : float = 1.0

    OnBegin<override>()<suspends> : void =
        PlayButton.InteractedWithEvent.Subscribe(OnPressed)

    OnPressed(Agent : agent) : void =
        spawn{ PlayOnce(Agent) }

    PlayOnce(Agent : agent)<suspends> : void =
        # ↓↓↓ ЕДИНСТВЕННАЯ СТРОКА, КОТОРУЮ НАДО ПОПРАВИТЬ ПОД СЕБЯ ↓↓↓
        #
        # Анимации попадают в Verse как сгенерированные имена вида
        #   <ИмяПроекта>.<Папка>.<ИмяАнимации>
        # Например, файл Content/Anims/FishingCast в проекте MyIsland
        # виден как  MyIsland.Anims.FishingCast
        #
        # Где взять точное имя: Content Browser → правый клик по
        # анимации → Copy Reference, либо просто начни печатать имя
        # проекта — автодополнение Verse покажет, что доступно.
        #
        # Если анимаций в проекте ещё нет — импортируй любую .fbx
        # анимацию в Content, она появится здесь автоматически.

        Anim := MyIsland.Anims.FishingCast

        # ↑↑↑ ЗАМЕНИ MyIsland.Anims.FishingCast НА СВОЁ ↑↑↑

        Ok := PlayAnimAndWait(Agent, Anim)
        Print("anim finished: {Ok}")
