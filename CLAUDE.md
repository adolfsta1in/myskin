# MySkin — дневник псориаза (iOS)

Приложение для людей с псориазом. Ежедневный чек-ин (зуд, боль, сон, триггеры), карта тела с оценкой зон (BSA, индекс тяжести, особые зоны), фото по зонам, план лечения с напоминаниями, опросники DLQI и PEST, экстренные предупреждения (красные флаги) и отчёт для врача в PDF.

Приложение — **дневник, а не медицинское изделие**: оно не ставит диагноз и не назначает лечение. Все подсказки формулируются как «discuss with your doctor».

Сейчас проект — UI-демо, которое пошагово превращается в MVP. Модель (`AppStore` с моками) заменяется на SwiftData, экраны переводятся на реальные данные.

## Рамки MVP
- Только **псориаз**: экзема и себорейный дерматит удаляются.
- Интерфейс на **английском**. Общение с пользователем и документы — на русском.
- Только локальные данные, без бэкенда и аккаунтов.
- Работаем **только в симуляторе**: Development Team не задан, на устройство не ставим.
- Фото: системная камера (`UIImagePickerController`) + `PhotosPicker`. В симуляторе камеры нет — проверяем через медиатеку.
- Препараты: встроенный справочник (`MedicationCatalog`) + «свой препарат».
- Режим Calm/Flare определяется автоматически (`FlareDetector`), ручного переключателя нет.

## Стек
- iOS 27, только iPhone, портретная ориентация. SwiftUI, Liquid Glass, Swift Charts.
- SwiftData с `VersionedSchema` с первого дня. Фото — файлы в Application Support, не в БД.
- `@Observable` + `@Environment`. Combine не используем, только async/await.
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Swift 6 language mode — с шага 3 плана.
- Тесты: Swift Testing (`import Testing`), таргет `MySkinTests` — с шага 4.
- Проект: `Untitled Project.xcodeproj`, таргет и схема `MyApp`, display name «MySkin».

## Структура папок
Текущая (демо):
```
MyApp/
  MyApp.swift          точка входа, AppStore в environment
  Model/               AppStore (моки, будет удалён), Models (BodyZone и пр.)
  Screens/             MainTabView+RootView, Today, BodyMap, Photos, ZoneProgress,
                       Treatment, Insights, DoctorReport, PrivacyLock
  Onboarding/          OnboardingFlow, OnboardingStepsIntro, OnboardingStepsSetup
  DesignSystem/        Theme, Components, SharedViews (BodySilhouette, графики)
  Canvas/              DesignCanvasView (только DEBUG)
docs/                  spec, research, current-state, migration-plan
```
Целевая: `App/`, `Model/Domain/`, `Model/Persistence/`, `Logic/`, `Services/`, `Screens/<Раздел>/`, `Onboarding/`, `DesignSystem/`, `Preview/`, `MySkinTests/`. Подробности — в migration-plan, часть 2.

## Правила кода
- Делай **ровно текущий шаг плана**. Без попутных правок в других местах — если они нужны, предложи отдельным шагом.
- Стиль как в окружающем коде: отступ 4 пробела, PascalCase для типов, camelCase для членов, `@State private var`, без force unwrap.
- Используй дизайн-систему: `Theme`, `glassCard()`, `screenScaffold()`, `SectionHeader`, `TagChip`, `PrimaryButton`, `.rounded(...)`. Новые цвета и шрифты не вводи.
- Бизнес-логика — чистые функции в `Logic/`, покрытые тестами. Во view только отображение.
- В данных хранятся **стабильные id**: id зон (`front.elbow.left`), строковые rawValue enum. Отображаемые имена в данных не храним. Существующие rawValue не переименовываем: так хранятся данные.
- Моки — только в `Preview/PreviewData` под `#if DEBUG`. В боевом коде моков нет.
- Новые API (Liquid Glass, SwiftUI 27, SwiftData) сверяй через `DocumentationSearch`.
- Проверка шага: `BuildProject`, тесты, затем критерий готовности шага в симуляторе. Отчитывайся честно: что проверено, а что нет.
- Один шаг — один коммит: `Step N: <кратко>`. Push — только с подтверждения пользователя.

