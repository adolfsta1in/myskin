# Текущее состояние проекта (октябрь 2026)

Это снимок демо-прототипа MySkin перед переходом к спецификации `docs/spec.md`. Здесь только факты, со ссылками на файлы.

**Статус:** проект — UI-скелет («как будет выглядеть»). Хранения данных, бизнес-логики и интеграций нет. Демо запускалось только в симуляторе Xcode.

**Решения, принятые по итогам анализа:**
- MVP только про **псориаз**;
- язык интерфейса MVP — **английский**;
- реальных пользователей и данных нет.

---

## 0. Проект и сборка

| Параметр | Значение |
|---|---|
| Таргеты | Один: `MyApp` (application). **Тестовых таргетов нет** |
| Платформа | iOS 27.0, только iPhone (`TARGETED_DEVICE_FAMILY = 1`), только портретная ориентация |
| Swift | Language mode 5.0, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, Approachable Concurrency, strict concurrency `minimal` |
| Подпись | Bundle ID — заглушка `devplaceholder…MyApp`, `DEVELOPMENT_TEAM` пуст, entitlements нет |
| Info.plist | Генерируется автоматически. Display name «MySkin». **Нет ни одного usage description**: Face ID, Camera, Health, Location |
| Capabilities | Нет HealthKit, WeatherKit, iCloud, Push |
| Фреймворки | SwiftUI, Charts. Liquid Glass (`glassEffect`, `.glass` / `.glassProminent`, `GlassEffectContainer`) |
| Контроль версий | git не инициализирован |

## 1. Экраны и навигация

**Точка входа:** `MyApp/MyApp.swift` создаёт `@State AppStore` и передаёт его через `.environment(store)` в `RootView`.

**`RootView`** (`Screens/MainTabView.swift`) переключает три состояния по флагам `store.hasCompletedOnboarding` и `store.isLocked`:
1. `OnboardingFlow`;
2. `PrivacyLockView`;
3. `MainTabView`.

При уходе приложения в фон (`scenePhase == .background`) снова ставится блокировка. Цветовая схема принудительно светлая (`.preferredColorScheme(.light)`).

**`MainTabView`** — `TabView` из 5 вкладок (`Tab`). В каждой вкладке своя `NavigationStack`.

| Вкладка | Файл | Показывает | Что реально работает |
|---|---|---|---|
| Today | `Screens/TodayView.swift` | Приветствие, переключатель Calm/Flare, чек-ин (зуд, теги, в режиме Flare — зоны, жжение, сон, заметка), «calm days», прогноз погоды, напоминания о лечении, график зуда за 14 дней | Слайдер, теги, добавление тега, галочки напоминаний. «Save check-in» только показывает надпись «Saved» |
| Body | `Screens/BodyMapView.swift` | Силуэт спереди/сзади, быстрые зоны (scalp, nails, palms, soles), оценка площади в % и сравнение с прошлой неделей | Тап по зоне меняет интенсивность 0→3, % пересчитывается. «Прошлая неделя» захардкожена |
| Photos | `Screens/PhotosView.swift` | Сетка фото-зон, кнопка камеры | Навигация. Камера — заглушка |
| Treatment | `Screens/TreatmentView.swift` | Кремы (FTU), таблетки, биологики (календарь на 14 дней), ротация мест инъекций | Только отображение моков. Кнопка «+» пустая |
| Insights | `Screens/InsightsView.swift` | Ссылка на отчёт, инсайты с «уверенностью», эксперимент, недельный балл | Только отображение моков |

**Вложенные экраны:**
- `ZoneProgressView` (`Screens/ZoneProgressView.swift`) открывается из Photos через NavigationLink. Содержит шторку before/after, ленту фото, таймлайн лечения и кнопку «Build timelapse». Кнопка timelapse только переключает флаг.
- `CameraOverlayView` (`Screens/PhotosView.swift`) открывается как fullScreenCover из Photos и ZoneProgress. Вместо видоискателя — градиент, контур-«призрак» `GhostOutline` и слайдер прозрачности. Фото не снимается и не сохраняется.
- `DoctorReportView` (`Screens/DoctorReportView.swift`) открывается из Insights. Это «лист бумаги» со статистикой, графиком, фото, таймлайном лечения и триггерами. Есть выбор периода и `ShareLink` с текстом.
- `PrivacyLockView` (`Screens/PrivacyLockView.swift`): кнопка «Unlock with Face ID» просто ставит `isLocked = false`.
- `DesignCanvasView` (`Canvas/DesignCanvasView.swift`): все экраны на одном холсте. Есть только в DEBUG, открывается долгим нажатием на приветствие в Today.

**Онбординг** (`Onboarding/OnboardingFlow.swift`): enum `OnboardingStep` из 13 шагов, переходы через `switch` и анимацию. Общий каркас страницы — `OnboardingPage`; общие элементы — `ChoiceCard` и `PermissionButtons`.

