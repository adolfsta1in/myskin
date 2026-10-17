# MySkin — App Store launch plan
_Research date: 2026-10-14. Not legal advice. Items marked [verify] could not be confirmed from primary sources._

**Decisions taken:**
- Distribution: worldwide.
- v1.0 is local-only, with no accounts. Supabase sync comes in v1.1.
- Monetization: freemium subscription.
- Developer: individual account, registered sole proprietor (IP) in Kyrgyzstan, already enrolled in the Apple Developer Program.
- DLQI and PEST are replaced with our own questionnaires (C5).
- Weather comes from Apple WeatherKit instead of Open-Meteo (C13).

## 0. Top risks (read first)
| # | Risk | Status / action |
|---|---|---|
| 1 | Payouts / Paid Applications Agreement | **Resolved.** Enrolled from Kyrgyzstan as a registered IP. When the subscription is added, sign the Paid Applications Agreement, fill in W-8BEN and add the bank in App Store Connect. |
| 2 | DLQI and PEST licences | **Replace with our own questionnaires.** DLQI (Cardiff University) and PEST (University of Leeds) need paid licences for commercial apps. We use original wording and no DLQI/PEST names (C5). |
| 3 | Medical-device boundary (EU MDR Rule 11, FDA) | A diary is fine. Careful wording, a clear intended purpose and no diagnoses keep it that way (C6). |
| 4 | Open-Meteo terms | **Switch to WeatherKit.** The free Open-Meteo API is non-commercial only, and its terms count subscription apps as commercial. WeatherKit is included in the Developer Program (500k calls/month) (C13). |
| 5 | Beta Xcode | Builds made with a beta Xcode/SDK are rejected in App Review; they work in TestFlight only. Archive with the release Xcode 27.0 or 27.1 RC. |
| 6 | Health data in iCloud (guideline 5.1.3(ii)) | Not applicable: no iCloud sync is planned. |

## Phase A — Start now
- **A1. Payouts.** Already enrolled as a Kyrgyzstan IP. When adding the subscription:
  - sign the Paid Applications Agreement;
  - fill in W-8BEN;
  - add the bank account;
  - join the Small Business Program (15% commission).

  Check with a Kyrgyz accountant how foreign income is taxed under your IP regime.
- **A2. Name check.** No trademark registration is needed to publish.
  - App Store names must be unique. You'll see whether "MySkin" is free when you create the app record (D1).
  - Similar apps already exist: "My Skin" (Krushcode) and "MySkin+".
  - The live "MY SKIN" trademark covers cosmetics (class 3), so the risk for a software diary is low.
  - Recommended store name: **"MySkin: Psoriasis Diary"**.
  - A quick search in TMview, the WIPO Global Brand Database and USPTO (classes 9, 42, 44) is enough.
  - Register your own mark later if the app grows.
- **A3. Domain and email.** Buy a domain (about $10–15 a year) and set up support@your-domain.

## Phase B — Code for v1.0
One step = one commit, as in CLAUDE.md. Blockers come first.

- **C1. Remove `docs/` from the app target.**
  - The synchronized group in `MySkin.xcodeproj/project.pbxproj:101-104` is a member of the app target.
  - As a result, the spec, migration plan, research notes and AI prompts are copied into `MySkin.app`.
- **C2. Commit the app icon.**
  - Commit `Assets.xcassets/AppIcon.appiconset` and the `ASSETCATALOG_COMPILER_APPICON_NAME` setting.
  - Re-export the 1024 PNG full-bleed: no baked-in rounded corners, no alpha.
  - Optional: an Icon Composer `.icon` with dark and tinted variants.
- **C3. Build the first Release archive.** The Release configuration has never been built.
  - If the build fails, wrap in `#if DEBUG` the `#Preview` blocks that use `PreviewData` outside it: `InsightsView.swift:162`, `TreatmentView.swift:315`, `TodayView.swift:1224/1230`, `OnboardingFlow.swift:292`.
  - Also guard the long press on the greeting (`TodayView.swift:211`).
- **C4. Add legal links in the app.**
  - In Settings › About (`SettingsView.swift:189-206`): Privacy Policy, Terms & Medical Disclaimer, and Contact support (mailto).
  - A Privacy link in the onboarding Privacy step.
  - Keep the URLs in one constant, for example `App/AppLinks.swift`.
