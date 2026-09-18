# ============================================================
#  cast_hud.verse — HUD ЗАБРОСА ПО РЕФЕРЕНСУ.
#
#  Три элемента из видео:
#    1. Вертикальная СЕГМЕНТНАЯ шкала справа, подпись "МОЩЬ!"
#       Сегменты, а не гладкая заливка: так игрок видит
#       дискретные ступени и легче целится в верх.
#    2. Баннер качества сверху: "ОТЛИЧНЫЙ ЗАБРОС!!"
#    3. Строка результата: дистанция в см + зона + множитель удачи.
#
#  Подсветка сегментов сделана переключением видимости, а не
#  сменой цвета: SetVisibility есть у любого виджета во всех
#  версиях UEFN, а вот SetColor у color_block — не везде.
#  Под горящими ячейками лежит тёмная дорожка, поэтому при
#  выключении ячейки не появляется дыра.
# ============================================================

using { /Fortnite.com/UI }
using { /UnrealEngine.com/Temporary/UI }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Verse.org/Colors }
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }

GaugeCellCount : int   = 7
GaugeCellW     : float = 52.0
GaugeCellH     : float = 34.0
GaugeCellGap   : float = 5.0

PowerLabel<localizes> : message = "МОЩЬ!"

QualityPerfect<localizes> : message = "ОТЛИЧНЫЙ ЗАБРОС!!"
QualityGood<localizes>    : message = "ХОРОШИЙ ЗАБРОС"
QualityWeak<localizes>    : message = "СЛАБЫЙ ЗАБРОС"

ResultLine<localizes>(Distance : int, ZoneName : string, Luck : float) : message =
    "{Distance} см  ·  {ZoneName}  ·  x{Luck} удача"

cast_hud := class:

    var LitCells  : []color_block = array{}
    var DarkCells : []color_block = array{}
    var MaybeUI   : ?player_ui    = false

    QualityText : text_block = text_block:
        DefaultTextColor := NamedColors.White
        DefaultShadowOpacity := 0.9

    ResultText : text_block = text_block:
        DefaultTextColor := NamedColors.White
        DefaultShadowOpacity := 0.9

    LabelText : text_block = text_block:
        DefaultText := PowerLabel
        DefaultTextColor := NamedColors.White
        DefaultShadowOpacity := 0.9

    # Ячейки создаются один раз при показе HUD, а не в объявлении
    # класса: в Verse массив виджетов в поле по умолчанию не собрать.
    BuildCells() : void =
        var Lit  : []color_block = array{}
        var Dark : []color_block = array{}
        for (Index := 0..GaugeCellCount - 1):
            set Dark += array:
                color_block:
                    DefaultColor := NamedColors.Black
                    DefaultOpacity := 0.55
                    DefaultDesiredSize := vector2{ X := GaugeCellW, Y := GaugeCellH }
            set Lit += array:
                color_block:
                    DefaultColor := NamedColors.LimeGreen
                    DefaultOpacity := 1.0
                    DefaultDesiredSize := vector2{ X := GaugeCellW, Y := GaugeCellH }
        set DarkCells = Dark
        set LitCells = Lit

    # Колонка ячеек. Строим СВЕРХУ ВНИЗ, поэтому индексы
    # переворачиваем: нижняя ячейка должна быть первой горящей.
    MakeColumn() : widget =
        var Slots : []stack_box_slot = array{}
        for (Index := 0..GaugeCellCount - 1):
            Flipped := GaugeCellCount - 1 - Index
            if (Dark := DarkCells[Flipped], Lit := LitCells[Flipped]):
                Cell := overlay:
                    Slots := array:
                        overlay_slot{ Widget := Dark }
                        overlay_slot{ Widget := Lit }
                set Slots += array:
                    stack_box_slot:
                        Widget := Cell
                        Padding := margin{ Top := GaugeCellGap * 0.5, Bottom := GaugeCellGap * 0.5, Left := 0.0, Right := 0.0 }
        stack_box{ Orientation := orientation.Vertical, Slots := Slots }

    Show(Player : player) : void =
        if (UI := GetPlayerUI[Player]):
            BuildCells()

            Column := stack_box:
                Orientation := orientation.Vertical
                Slots := array:
                    stack_box_slot{ Widget := MakeColumn() }
                    stack_box_slot{ Widget := LabelText }

            Canvas := canvas:
                Slots := array:
                    # Шкала — справа по центру, как в референсе.
                    canvas_slot:
                        Anchors := anchors{ Minimum := vector2{X := 1.0, Y := 0.5}, Maximum := vector2{X := 1.0, Y := 0.5} }
                        Offsets := margin{ Left := -200.0, Top := -180.0, Right := 120.0, Bottom := 360.0 }
                        Alignment := vector2{ X := 0.0, Y := 0.0 }
                        Widget := Column
                    # Баннер качества — сверху по центру.
                    canvas_slot:
                        Anchors := anchors{ Minimum := vector2{X := 0.5, Y := 0.0}, Maximum := vector2{X := 0.5, Y := 0.0} }
                        Offsets := margin{ Left := -300.0, Top := 90.0, Right := 600.0, Bottom := 60.0 }
                        Alignment := vector2{ X := 0.0, Y := 0.0 }
                        Widget := QualityText
                    # Результат — под баннером.
                    canvas_slot:
                        Anchors := anchors{ Minimum := vector2{X := 0.5, Y := 0.0}, Maximum := vector2{X := 0.5, Y := 0.0} }
                        Offsets := margin{ Left := -300.0, Top := 150.0, Right := 600.0, Bottom := 50.0 }
                        Alignment := vector2{ X := 0.0, Y := 0.0 }
                        Widget := ResultText

            UI.AddWidget(Canvas)
            set MaybeUI = option{UI}
            SetPower(0.0)
            ClearText()

    Hide() : void =
        if (UI := MaybeUI?):
            UI.RemoveAllWidgets()
            set MaybeUI = false

    # Power 0.0..1.0 → сколько ячеек горит снизу.
    SetPower(Power : float) : void =
        Clamped := Clamp(Power, 0.0, 1.0)
        LitCount := Ceil(Clamped * (GaugeCellCount * 1.0))
        for (Index -> Cell : LitCells):
            if (Index < LitCount):
                Cell.SetVisibility(widget_visibility.Visible)
            else:
                Cell.SetVisibility(widget_visibility.Hidden)

    ShowQuality(Power : float, PerfectFrom : float) : void =
        if (Power >= PerfectFrom):
            QualityText.SetText(QualityPerfect)
        else if (Power >= PerfectFrom * 0.6):
            QualityText.SetText(QualityGood)
        else:
            QualityText.SetText(QualityWeak)

    ShowResult(Distance : int, ZoneName : string, Luck : float) : void =
        ResultText.SetText(ResultLine(Distance, ZoneName, Luck))

    ClearText() : void =
        QualityText.SetText(EmptyLine())
        ResultText.SetText(EmptyLine())

EmptyLine<localizes> : message = ""
