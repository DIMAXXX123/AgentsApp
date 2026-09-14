# ============================================================
#  power_bar.verse — UMG-шкала силы заброса.
#
#  Устройство: три прямоугольника в overlay, выровненных по низу/верху.
#    Track   — тёмный фон на всю высоту
#    Fill    — зелёная заливка, растёт снизу вверх (её высоту мы и меняем)
#    Perfect — красная полоска у самого верха = "идеальное" окно
#
#  Почему заливка, а не бегающий маркер: сменить размер виджета можно
#  на лету (SetDesiredSize), а сдвинуть его в canvas_slot — нельзя без
#  пересоздания слота. Заливка даёт тот же геймплей дешевле.
# ============================================================

using { /Fortnite.com/UI }
using { /UnrealEngine.com/Temporary/UI }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Verse.org/Colors }
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }

BarWidth     : float = 46.0
BarHeight    : float = 320.0
PerfectBand  : float = 0.07   # верхние 7% шкалы = идеальный бросок

power_bar := class:

    Track : color_block = color_block:
        DefaultColor       := NamedColors.Black
        DefaultOpacity     := 0.55
        DefaultDesiredSize := vector2{ X := BarWidth, Y := BarHeight }

    Fill : color_block = color_block:
        DefaultColor       := NamedColors.LimeGreen
        DefaultOpacity     := 0.95
        DefaultDesiredSize := vector2{ X := BarWidth, Y := 1.0 }

    Perfect : color_block = color_block:
        DefaultColor       := NamedColors.Red
        DefaultOpacity     := 0.85
        DefaultDesiredSize := vector2{ X := BarWidth, Y := BarHeight * PerfectBand }

    var MaybeUI : ?player_ui = false

    MakeWidget() : widget =
        Stack := overlay:
            Slots := array:
                overlay_slot:
                    Widget               := Track
                    HorizontalAlignment  := horizontal_alignment.Center
                    VerticalAlignment    := vertical_alignment.Bottom
                overlay_slot:
                    Widget               := Fill
                    HorizontalAlignment  := horizontal_alignment.Center
                    VerticalAlignment    := vertical_alignment.Bottom
                overlay_slot:
                    Widget               := Perfect
                    HorizontalAlignment  := horizontal_alignment.Center
                    VerticalAlignment    := vertical_alignment.Top
        Stack

    Show(Player : player) : void =
        if (UI := GetPlayerUI[Player]):
            Canvas := canvas:
                Slots := array:
                    canvas_slot:
                        Anchors   := anchors{ Minimum := vector2{X := 0.5, Y := 0.5}, Maximum := vector2{X := 0.5, Y := 0.5} }
                        Offsets   := margin{ Left := 300.0, Top := BarHeight * -0.5, Right := BarWidth, Bottom := BarHeight }
                        Alignment := vector2{ X := 0.0, Y := 0.0 }
                        Widget    := MakeWidget()
            UI.AddWidget(Canvas, player_ui_slot{ InputMode := ui_input_mode.None })
            set MaybeUI = option{UI}

    Hide() : void =
        if (UI := MaybeUI?):
            UI.RemoveAllWidgets()
            set MaybeUI = false

    # Power: 0.0 .. 1.0
    SetPower(Power : float) : void =
        Clamped := Clamp(Power, 0.0, 1.0)
        Fill.SetDesiredSize(vector2{ X := BarWidth, Y := Max(1.0, BarHeight * Clamped) })

# Идеальный бросок — попадание в верхнюю полосу.
# Сила игрока расширяет окно, но НЕ поднимает потолок:
# прокачка делает попадание вероятнее, а не бросок дальше.
IsPerfect(Power : float, Strength : int) : logic =
    Window := PerfectBand + (Strength * 0.004)
    Power >= 1.0 - Window
