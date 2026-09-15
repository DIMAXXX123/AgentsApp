# UEFN MCP — как работает

С 20 августа 2026 Unreal MCP (появился в UE 5.8) встроен **прямо в UEFN**,
отдельный плагин ставить не надо.

## Механика

- Внутри процесса редактора поднимается MCP-сервер на **локальном HTTP**.
- Любой MCP-клиент (Claude Code, Cursor, MCP Inspector) подключается и
  дёргает типизированные тулы, сгруппированные в **toolsets**.
- Включение: Project Settings → beta access → toolset **UEFN MCP** →
  редактор сгенерирует конфиг для подключения агента.

## Что агент умеет

- читать / писать / компилировать **Verse**, искать по файлам, чинить
  ошибки компиляции итеративно
- ставить и настраивать **девайсы** на карте
- создавать сущности **Scene Graph**
- собирать UI на **UMG**
- запускать **play-сессии** для теста

## Community-серверы

Если нужен доступ шире официального toolset:

- [KirChuvakov/uefn-mcp-server](https://github.com/KirChuvakov/uefn-mcp-server)
  — ~22–28 тулов: actors, assets, levels, viewport, лог, произвольный
  Python. Чистый Python, без сборки C++.
- [quangdang46/uefn-verse-mcp](https://github.com/quangdang46/uefn-verse-mcp)
  — мост Verse / редактор.
- [tomV12/uefn-mcp](https://lobehub.com/mcp/tomv12-uefn-mcp) — анализ
  проекта: индексирует девайсы, события, currency-потоки, парсит
  `config_dump.txt`.
- [Verse Docs MCP](https://mcpmarket.com/server/verse-docs) — документация
  Verse и UEFN API. Ставить обязательно: без неё агент выдумывает имена
  девайсов и опций.

## Генерация моделей

**UEFN MCP сам 3D-меши не генерирует** — он управляет редактором, а не
диффузионной моделью. Варианты:

1. **Modeling Mode внутри UEFN** — процедурное моделирование в редакторе;
   через тул `execute_python` (community-серверы) можно скриптовать
   создание и трансформацию геометрии.
2. **Внешние text-to-3D / image-to-3D** → импорт как custom asset:
   [3DAI Studio](https://www.3daistudio.com/UseCases/FortniteUEFN),
   [UEFN Central Asset Generator](https://uefncentral.com/asset-generator).
   Там же оптимизация полигонажа, quad-топология, авто-LOD под лимиты UEFN.
3. **Связка:** агент через MCP импортирует готовый `.fbx` / `.glb`, ставит
   в уровень, прописывает Verse-логику.

Ограничения UEFN никуда не деваются: лимиты памяти проекта, только
разрешённые форматы, обязательная проверка перед публикацией.

## Внутренние девайсы Fortnite

Агент работает со **встроенными Creative-девайсами**. В Verse они доступны
как классы из `/Fortnite.com/Devices`:

```verse
using { /Fortnite.com/Devices }

my_game := class(creative_device):
    @editable ButtonDevice : button_device = button_device{}
    @editable Spawner : player_spawner_device = player_spawner_device{}

    OnBegin<override>()<suspends> : void =
        ButtonDevice.InteractedWithEvent.Subscribe(OnPressed)

    OnPressed(Agent : agent) : void = ...
```

Основные: `button_device`, `trigger_device`, `timer_device`,
`player_spawner_device`, `item_granter_device`, `hud_message_device`,
`billboard_device`, `conditional_button_device`, `class_designer_device`,
`team_settings_and_inventory_device`, `mutator_zone_device`,
`capture_area_device`, `score_manager_device`, vfx/audio-девайсы.
Полный список — в API-референсе `Fortnite.com/Devices`.

## Источники

- [Unreal MCP is now available in UEFN](https://www.fortnite.com/news/unreal-mcp-is-now-available-in-uefn)
- [UEFN MCP — Epic Developer Community](https://dev.epicgames.com/documentation/fortnite/uefn-mcp?lang=en-US)
- [Modeling in UEFN](https://dev.epicgames.com/documentation/en-us/fortnite/modeling-in-unreal-editor-for-fortnite)
