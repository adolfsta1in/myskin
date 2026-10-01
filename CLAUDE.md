# MySkin — дневник псориаза (iOS)

Приложение для людей с псориазом. Ежедневный чек-ин (зуд, боль, сон, триггеры), карта тела с оценкой зон (BSA, индекс тяжести, особые зоны), фото по зонам, план лечения с напоминаниями, опросники DLQI и PEST, экстренные предупреждения (красные флаги) и отчёт для врача в PDF.

Приложение — **дневник, а не медицинское изделие**: оно не ставит диагноз и не назначает лечение. Все подсказки формулируются как «discuss with your doctor».

Сейчас проект — UI-демо, которое пошагово превращается в MVP. Модель (`AppStore` с моками) заменяется на SwiftData, экраны переводятся на реальные данные.

## Рамки MVP
- Только **псориаз**: экзема и себорейный дерматит удаляются.
- Интерфейс на **английском**. Общение с пользователем и документы — на русском.
- Только локальные данные, без бэкенда и аккаунтов.
- Проверяем в симуляторе. Development Team `3RTVRU8JMK` задан у `MyApp` и `MySkinTests` (у тестов — обязательно, иначе они не собираются), чтобы пользователь мог поставить приложение на свой iPhone. Сами на устройство не ставим.
- Фото: системная камера (`UIImagePickerController`) + `PhotosPicker`. В симуляторе камеры нет — проверяем через медиатеку.
- Препараты: встроенный справочник (`MedicationCatalog`) + «свой препарат».
- Режим Calm/Flare определяется автоматически (`FlareDetector`), ручного переключателя нет.

## Стек
- SDK iOS 27, **минимальная версия iOS 26.0** (чтобы запускать на iPhone 11 пользователя с iOS 26.5). API только из iOS 27 — лишь под `if #available(iOS 27, *)`. Только iPhone, портретная ориентация. SwiftUI, Liquid Glass, Swift Charts.
- SwiftData с `VersionedSchema` с первого дня. Фото — файлы в Application Support, не в БД.
- `@Observable` + `@Environment`. Combine не используем, только async/await.
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Swift 6 language mode — с шага 3 плана.
- Тесты: Swift Testing (`import Testing`), таргет `MySkinTests` — с шага 4.
- Проект: `Untitled Project.xcodeproj`, таргет и схема `MyApp`, display name «MySkin».