| Шаги | Файл | Содержание |
|---|---|---|
| O1–O6 | `Onboarding/OnboardingStepsIntro.swift` | Welcome, Condition, Who for, Skin now (слайдер 0–1), Goals, Delay insight |
| O7–O12 | `Onboarding/OnboardingStepsSetup.swift` | Карта тела, лечение (13 препаратов в каталоге), уведомления, геолокация, сон (HealthKit), приватность, «план готов» |

Разрешения на уведомления, геолокацию и HealthKit **не запрашиваются**: шаги только ставят флаги в `AppStore`. Кнопка «Save a backup to iCloud» пустая.

## 2. Модели данных и хранение

### Хранение
**Хранения нет совсем.** Ни SwiftData, ни Core Data, ни UserDefaults/`@AppStorage`, ни файлов, ни Keychain. Всё состояние живёт в `@Observable final class AppStore` (`Model/AppStore.swift`) и пропадает при каждом перезапуске. Онбординг показывается каждый раз.

### Типы (`Model/Models.swift`)

| Тип | Вид | Замечания |
|---|---|---|
| `Condition` | enum: psoriasis, eczema, seborrheic, other | Псориаз — лишь один из вариантов |
| `ProfileKind` | enum: myself, child | — |
| `Goal` | enum: 5 целей | — |
| `AppMode` | enum: calm, flare | — |
| `BodySide` | enum: front, back | — |
| `BodyZone` | struct, статическая геометрия | id вида `front.elbow.left`, `rect` в пространстве 200×440, `area` — % поверхности тела. 26 зон на каждую сторону + 4 `quickZones`. Хорошая основа |
| `DayValue` | struct (date, value) | Для графиков |
| `TreatmentKind` | enum: cream, ointment, pill, biologic, phototherapy | — |
| `Treatment` | struct | `id = UUID()` в init; `zones: [String]` — **отображаемые имена** («Elbows»), а не id зон; `frequency: String` вместо расписания; `nextDoseInDays: Int?` |
| `TreatmentReminder` | struct | Не связан с `Treatment` |
| `InjectionSite` | enum: 4 места | — |
| `Insight`, `Experiment` | struct | Чисто демонстрационные |
| `PhotoEntry` | struct (date, seed, calmness) | **Нет ссылки на изображение**, `seed` нужен только для заглушки |
| `PhotoZone`, `TreatmentMarker` | struct | Маркеры лечения дублируют `Treatment` строками |

### Поля `AppStore`
- **Флаги потока:** `hasCompletedOnboarding`, `isLocked`.
- **Ответы онбординга:** `condition`, `profile`, `skinNow`, `goals`, `currentTreatments: Set<String>`.
- **Настройки:** `notifyTreatment`, `notifyCheckIn`, `notifyForecast`, `checkInTime`, `locationAllowed`, `healthAllowed`, `faceIDEnabled`.
- **Today:** `todayItch` (одно число, **без даты и истории**), `selectedTags`, `tags`, `reminders`.
- **Карта тела:** `zoneIntensity: [String: Int]` (0–3, без даты), `lastWeekArea = 5.1` (константа).
- **Моки:**
  - `itchHistory`, `weeklyScores`, `sleepHistory`;
  - `treatments` (такролимус и адалимумаб — набор для экземы);
  - `insights`, `experiment`, `photoZones`;
  - `calmDaysThisMonth` всегда возвращает `12`.
- **Логика:** `affectedArea` (сумма `area × coverage`, где coverage для уровней 1/2/3 = 0.25/0.5/0.8), `suggestedInjectionSite`, `cycleIntensity`, `toggleTag`, `completeOnboarding`, `static var preview`.

## 3. Архитектура и слои

| Слой | Что есть |
|---|---|
| UI | SwiftUI views в `Screens/` и `Onboarding/` |
| Дизайн-система | `DesignSystem/Theme.swift` (палитра, шрифты, `WarmBackground`, `previewSetup`), `Components.swift` (`GlassCard`, `SectionHeader`, `TagChip`, `FlowLayout`, кнопки, заглушки-иллюстрации), `SharedViews.swift` (`BodySilhouette`, `IntensityLegend`, графики, `SkinForecastCard`, `FingerIllustration`) |
| Состояние | Один «божественный» `AppStore`: поток, онбординг, настройки, данные дня, моки и производные значения вместе |
| Domain / логика | Отсутствует как слой. Расчёты разбросаны по `AppStore` и view (фильтры в `TreatmentView`, текст отчёта в `DoctorReportView.summaryText`) |
| Persistence / сервисы | Отсутствуют: нет репозиториев, нет сервисов уведомлений, камеры, Health, погоды, аутентификации |
| DI | Только SwiftUI Environment |
| Тесты | Нет |

## 4. Реализовано / заглушки / моки