- **C5. Our own questionnaires instead of DLQI and PEST.**
  - Use original questions with our own wording, number of items and answer scale. No DLQI/PEST names and no claims of being "validated".
  - **Skin impact** (replaces DLQI):
    - Asks how psoriasis affected the past week: sleep, mood, work or study, social life, clothing choices, treatment burden.
    - Each item on a 0–3 scale.
    - The total is shown as a number with plain-language bands and no medical meaning.
  - **Joint check** (replaces PEST):
    - Our own questions, for example: joint pain, swelling, morning stiffness over 30 minutes, heel or finger pain, back pain at night.
    - Our own scoring and threshold → "Discuss your joints with your doctor or a rheumatologist".
    - Wording: "a reason to talk to your doctor", never "you may have arthritis".
    - It still sets `arthritisSuspected`, but is described as "joint symptoms reported".
  - **Data:** add new `QuestionnaireKind` cases with new rawValues. Keep the old `dlqi` and `pest` rawValues in the enum so stored results still decode (stored rawValues are never renamed).
  - **Code to update:**
    - the `SeverityCalculator` "rule of tens" (uses DLQI > 10 and PEST ≥ 3);
    - `QuestionnaireSchedule`;
    - the BodyMap "Elevated" card;
    - `DoctorReport`;
    - the CSV export;
    - the Settings attribution line;
    - the tests.
- **C6. Medical wording pass** (MDR and guideline 1.4.1):
  - BSA and severity are "your estimate", not a measurement.
  - The Flare banner is descriptive ("your entries show…") and always ends with "discuss with your doctor".
  - The joint check result says "bring this to your doctor or a rheumatologist", with no diagnosis.
  - Red flags stay (a project rule), but they're phrased as safety information ("If you have fever with pustules… seek care now"), not as a diagnosis. Cite the sources (AAD, NICE CG153) in About.
  - The medication catalog says "typical schedule — use what your doctor prescribed". Ask a doctor or pharmacist to review all 39 entries.
- **C7. Make backup behaviour consistent.**
  - The SwiftData store goes into iCloud and computer backups, but photos are excluded. After a restore, photo records point to missing files.
  - Fix: either exclude the store from backup, or handle missing photo files gracefully.
  - Align the onboarding text "stays on this phone" (`OnboardingStepsIntro.swift:42`, `OnboardingStepsSetup.swift:339`).
- **C8. No crash on store failure.** Replace the `fatalError` at `MyApp.swift:19` with a recovery screen (export, reset, contact support).
- **C9. Privacy manifest and weather.**
  - Approximate coordinates go to Apple, for WeatherKit and for reverse geocoding.
  - If App Store Connect treats this as collection, declare "Coarse Location — App Functionality — not linked — no tracking" in `PrivacyInfo.xcprivacy` and in App Store Connect.
  - Keep `UserDefaults CA92.1`.
  - Before uploading, check that the Xcode privacy report shows no other required-reason APIs.
- **C10. Device checks** on the iPhone: camera capture, Face ID with passcode fallback, "Call 112/911", "Find emergency care", notifications, PDF/CSV share.
- **C11. Accessibility pass.** Test the largest Dynamic Type sizes, and VoiceOver on the body map and the paywall. The app forces light mode, which is fine as long as it's deliberate.
- **C12. Clean-up (optional).**
  - Remove the leftover template settings `ENABLE_APP_SANDBOX`, `ENABLE_USER_SELECTED_FILES` and `REGISTER_APP_GROUPS`.
  - Rename the scheme `MyApp` → `MySkin`.
  - Update the paths in CLAUDE.md.
- **C13. WeatherKit instead of Open-Meteo.**
  - Enable the WeatherKit capability for the App ID in the developer portal, plus the entitlement.
  - Replace the network call in `WeatherService`/`WeatherInfo` with `WeatherService.shared.weather(for:)`.
  - Show the required Apple Weather attribution: the logo and the legal link from `WeatherService.attribution`.
  - Update the texts that say location goes to Open-Meteo (`TodayView.swift:777`, `OnboardingStepsSetup.swift:341`) and the privacy policy.