## Структура папок
Текущая (демо):
```
MyApp/
  App/                 MyApp.swift (точка входа, AppStore + modelContainer)
  Model/               AppStore (моки, будет удалён), Models (остатки демо)
    Domain/            DomainEnums, BodyZone
    Persistence/       SchemaV1, MigrationPlan, AppModelContainer
  Preview/             PreviewData (только DEBUG)
  Screens/             MainTabView+RootView, Today/ (TodayView, CheckInDraft), BodyMap, Photos, ZoneProgress,
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
- **Текущий шаг: Шаг 35** — Экран экстренного предупреждения.
- Готово: фазы анализа (spec, current-state, migration-plan), этап 0 целиком:
  - Шаг 1 — git + GitHub `adolfsta1in/myskin`, `CLAUDE.md`;
  - Шаг 2 — bundle id `com.adolfsta1in.myskin`, usage descriptions для Face ID и камеры;
  - Шаг 3 — Swift 6; `Shape`-типы помечены `nonisolated`, т. к. по умолчанию всё на MainActor;
  - Шаг 4 — таргет `MySkinTests` (Swift Testing, Swift 6, MainActor по умолчанию, хост — `MyApp`, доступен `@testable import MyApp`), подключён к схеме `MyApp`; тесты запускаются через `RunAllTests` / ⌘U.
  - Этап A:
    - Шаг 5 — `Model/Domain/DomainEnums.swift` (`nonisolated`, `String` rawValue, `Codable`); `TreatmentKind` перенесён туда из `Models.swift`. Тест фиксирует rawValue.
    - Шаг 6 — `Model/Domain/BodyZone.swift` (`BodySide`, `BodyRegion`, `ZoneShapeKind`, `BodyZone`). Quick-зоны: scalp, face, nails, palms, soles, folds, genitals — все `isSpecialSite`. Ягодицы (`*.pelvis`) — регион legs, как в PASI. Внимание для шага 11: `front.head` («Face» на силуэте) и `quick.face` пересекаются по площади.
    - Шаг 7 — `Model/Persistence/SchemaV1.swift`: модели вложены в `enum SchemaV1: VersionedSchema`, наружу — `typealias`. Enum хранятся строками (`…ID`/`…IDs`) с вычисляемыми типизированными свойствами. `DailyCheckIn.day` — `.unique` (одна запись на день), `ZoneAssessment` — `#Unique([day, zoneID])`; день нормализуется в `startOfDay` в `init`.
    - Шаг 8 — `Treatment` (расписание: `scheduleKind` + `timesPerDay`/`interval`/`weekday`/`doseMinutes`), `DoseLog` (каскад от `Treatment`), `Photo`, `QuestionnaireResult`; `MigrationPlan.swift` (`MySkinMigrationPlan`, стадий нет). У новой модели **нет** `typealias Treatment` — имя занято демо-структурой; до шага 22 писать `SchemaV1.Treatment`.
    - Шаг 9 — `App/MyApp.swift` (`.modelContainer`), `Model/Persistence/AppModelContainer.swift` (`makePersistent`: `Application Support/Store/MySkin.store`, без CloudKit, папка и файлы с `.completeUnlessOpen` — чтобы открытая SQLite могла дописать при блокировке; `makeInMemory` для превью и тестов). `Preview/PreviewData.swift` (DEBUG): профиль, 14 чек-инов, оценки зон, 4 лечения с дозами, DLQI/PEST; фото нет. `previewSetup` и `DesignCanvasView` подключают `PreviewData.container`. При ошибке открытия хранилища — `fatalError` (без тихого пустого хранилища).
    - Шаг 10 — `App/AppSettings.swift` (`@Observable` поверх `UserDefaults`, ключи в `AppSettings.Key` не переименовывать; время чек-ина хранится как `checkInMinutes`). `RootView`, `OnboardingFlow`, `NotificationsStep`, `PrivacyStep`, `PlanReadyStep` читают настройки отсюда; из `AppStore` поля удалены, `isLocked` остался (состояние сессии). `faceIDEnabled` по умолчанию **false** — настоящей блокировки ещё нет (шаг 37). Превью — `PreviewData.settings` (отдельный suite). Тесты 23/23. Критерий «онбординг → перезапуск → сразу вкладки» проверен пользователем в симуляторе.
  - Этап B:
    - Шаг 11 — `Logic/SeverityCalculator.swift`: вход — `ZoneScore` (копия `ZoneAssessment`, `.score`), выход — `SeveritySnapshot` (BSA, индекс 0–72, `specialSiteIDs`, `category`, `isElevated`). Площадь зоны ограничена `BodyZone.area`, площадь региона — суммой зон силуэта (quick-зоны лежат внутри силуэта, так снято перекрытие `front.head`/`quick.face`), BSA ≤ 100. Правило десяток: BSA/индекс/DLQI > 10 → severe; особая зона или `arthritisSuspected` поднимают mild → moderate. Пороги — `SeverityCalculator.Threshold`. Тесты 54/54.
    - Шаг 12 — `Logic/Questionnaires.swift`: `Question`/`QuestionOption`, `Questionnaires.score(kind, answers:)` (ответы — **индексы вариантов**, чтобы «Not relevant» отличался от «Not at all»; неполные/неверные → nil). `DLQI`: 10 вопросов, полосы 0–1/2–5/6–10/11–20/21–30, `isAtGoal` (≤1), `isVeryLargeEffect` (>10). `PEST`: 5 да/нет, ≥3 → ревматолог. Тексты — стандартные английские формулировки; лицензия DLQI (Cardiff University) не оформлена. Тесты 76/76.
    - Шаг 13 — `Logic/FlareDetector.swift`: `status(on:checkIns:zones:)` → `FlareStatus` (`AppMode` + `[FlareReason]` с `explanation` + `signalDay`). День «с признаком» — если сработало любое правило §1.6; Flare, пока признак есть в одном из последних 3 дней (`calmDays`), дни без чек-ина считаются днями без признаков. Зоны — последнее состояние каждой зоны; первая карта не даёт Flare. Пороги — `FlareDetector.Threshold`. Тесты 92/92.
    - Шаг 13.1 — минимального числа чек-инов для Flare нет: зуд ≥ 7 или «new spots» дают Flare с первого чек-ина (решение пользователя); ≥ 3 прошлых чек-инов нужны только для правила «выше среднего».
    - Шаг 14 — `Logic/RedFlagRules.swift`: `flags(zones:symptoms:isFlare:)` → `[RedFlag]`. Пустулы ≥ 5 % BSA + температура/слабость; покраснение > 75 % BSA (само по себе, озноб не обязателен); ухудшение после отмены системных стероидов при Flare. Симптомы (`RedFlagSymptoms`) в схеме не хранятся — их спросит чек-ин в режиме Flare. PHQ-9 не входит в MVP — не проверяется. В `ZoneScore` добавлено `pustules`. Тесты 102/102.
    - Шаг 15 — `Model/Domain/MedicationCatalog.swift`: 39 позиций (`Medication`: стабильный `id` для `Treatment.catalogID` — не переименовывать, `kind`, `MedicationCategory`, `steroidClass?`, `TypicalSchedule`, `notes`). Биологики — интервал поддерживающей фазы (стартовые дозы — в `notes`). Классы стероидов (US) и режимы требуют сверки врачом/фармацевтом. Тесты 110/110.
    - Шаг 16 — `Logic/DoseScheduler.swift`: вход — `DoseSchedule` (`treatment.doseSchedule`) и `LoggedDose` (`doseLog.logged`). `doses(on:)` → `[ScheduledDose]` со статусом (лог закрывает слот по точному `scheduledAt`); `nextDose(onOrAfter:)` — первая неотмеченная доза с начала дня. Времена по умолчанию 08:00…20:00; интервальные схемы привязаны к `startDate` (поздняя инъекция не сдвигает график); после `endDate` доз нет. Тесты 124/124.
    - Шаг 16.1 — `front.head` («Face» на силуэте) — особая зона (`isSpecialSite`), `back.head` — нет (волосистую часть покрывает `quick.scalp`).
  - Этап C:
    - Шаг 17 — `Screens/Today/TodayView.swift` (перенесён в папку), `CheckInCard` работает с `DailyCheckIn` через `@Query` за сегодня; черновик — `Screens/Today/CheckInDraft.swift` (боль/сон/настроение `nil`, пока не тронуты; триггеры из `Trigger` + свои теги из прошлых чек-инов). В Calm детали раскрываются кнопкой, во Flare видны всегда. Убраны несохраняемые чипы «Where is it flaring?» и надпись «Take a photo». Из `AppStore` удалены `todayItch`, `selectedTags`, `tags`, `toggleTag`. Тесты 130/130; критерий проверен в симуляторе (сохранить → перезапуск → значения на месте, «Update check-in»).
    - Шаг 18 — `Logic/TodayStats.swift`: `itchHistory` (14 дней, только дни с чек-ином), `itchTrend` (среднее 7 дней vs предыдущие 7, ≥ 3 чек-инов в каждой половине, порог 1 балл), `calmDaysThisMonth` (дни месяца с чек-ином без сигналов `FlareDetector.signals`; дни без чек-ина не считаются). `ItchChartCard`/`CalmDaysCard` — через `@Query`, пустые состояния. Из `AppStore` удалён `calmDaysThisMonth` (`itchHistory` ещё нужен онбордингу). Development Team прописан и у `MySkinTests`. Тесты 142/142.
    - Шаг 19 — `Picker` Calm/Flare удалён: `TodayView` считает `FlareDetector.status` из `@Query` (чек-ины + оценки зон), `ModeBanner` — «Calm mode» или раскрывающаяся «Flare mode · why?» со списком `FlareReason.explanation`, днём сигнала и «discuss it with your doctor». Параметр `todayMode` убран из `MainTabView`; для превью и канваса — `PreviewData.flareContainer` (сегодня зуд 8 + new spots). `.modelContainer` в превью ставить **до** `previewSetup()` — ближний к view побеждает. Тесты 143/143.
    - Шаг 20 — `Screens/Body/` (туда перенесён `BodyMapView`): `ZoneAssessmentDraft` (площадь в ладонях 0…`zone.area`, шаг 0.1 для зон ≤ 1 %, иначе 0.5; признаки 0–4; пустулы; `save` — upsert записи зоны за день; `latest`), `ZoneAssessmentSheet` (подсказка про тёмную кожу у покраснения, «Clear this area» сохраняет зону чистой — история не стирается), `SignScale` — подписи 0–4. Тап по силуэту и quick-зоне открывает лист. Ногти/пигментация из spec §3 в схеме нет — не собираются. Тесты 148.
    - Шаг 21 — `Logic/BodyMapSummary.swift`: текущая карта = последняя оценка каждой зоны; `previous` — карта до последнего дня оценки («vs previous assessment»); `SeverityCalculator.level` (0–3 по среднему трёх признаков; зона только с площадью/пустулами — 1). `BodyMapView` без `AppStore`: окраска, quick-зоны и карточка (BSA, категория, индекс, изменение, «Elevated» с особыми зонами или PEST ≥ 3 + «discuss systemic treatment with your doctor», дата) из `@Query`; DLQI/PEST — последние результаты. `IntensityLegend`: Clear/Mild/Moderate/Severe. Из `AppStore` удалён `lastWeekArea` (`zoneIntensity`/`affectedArea` ещё нужны онбордингу и отчёту). Тесты 161/161.
    - Шаг 22 — `Screens/Treatment/TreatmentView.swift` (перенесён): `@Query` по `Treatment`, группы (Creams & ointments = cream/ointment/foam/shampoo, Tablets, Biologics, Phototherapy) + «Stopped»; пустое состояние с «Add treatment». Демо-структура переименована в `DemoTreatment` (её ещё читает `DoctorReportView`), добавлен `typealias Treatment = SchemaV1.Treatment`. `DoseScheduler.summary(for:)` — текст расписания («Twice a day», «Weekly · Monday», «Every 2 weeks»). Календарь биологика и места инъекций временно убраны — вернутся в шаге 25. Тесты 162.
    - Шаг 23 — `Screens/Treatment/TreatmentDraft.swift` (из справочника — типичное расписание; «свой» — только имя; `apply`/`makeTreatment`; у не-топических препаратов зоны/класс/FTU обнуляются; `stop`/`resume`; `search`; `sensitiveAreaWarning` — стероид класса I–II на лице/складках/гениталиях). `TreatmentEditor.swift`: `AddTreatmentSheet` (поиск по `MedicationCatalog` с секциями + «Custom…») → `TreatmentEditor` (Form: имя, тип, класс, FTU, расписание и время доз, дата начала, зоны через `ZonePicker`, заметка; для сохранённого — Stop с причиной / Resume / Delete). Тап по карточке открывает редактор. Тесты 170.
    - Шаг 24 — `Screens/Today/DoseRows.swift`: `rows(for:on:)` — дозы активных лечений на день через `DoseScheduler` (по времени, затем имени); `toggle` — пишет `DoseLog(scheduledAt:, .done, FTU)` или удаляет отметку. `RemindersCard` читает активные `Treatment` через `@Query`, пустые состояния. Из `AppStore` удалены `reminders`, из `Models` — `TreatmentReminder`. Тесты 174.
    - Шаг 25 — `Logic/InjectionPlan.swift`: `lastSite` (последний лог с местом), `suggestedSite` (по кругу `InjectionSite.allCases`), `daysUntilNextDose` (через `DoseScheduler.nextDose`, отмеченная доза сдвигает на следующую), `countdownText`. В `TreatmentView`: у активного биологика — полоса 14 дней с реальным днём дозы (подпись — день недели), под группой Biologics — `InjectionSitesCard` по `DoseLog`. На Today отметка инъекции спрашивает место (`confirmationDialog`, предложенное — первым). Инъекцию вне расписания отметить нельзя. Из `AppStore` удалены `lastInjectionSite`/`suggestedInjectionSite`. Тесты 178.
    - Шаг 26 — `Services/PhotoStore.swift` (`nonisolated`, `Sendable`): папка `Application Support/Photos` (`.complete`, вне бэкапа), `save(imageData:)` — перекодирование через ImageIO в JPEG ≤ 2048 px **без метаданных** (геолокация не сохраняется), файлы с `.completeFileProtection` и `isExcludedFromBackup`; `data`, `thumbnail`, `delete`, `exists`; имя файла без путей. Тесты на временной папке, класс защиты проверяется. Тесты 182.
    - Шаг 27 — `Screens/Photos/` (туда перенесён `PhotosView`; группы проекта синхронизируются с ФС — файлы, созданные вне Xcode, попадают в таргет сами). `PhotoRecords`: `add` (файл через `PhotoStore` в фоне через `@concurrent`, затем запись `Photo`; при ошибке записи файл удаляется), `delete`, `zonesWithPhotos`; `PhotoStore.shared`; `StoredPhotoImage` — миниатюра, декодируется не на главном потоке. `PhotoImport`: `.photoImport(zoneID:source:)` — системный `photosPicker` (вне процесса, без доступа к медиатеке), `PhotoZonePicker`. Сетка — зоны с фото из `@Query`, пустое состояние; текст о хранении — только то, что реально сделано. Плитки станут ссылками на `ZoneProgressView` в шаге 29. Тесты 185.
    - Шаг 28 — `Screens/Photos/CameraPicker.swift` — обёртка `UIImagePickerController` (.camera, без сохранения в медиатеку); `PhotoSource.camera` показывается только при `CameraPicker.isAvailable` (в симуляторе скрыт). Снимок → `jpegData(0.95)` → `PhotoRecords.add` (перекодирование с учётом ориентации). Удалены `CameraOverlayView` и `GhostOutline` (и из канваса). На устройстве съёмка не проверялась.
    - Шаг 29 — `Screens/Photos/ZoneProgressView.swift` (перенесён, `init(zoneID:)`): `@Query` фото зоны; шторка при 2+ фото (старое — «before», новое — «now», сброс при изменении числа фото), одно фото — без шторки; лента миниатюр с контекстным меню (before / now / Delete → `PhotoRecords.delete` удаляет файл и запись); таймлайн — фото + `Treatment.startDate` лечений с этой зоной в `zoneIDs`; «Build timelapse» убран; добавление фото в эту зону. Плитки `PhotosView` ведут сюда. Тесты 185/185.
    - Шаг 30 — Онбординг — 11 шагов: Welcome, **Disclaimer** (нельзя пропустить: Continue и `advance` заблокированы до тумблера «I understand…»), **Your psoriasis** (`PsoriasisType` + год начала / «Not sure»), Skin now, Goals, Insight (тексты про триггеры псориаза: стресс, инфекция, травма кожи, холодный сухой воздух; «days to a few weeks»), Body map, Treatments, Notifications, Privacy, Plan ready. Удалены Condition, Profile (child), Location, Sleep. `Onboarding/OnboardingDraft.swift` (`@Observable`, живёт в `OnboardingFlow` и передаётся через `.environment`) — ответы; на «Start» `save(in:)` пишет `Profile` (существующий обновляется). `PlanReadyStep` показывает формы; кнопка «Save a backup to iCloud» удалена (не реализовано). Из `AppStore` удалены `profile`, `skinNow`, `goals`, `locationAllowed`, `healthAllowed`, `sleepHistory`, из `Models` — `ProfileKind`; `condition` и `scoreName` ещё нужны Insights/DoctorReport. Тесты 188.
    - Шаг 31 — `FirstBodyMapStep` пишет в `OnboardingDraft.zoneLevels` (тап: clear → mild → moderate → severe), BSA в подвале — `SeverityCalculator`; при сохранении уровень → `ZoneAssessment` (площадь = `zone.area` × 0.25/0.5/0.8, все три признака = уровню, чтобы окраска совпала). `TreatmentsStep`: поиск по `MedicationCatalog` + «Add “…”» (свой) + «Nothing right now»; создаются `Treatment` с типичным расписанием и стартом в день онбординга. `SkinNowStep` → `Profile.baselineSelfRating`. Из `AppStore` удалены `currentTreatments`, `cycleIntensity` (`zoneIntensity`/`affectedArea` ещё читает `DoctorReportView`). Тесты 191.
    - Шаг 32 — `Services/NotificationPermission.swift` — `UNUserNotificationCenter.requestAuthorization`. В `NotificationsStep` «Turn on» вызывает системный диалог (если включён хоть один тумблер); при отказе оба тумблера выключаются, «Not now» тоже их выключает — `AppSettings` отражает реальный выбор. Тумблер «Flare forecast» и `AppStore.notifyForecast` удалены; превью уведомления — нейтральный текст. Сами напоминания ещё не планируются (это этап D). Тесты 191/191.
    - Проверка этапа C в симуляторе **iPhone 11** (чистая установка): онбординг → данные во вкладках, чек-ин, дозы, оценка зоны, редактор лечения, фото из медиатеки, шторка при 2 фото, удаление фото — работают. Исправлено по итогам: в симуляторе камера скрывается явно (`targetEnvironment(simulator)` — iOS 27 сообщает о камере), на экране зоны «+» в навбаре, класс стероида везде «Class I». Не проверено: съёмка камерой на устройстве; Flare на 3+ чек-инах в симуляторе (покрыто тестами).
    - Найдено, не исправлено (кандидаты в отдельные шаги): карточка «Skin forecast» на Today — демо-мок с советом; Privacy-шаг обещает Face ID и «stored on this device» до шага 37; в онбординге плавающий подвал перекрывает quick-зоны (карта) и результаты поиска при клавиатуре (лечение); в выборе зоны для фото «Face» встречается дважды (`front.head` и `quick.face`).
  - Этап D:
    - Шаг 33 — `Logic/QuestionnaireSession.swift` (пошаговое прохождение: `answer`/`goBack`, ответ остаётся выбранным при возврате, `makeResult`; `Questionnaires.maxScore/headline/interpretation/needsAttention/intro`). `Screens/Questionnaires/QuestionnaireView` (лист: вступление → по вопросу на странице → результат, сохраняется после последнего ответа; во время прохождения свайп-закрытие отключено), `QuestionnaireHistoryView` (последний балл с интерпретацией + прошлые, удаление через контекстное меню, «Take it again»). Вход — карточка «Questionnaires» на Insights. Тесты 206 (запуск на iPhone A).
    - Шаг 34 — `Logic/QuestionnaireSchedule.swift`: DLQI раз в 30 дней, PEST раз в 91 день от последнего результата; не пройден ни разу — пора сразу. На Today — `QuestionnaireDueCards` («Time for: …»), лист `QuestionnaireView` держит `TodayView` (иначе исчезающая карточка закрыла бы лист с результатом). PEST ≥ 3 → заголовок «Tell a rheumatologist» в результате и истории. Тесты 211.
  - Вне очереди (по просьбе пользователя):
    - Шаг 36 — `Logic/ReminderPlan.swift` (чек-ин — ежедневный повтор в `checkInMinutes`; дозы — открытые дозы активных лечений на 7 дней вперёд, одно напоминание на одно время, лимит 60 из 64 iOS; тексты только «Time for your diary check-in.» / «Time for your treatment.», id с префиксом `myskin.`), `Services/NotificationService.swift` (`sync`: удаляет свои ожидающие и ставит заново; без разрешения ничего не делает и диалог не показывает; `NotificationPresenter` — баннер и при открытом приложении). Перепланирование — `ReminderSync` в `MainTabView` (меняются лечения, отметки доз, настройки, приложение стало активным). В симуляторе iPhone 11 баннер дозы пришёл. Время чек-ина пока меняется только в онбординге — экран настроек в шаге 41. Тесты 199.
- Ресурсы: Mac с 8 ГБ RAM — не держать симулятор и превью без нужды, превью рендерить по одному, симулятор запускать только для критерия шага. Симулятор — **iPhone 11** (легче); перед запуском выключать остальные (`xcrun simctl shutdown all`).
- Известная проблема (не регрессия): превью `DoctorReportView` падает в AttributeGraph (навбар/Liquid Glass) — так же падало и до шага 9.
- Замечание по сборке: `BuildProject(buildForTesting:)` не пересобирает `MyApp` перед тестами — сначала обычный `BuildProject`, потом `RunAllTests`.
- После каждого шага: отметить ✅ в `docs/migration-plan.md` и обновить этот раздел.