**Работает (только в памяти):**
- проход онбординга, выбор диагноза, профиля и целей, слайдер «кожа сейчас»;
- карта тела с пересчётом площади;
- чек-ин: слайдер, теги, добавление тега, переключатель Calm/Flare;
- галочки напоминаний;
- шторка before/after и выбор фото в ZoneProgress;
- выбор периода отчёта, ShareLink.

**Заглушки:**
- Face ID (`PrivacyLockView`) — без `LocalAuthentication`;
- камера (`CameraOverlayView`) — нет AVFoundation, нет сохранения, кнопка вспышки пустая;
- фото — `AbstractSkinPlaceholder` вместо изображений;
- «Build timelapse», «Add treatment», «Save a backup to iCloud»;
- системные разрешения (уведомления, геолокация, HealthKit) — только флаги;
- «Save check-in» — только анимация; данные обострения (`flareZones`, `burning`, `sleepQuality`, `note`) живут в `@State` карточки и теряются.

**Моки и хардкод:**
- вся история, инсайты, эксперимент и фото-зоны в `AppStore.init`;
- `SkinForecastCard` с выдуманной влажностью;
- в `DoctorReportView` строки «16 → 8», «5.8 → 3.0», «6% →»;
- `biologicCard` всегда подписывает день дозы «Fri»;
- в `DoctorReportView` по умолчанию «Atopic dermatitis»; `AppStore.preview` использует `.eczema`.

## 5. Качество кода

**Хорошо:**
- Современный SwiftUI: `@Observable`, `@Environment`, `@Bindable`, `Tab`, `containerRelativeFrame`, `sensoryFeedback`, `contentTransition`.
- Единая тема и переиспользуемые компоненты. Визуальный язык стоит сохранить.
- Внимание к доступности: `accessibilityLabel` / `Value` у зон тела, `accessibilityAdjustableAction` у шторки, крупные области нажатия.
- Мысли о производительности: кэш зон (`BodyZone.frontZones`), `drawingGroup` у заглушек, MeshGradient вместо blur, разбиение на мелкие view (`CheckInCard` владеет своим state).
- Нет force unwrap. Debug-канвас закрыт `#if DEBUG`. Превью у каждого экрана.
- Геометрия `BodyZone` с площадями в % BSA — полезная основа для расчёта BSA.

**Плохо / технический долг:**
- Нет хранения и нет тестов.
- `AppStore` смешивает всё. Моки зашиты в `init`, их нельзя отделить от боевого кода.
- Модель заточена под экзему: шкала POEM 0–28 в `WeeklyScoreChart`, `scoreName`, препараты в моках и каталоге, preview.
- Отображаемые имена используются как идентификаторы (`Treatment.zones`, `tags`, `currentTreatments`).
- Нестабильные `UUID()` в `init`. `Treatment` смешивает справочник и план. Расписание задано строкой.
- Бизнес-правил из spec нет: категория тяжести, само-PASI, DLQI, PEST, красные флаги, курс стероидов.
- Все строки захардкожены на английском. String Catalog есть в настройках (`LOCALIZATION_PREFERS_STRING_CATALOGS`), но не используется осознанно.
- Принудительная светлая тема, тёмной нет.
- Мелочи: сбит отступ во вложенном `GlassEffectContainer` в `BodyMapView.quickZones`; `ForEach(quick.indices)` вместо идентифицируемых элементов.
- Swift 5 language mode, строгая проверка concurrency выключена.

## 6. Безопасность данных (фото и здоровье)

Сейчас ничего не сохраняется, поэтому утечь нечему. Но:

1. **Интерфейс обещает то, чего нет.** Тексты «Protected by Face ID», «Stored only on this device», «Never appear in your shared photo library», «Nothing leaves your phone» (`PrivacyLockView`, `PhotosView`, `PrivacyStep`, `WelcomeStep`) не подкреплены кодом.
2. **Блокировка обходится одним тапом** — `LocalAuthentication` нет.
3. **Нет экрана приватности при переходе в неактивное состояние.** Блокировка ставится только на `.background`, поэтому снимок в переключателе приложений покажет данные.
4. **Нет usage descriptions** (`NSFaceIDUsageDescription`, `NSCameraUsageDescription`, `NSHealthShareUsageDescription`, `NSLocationWhenInUseUsageDescription`). Первый же реальный вызов этих API уронит приложение.
5. **Отчёт уходит открытым текстом** через `ShareLink`, без предупреждения о том, что это медицинские данные.
6. **Не определены:**
   - класс Data Protection для файлов;
   - исключение фото из бэкапа и фотоплёнки;
   - шифрование;
   - нейтральные тексты уведомлений;
   - экспорт и удаление всех данных.

**Что потребуется при реализации:**
- SwiftData с защитой файлов `.complete`;
- фото в контейнере приложения (не в Photos);
- `LAContext` с откатом на код-пароль;
- размытие при `.inactive`;
- usage descriptions;
- предупреждение перед отправкой отчёта;
- «Удалить все данные».