- **C14. Remote config (an "over-the-air" content update, not a code update).**
  - **What's not allowed:** a native Swift app can't download and run new code.
    - Guideline 2.5.2 forbids apps that "download, install, or execute code which introduces or changes features or functionality".
    - Hiding features from review is a 2.3.1 violation and can lead to removal and account termination.
    - Expo/CodePush-style OTA works only for JavaScript apps (React Native), within the same limits. It doesn't apply to SwiftUI.
    - **New screens, logic or bug fixes in Swift still go through App Review.** Reviews usually take 1–2 days. For urgent fixes, request an expedited review.
  - **What's allowed (and what we build):** a static JSON file on our own site (Cloudflare Pages, Phase C), fetched at launch and cached on the device. It never sends user data.
    - `minimumVersion` → a "Please update MySkin" screen with a link to the App Store, for critical bugs.
    - Feature flags that **switch off** already-reviewed features (a kill switch, e.g. if WeatherKit breaks). Never use them to switch on hidden features.
    - An optional banner/announcement (title, text, link, show-until date).
    - Content data: medication catalog additions, trigger/food lists, help/FAQ texts. Stable ids (rule from CLAUDE.md) stay unchanged; the built-in versions are the fallback when offline.
  - **Rules:**
    - The app works fully offline with the built-in defaults.
    - Medical texts (red flags, questionnaires, disclaimers) stay in the app binary and change only through review.
    - Validate the JSON (a schema version field), keep strict HTTPS, add no tracking parameters, and cache the last good config.
  - **Code:**
    - `Services/RemoteConfig.swift`: fetch with `URLSession` and `async/await`, decode, cache in Application Support.
    - Pure logic for merging and version comparison in `Logic/`, with tests.
    - Reading the config goes through `@Environment`.
  - **Privacy:**
    - This is a new network request. Update the privacy policy ("the app downloads settings from our website; no personal data is sent") and the CLAUDE.md rule "no other network requests".
    - The server sees the device's IP address. With Cloudflare Pages and no logging on our side, the App Privacy label stays "Data Not Collected" [verify].

## Phase C — Website (landing and legal pages)
Host it on Cloudflare Pages (free, commercial use allowed) on your own domain. Pages:

- **Landing page:** what the app is (a diary, not a medical device), the App Store link, screenshots.
- **Privacy Policy** (v1.0 version). It should cover:
  - who you are and how to contact you;
  - that all diary data and photos stay on the device;
  - that there are no accounts, analytics, ads or tracking;
  - weather: approximate location goes to Apple (WeatherKit) and isn't stored;
  - that Apple handles purchases;
  - that export and sharing happen only when the user chooses;
  - that deleting the app, or "Delete all data", erases everything;
  - children's age policy;
  - user rights;
  - how changes are announced (before sync launches).

  A free generator is fine for v1.0. For v1.1, have a lawyer review it once.
- **Terms of Use & Medical Disclaimer.** It should say:
  - the app is not a medical device and doesn't diagnose or treat;
  - in an emergency, call the local emergency number;
  - BSA is an estimate;
  - how subscription auto-renewal and cancellation through Apple work;
  - limitation of liability;
  - that Apple's standard EULA applies.
- **Support:** email and an FAQ (data stays on the device, how to export, how to delete). Add the DSA trader address and phone if you're a trader.
- **Consumer Health Data Privacy Policy** (Washington MHMDA, Nevada): a separate standalone page. Cheap insurance now, and mandatory for v1.1.

## US checklist (v1.0, local-only)
- **FDA:** stay a "general wellness / symptom tracker". Don't use the words diagnose, detect, predict or screen in the app, on the store page or on the site (C6).
- **Privacy policy:** says clearly that nothing is collected and health data never leaves the device.
- **Washington MHMDA and Nevada:** publish the short standalone "Consumer Health Data Privacy Policy" page and link it from the site's home page (Phase C).
- **FTC Health Breach Notification Rule:** there's no health data on a server, so nothing to report. It becomes relevant with Supabase (Phase H).
- **CCPA:** doesn't apply; the app is below the thresholds.
- **COPPA and children:** the app isn't aimed at children, and the age rating is 16+ (D4).
- **Subscriptions** (when added): follow California and other state auto-renewal laws. The paywall shows the price, the period, the renewal terms and "cancel in Settings › Apple ID". Apple handles cancellation and refunds.
- **No analytics or ad SDKs.** This keeps "Data Not Collected" true.

## Phase D — App Store Connect setup
- **D1. App record:**
  - bundle ID `app.myskin.ios`;
  - name up to 30 characters, subtitle up to 30, keywords up to 100 bytes;
  - category Medical or Health & Fitness, consistent with the "diary" positioning.
- **D2. URLs:** Privacy Policy and Support are required; Marketing is optional.
- **D3. App Privacy label:** v1.0 is "Data Not Collected" (or, if C9 applies, only Coarse Location, not linked). It must match the privacy manifest.
- **D4. Age rating.** The new questionnaire has been mandatory since 2026-01-31.
  - "Medical or Treatment Information": answer Frequent (→ 16+), or at least Infrequent (→ 13+). Never under-declare.
  - Social features: No.
