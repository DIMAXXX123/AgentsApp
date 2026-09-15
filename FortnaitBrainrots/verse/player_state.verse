# ============================================================
#  player_state.verse — СОСТОЯНИЕ ИГРОКА И СЕЙВ.
#
#  Ключевое ограничение UEFN: persistable-класс ИММУТАБЕЛЕН.
#  Внутри него нельзя var-поля. Поэтому "изменение" — это
#  создание нового объекта с изменённым полем. Отсюда хелперы
#  WithCoins / WithStrength / WithRod ниже.
# ============================================================

using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }

save_data := class<final><persistable>:
    Version    : int   = 1   # НЕ УДАЛЯЙ. Нужен для миграции без вайпа игроков.
    Coins      : int   = 0
    Strength   : int   = 1
    RodTier    : int   = 1
    FarmIds    : []int = array{}   # индексы в BrainrotCatalog, по слотам
    FarmLevels : []int = array{}   # уровень апгрейда, по тем же слотам

# Модуль-скоуп + var + weak_map = данные переживают сессию.
var PlayerSaves : weak_map(player, save_data) = map{}

GetSave(Player : player) : save_data =
    if (Data := PlayerSaves[Player]):
        Data
    else:
        save_data{}

SetSave(Player : player, Data : save_data) : void =
    if (set PlayerSaves[Player] = Data) {}

# ---------- Иммутабельные апдейтеры ----------
WithCoins(Old : save_data, NewCoins : int) : save_data =
    save_data:
        Version    := Old.Version
        Coins      := NewCoins
        Strength   := Old.Strength
        RodTier    := Old.RodTier
        FarmIds    := Old.FarmIds
        FarmLevels := Old.FarmLevels

WithStrength(Old : save_data, NewStrength : int) : save_data =
    save_data:
        Version    := Old.Version
        Coins      := Old.Coins
        Strength   := NewStrength
        RodTier    := Old.RodTier
        FarmIds    := Old.FarmIds
        FarmLevels := Old.FarmLevels

WithRod(Old : save_data, NewTier : int) : save_data =
    save_data:
        Version    := Old.Version
        Coins      := Old.Coins
        Strength   := Old.Strength
        RodTier    := NewTier
        FarmIds    := Old.FarmIds
        FarmLevels := Old.FarmLevels

# ---------- Операции ----------
AddCoins(Player : player, Amount : int) : void =
    Old := GetSave(Player)
    SetSave(Player, WithCoins(Old, Old.Coins + Amount))

# Failable: не хватило денег — вся покупка откатывается.
TrySpend(Player : player, Amount : int)<decides><transacts> : void =
    Old := GetSave(Player)
    Old.Coins >= Amount
    SetSave(Player, WithCoins(Old, Old.Coins - Amount))

# ---------- Удочки ----------
rod_def := class<concrete>:
    Tier    : int    = 1
    Name    : string = "Палка с верёвкой"
    MaxZone : int    = 2     # дальше этой зоны удочка не добивает
    Price   : int    = 0

RodCatalog : []rod_def = array:
    rod_def{ Tier := 1, Name := "Палка с верёвкой", MaxZone := 2, Price := 0     }
    rod_def{ Tier := 2, Name := "Бамбуковая",       MaxZone := 3, Price := 500   }
    rod_def{ Tier := 3, Name := "Спиннинг",         MaxZone := 4, Price := 2500  }
    rod_def{ Tier := 4, Name := "Карбон",           MaxZone := 5, Price := 12000 }
    rod_def{ Tier := 5, Name := "Гарпун Посейдона", MaxZone := 6, Price := 60000 }

MaxZoneFor(Player : player) : int =
    Save := GetSave(Player)
    if (Rod := RodCatalog[Save.RodTier - 1]):
        Rod.MaxZone
    else:
        2