## Безопасность данных (здоровье и фото)
- Фото — только в контейнере приложения (`Application Support/Photos`), с `FileProtectionType.complete` и исключением из бэкапа. **Никогда** не сохранять в системную медиатеку.
- Хранилище SwiftData — с защитой файлов. Без сторонней аналитики, SDK и сетевых запросов.
- Блокировка: `LAContext` с откатом на код-пароль; размытие содержимого при `.inactive`.
- Тексты уведомлений нейтральные, без диагноза и препаратов.
- Перед отправкой отчёта или экспорта — предупреждение, что это медицинские данные.
- В интерфейсе не обещать того, что не реализовано («protected by Face ID», «stored only on device» и т. п.).
- Красные флаги (пустулы + температура, эритродермия) всегда показываются, их нельзя скрыть настройками.

## Документы (читать по ситуации)
- `docs/migration-plan.md` — **читать в начале каждой сессии**. Часть 2 — пошаговый план (Шаг 1…44): цель, файлы, зависимости и критерий готовности каждого шага. Часть 1 — gap-анализ и модель данных (§1.5), правило автоматического режима (§1.6).
- `docs/spec.md` — читать, когда шаг касается конкретной функции: какие поля собирать, шкалы, пороги, экраны (§2 — данные, §3 — модель, §5 — экраны, §8 — состав MVP).
- `docs/current-state.md` — читать, когда меняешь существующий демо-файл: что в нём заглушка, а что работает.
- `docs/reaserch.md` — медицинский первоисточник. Читать только при сомнениях в медицинском содержании (шкалы, препараты, триггеры).

## Статус
- **Текущий шаг: Шаг 8** — SwiftData: лечение, дозы, фото, опросники (этап A).
- Готово: фазы анализа (spec, current-state, migration-plan), этап 0 целиком:
  - Шаг 1 — git + GitHub `adolfsta1in/myskin`, `CLAUDE.md`;
  - Шаг 2 — bundle id `com.adolfsta1in.myskin`, usage descriptions для Face ID и камеры;
  - Шаг 3 — Swift 6; `Shape`-типы помечены `nonisolated`, т. к. по умолчанию всё на MainActor;
  - Шаг 4 — таргет `MySkinTests` (Swift Testing, Swift 6, MainActor по умолчанию, хост — `MyApp`, доступен `@testable import MyApp`), подключён к схеме `MyApp`; тесты запускаются через `RunAllTests` / ⌘U.
  - Этап A:
    - Шаг 5 — `Model/Domain/DomainEnums.swift` (`nonisolated`, `String` rawValue, `Codable`); `TreatmentKind` перенесён туда из `Models.swift`. Тест фиксирует rawValue.
    - Шаг 6 — `Model/Domain/BodyZone.swift` (`BodySide`, `BodyRegion`, `ZoneShapeKind`, `BodyZone`). Quick-зоны: scalp, face, nails, palms, soles, folds, genitals — все `isSpecialSite`. Ягодицы (`*.pelvis`) — регион legs, как в PASI. Внимание для шага 11: `front.head` («Face» на силуэте) и `quick.face` пересекаются по площади.
    - Шаг 7 — `Model/Persistence/SchemaV1.swift`: модели вложены в `enum SchemaV1: VersionedSchema`, наружу — `typealias`. Enum хранятся строками (`…ID`/`…IDs`) с вычисляемыми типизированными свойствами. `DailyCheckIn.day` — `.unique` (одна запись на день), `ZoneAssessment` — `#Unique([day, zoneID])`; день нормализуется в `startOfDay` в `init`.
- Замечание по сборке: `BuildProject(buildForTesting:)` не пересобирает `MyApp` перед тестами — сначала обычный `BuildProject`, потом `RunAllTests`.
- После каждого шага: отметить ✅ в `docs/migration-plan.md` и обновить этот раздел.