- **D5. Export compliance:** `ITSAppUsesNonExemptEncryption = NO` is already set (only system encryption is used). No French declaration is needed.
- **D6. DSA trader status:**
  - The free v1.0 can be "non-trader".
  - Once the subscription ships, you're effectively a trader. Your address (a P.O. box is allowed), phone and email are verified and shown publicly in the EU.
  - The alternative is to exclude the EU.
- **D7. Screenshots:**
  - 6.9" (1320×2868), no alpha, up to 10.
  - **No real lesion photos** (guideline 2.3.8). Use the body map and illustrations.
  - Mark which features need the subscription.
- **D8. Review notes:**
  - it's a self-reported diary, not a diagnostic tool;
  - that the questionnaires are our own, and the sources of the red-flag list;
  - how to reach the red-flag screen (Flare check-in → fever + pustules);
  - that Face ID is optional;
  - where the paywall is (once added).

  Enter the review contact phone in international format (+996…).
- **D9. Availability:** worldwide. The Russian storefront can't buy anything anyway.

## Phase E — TestFlight
- Start with internal testing (up to 100 testers, no review). Then external testing: a Beta App Review on the first build of each version, and a public link.
- Test information: description, feedback email, and "What to Test".
- Builds expire after 90 days. Increase `CURRENT_PROJECT_VERSION` with every upload.

## Phase F — Submit v1.0
- Archive with the release Xcode, upload, attach the build, and submit.
- Use a manual release, so you control launch day, together with a phased release.
- Typical 1.4.1 rejections: no "consult your doctor", diagnosis-like wording, no sources. Answer in the Resolution Center with citations and revised wording.

## Phase G — Monetization (v1.0.x / v1.1)
- Paid Applications Agreement, tax forms and banking.
- StoreKit 2: create the products in App Store Connect and a local `.storekit` configuration. Build the paywall with `SubscriptionStoreView`.
- The paywall must show:
  - the billed price, most prominently;
  - the period;
  - the trial terms;
  - Restore Purchases;
  - links to the Terms (EULA) and the Privacy Policy.

  Add the EULA link to the app description too.
- **What to paywall:** keep logging, red flags and basic history free. Put the advanced features behind the subscription: doctor PDF, long-range trends, the patterns engine, CSV export. This meets guideline 3.1.2 ("ongoing value").
- The first subscription has to be submitted together with an app version, with a paywall screenshot for review.
- DSA: switch to trader (see D6).

## Phase H — v1.1 Supabase (steps 54–57)
- **Sign in:** Sign in with Apple is mandatory alongside Google (guideline 4.8). Local features must not require login (5.1.1(v)).
- **In-app account deletion** (5.1.1(v)), including revoking the Sign in with Apple token (TN3194).
- **Consent:** explicit GDPR Art. 9 consent through an unticked checkbox before the first sync. Users must be able to withdraw it.
- **GDPR and UK GDPR:**
  - EU representative (Art. 27) and UK representative (about €100–500 a year);
  - a written DPIA (data protection impact assessment);
  - accept Supabase's DPA and list its subprocessors;
  - a procedure for reporting a breach within 72 hours.
- **US:** the Washington/Nevada consumer health policy plus separate consent; the FTC Health Breach Notification Rule (notices within 60 days).
- **Russia (152-FZ localization) and Kazakhstan:** either disable sync for these regions or store their data locally.
- **Updates:**
  - App Privacy label: Health, Email, User ID, "Linked to You";
  - `NSPrivacyCollectedDataTypes`;
  - a rewritten privacy policy;
  - a demo account for review;
  - current versions of the GoogleSignIn and supabase-swift SDKs (with their privacy manifests).

## Order of work
1. A1–A3 now.
2. C1–C3.
3. C4–C9, C13 and C14.
4. C10–C11.
5. The website.
6. App Store Connect setup, D1–D9.
7. TestFlight.
8. Submit v1.0 (free).
9. Phase G (subscription).
10. Phase H (v1.1).

## Open uncertainties [verify]
- The US withholding rate for a Kyrgyzstan IP (W-8BEN). Check with an accountant.
- Whether 6.1" screenshots are now mandatory. "iPhone Duo" screenshots are due from April 2027.
- The exact required-reason codes. Check Apple's documentation page.
- Whether location sent to WeatherKit counts as "collected" for the App Store label.
