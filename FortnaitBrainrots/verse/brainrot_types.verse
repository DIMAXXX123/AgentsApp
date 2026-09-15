# ============================================================
#  brainrot_types.verse — ДАННЫЕ. Здесь нет логики игры.
#  Добавить нового брейнрота = добавить одну строчку в каталог.
# ============================================================

using { /Verse.org/Simulation }
using { /Verse.org/Random }

# ---------- Редкости ----------
# Порядок важен: индекс редкости = индекс в массиве весов зоны.
rarity := enum:
    Common
    Uncommon
    Rare
    Epic
    Legendary
    Mythic

RarityFromIndex(Index : int) : rarity =
    case (Index):
        1 => rarity.Uncommon
        2 => rarity.Rare
        3 => rarity.Epic
        4 => rarity.Legendary
        5 => rarity.Mythic
        _ => rarity.Common

RarityName(R : rarity) : string =
    case (R):
        rarity.Common    => "Обычный"
        rarity.Uncommon  => "Необычный"
        rarity.Rare      => "Редкий"
        rarity.Epic      => "Эпический"
        rarity.Legendary => "Легендарный"
        rarity.Mythic    => "Мифический"

# ---------- Описание одного брейнрота ----------
brainrot_def := class<concrete>:
    Name       : string = "Unknown"
    Rarity     : rarity = rarity.Common
    BaseIncome : int    = 1      # монет/сек на 1 уровне фермы
    SellPrice  : int    = 10     # цена мгновенной продажи

# ---------- Каталог ----------
# Держи здесь минимум по 2 штуки на редкость, иначе пул выбора вырождается.
BrainrotCatalog : []brainrot_def = array:
    brainrot_def{ Name := "Tung Tung Sahur",   Rarity := rarity.Common,    BaseIncome := 1,   SellPrice := 10 }
    brainrot_def{ Name := "Brr Brr Patapim",   Rarity := rarity.Common,    BaseIncome := 1,   SellPrice := 12 }
    brainrot_def{ Name := "Lirili Larila",     Rarity := rarity.Uncommon,  BaseIncome := 4,   SellPrice := 45 }
    brainrot_def{ Name := "Boneca Ambalabu",   Rarity := rarity.Uncommon,  BaseIncome := 5,   SellPrice := 55 }
    brainrot_def{ Name := "Bombardiro",        Rarity := rarity.Rare,      BaseIncome := 12,  SellPrice := 180 }
    brainrot_def{ Name := "Chimpanzini",       Rarity := rarity.Rare,      BaseIncome := 14,  SellPrice := 210 }
    brainrot_def{ Name := "Cappuccino Assasino", Rarity := rarity.Epic,    BaseIncome := 32,  SellPrice := 700 }
    brainrot_def{ Name := "Ballerina Cappucina", Rarity := rarity.Epic,    BaseIncome := 36,  SellPrice := 820 }
    brainrot_def{ Name := "Tralalero",         Rarity := rarity.Legendary, BaseIncome := 90,  SellPrice := 2400 }
    brainrot_def{ Name := "Trippi Troppi",     Rarity := rarity.Legendary, BaseIncome := 105, SellPrice := 2900 }
    brainrot_def{ Name := "La Vacca Saturno",  Rarity := rarity.Mythic,    BaseIncome := 260, SellPrice := 9000 }

# ---------- Зоны воды ----------
# Weights — по индексу редкости: [Common, Uncommon, Rare, Epic, Legendary, Mythic]
# MinStrength — сколько силы нужно, чтобы шкала вообще дотягивала до зоны.
zone_def := class<concrete>:
    Zone        : int   = 1
    Weights     : []int = array{100, 0, 0, 0, 0, 0}
    MinStrength : int   = 1
    Distance    : float = 1200.0   # units от пирса до полосы

ZoneTable : []zone_def = array:
    zone_def{ Zone := 1, Weights := array{80, 18,  2,  0,  0,  0}, MinStrength := 1,  Distance := 1200.0 }
    zone_def{ Zone := 2, Weights := array{55, 32, 11,  2,  0,  0}, MinStrength := 3,  Distance := 2400.0 }
    zone_def{ Zone := 3, Weights := array{30, 35, 25,  9,  1,  0}, MinStrength := 6,  Distance := 3600.0 }
    zone_def{ Zone := 4, Weights := array{12, 26, 34, 22,  6,  0}, MinStrength := 10, Distance := 4800.0 }
    zone_def{ Zone := 5, Weights := array{ 4, 14, 30, 34, 16,  2}, MinStrength := 15, Distance := 6000.0 }
    zone_def{ Zone := 6, Weights := array{ 0,  5, 18, 32, 33, 12}, MinStrength := 22, Distance := 7200.0 }

MaxZoneIndex : int = 6

# ---------- Ролл ----------
SumInts(Values : []int) : int =
    var Total : int = 0
    for (V : Values):
        set Total += V
    Total

# Взвешенный выбор редкости для зоны.
# Билетный метод: тянем число 1..Total и идём по накопленной сумме весов.
RollRarity(Zone : int) : rarity =
    if:
        Table := ZoneTable[Zone - 1]
        Total := SumInts(Table.Weights)
        Total > 0
    then:
        Ticket := GetRandomInt(1, Total)
        var Acc : int = 0
        for (Index -> Weight : Table.Weights):
            set Acc += Weight
            if (Ticket <= Acc):
                return RarityFromIndex(Index)
        rarity.Common
    else:
        rarity.Common

# Сначала решаем редкость, потом равновероятно берём из пула этой редкости.
# Так добавление нового брейнрота не меняет баланс — только разнообразие.
PickBrainrot(Zone : int) : ?brainrot_def =
    Target := RollRarity(Zone)
    var Pool : []brainrot_def = array{}
    for (Def : BrainrotCatalog, Def.Rarity = Target):
        set Pool += array{Def}
    if (Pool.Length > 0, Pick := Pool[GetRandomInt(0, Pool.Length - 1)]):
        option{Pick}
    else if (Fallback := BrainrotCatalog[0]):
        option{Fallback}
    else:
        false
