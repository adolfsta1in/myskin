import StoreKit
import SwiftData
import SwiftUI
import UIKit

/// Profile, reminders, lock and the disclaimer. Opened from the gear on Today.
struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]
    @State private var isNotificationsDenied = false
    @State private var isAskingPermission = false
    /// Covers the form while «Delete all data» runs, so half-deleted screens never flash.
    @State private var isDeleting = false

    var body: some View {
        NavigationStack {
            Form {
                aboutYouSection
                profileSection
                remindersSection
                LanguageSection()
                Section {
                    LockToggle()
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("When on, MySkin locks each time you leave the app and hides its content in the app switcher.")
                }
                SubscriptionSection()
                DataSection(isDeleting: $isDeleting)
                #if DEBUG
                DeveloperSection()
                #endif
                aboutSection
            }
            .font(.rounded(.body))
            .scrollContentBackground(.hidden)
            .background(WarmBackground())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay {
                if isDeleting {
                    ZStack {
                        WarmBackground()
                        ProgressView("Deleting your data…")
                            .font(.rounded(.body))
                            .tint(Theme.accent)
                    }
                    .transition(.opacity)
                }
            }
            .alert("Notifications are off", isPresented: $isNotificationsDenied) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Allow notifications for MySkin in the Settings app to get reminders.")
            }
        }
        .tint(Theme.accent)
    }

    // MARK: Profile

    private var profile: Profile? { profiles.first }

    private var aboutYouSection: some View {
        Section("About you") {
            TextField("First name", text: Binding(
                get: { profile?.name ?? "" },
                // Trimmed only when shown, so typing a space between names isn't undone.
                set: { name in updateProfile { $0.name = String(name.prefix(ProfileInfo.maxNameLength)) } }
            ))
            .textContentType(.givenName)
            Picker("Sex", selection: Binding(
                get: { profile?.sex },
                set: { sex in updateProfile { $0.sex = sex } }
            )) {
                Text("Not set").tag(Sex?.none)
                ForEach(Sex.allCases) { sex in
                    Text(sex.title).tag(Optional(sex))
                }
            }
            Picker("Age", selection: Binding(
                get: { profile?.birthYear.map { ProfileInfo.age(birthYear: $0) } },
                set: { age in updateProfile { $0.birthYear = age.map { ProfileInfo.birthYear(age: $0) } } }
            )) {
                Text("Not set").tag(Int?.none)
                ForEach(ProfileInfo.ages, id: \.self) { age in
                    Text(String(age)).tag(Optional(age))
                }
            }
        }
    }

    private var profileSection: some View {
        Section("Your psoriasis") {
            NavigationLink {
                PsoriasisTypesPicker(selected: profile?.psoriasisTypes ?? []) { types in
                    updateProfile { $0.psoriasisTypes = types }
                }
            } label: {
                LabeledContent("Forms", value: typesSummary)
            }
            Picker("Year it started", selection: Binding(
                get: { profile?.onsetYear },
                set: { year in updateProfile { $0.onsetYear = year } }
            )) {
                Text("Not sure").tag(Int?.none)
                ForEach(OnboardingDraft.onsetYears(), id: \.self) { year in
                    Text(String(year)).tag(Optional(year))
                }
            }
            Picker("Psoriatic arthritis", selection: Binding(
                get: { profile?.arthritisStatus },
                set: { status in updateProfile { $0.arthritisStatus = status } }
            )) {
                Text("Not set").tag(ArthritisStatus?.none)
                ForEach(ArthritisStatus.allCases) { status in
                    Text(status.title).tag(Optional(status))
                }
            }
        }
    }

    private var typesSummary: String {
        let types = profile?.psoriasisTypes ?? []
        return types.isEmpty ? String(localized: "Not set") : PsoriasisType.allCases.filter(types.contains).map(\.title).joined(separator: String(localized: ", "))
    }

    /// Edits the profile, creating it if onboarding left none.
    private func updateProfile(_ change: (Profile) -> Void) {
        let target = profile ?? {
            let new = Profile()
            modelContext.insert(new)
            return new
        }()
        change(target)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
        }
    }

    // MARK: Reminders

    private var remindersSection: some View {
        @Bindable var settings = settings
        return Section {
            Toggle("Daily check-in", isOn: Binding(get: { settings.checkInReminder }, set: { setReminder(\.checkInReminder, $0) }))
            if settings.checkInReminder {
                DatePicker("Time", selection: $settings.checkInTime, displayedComponents: .hourAndMinute)
            }
            Toggle("Treatment doses", isOn: Binding(get: { settings.doseReminders }, set: { setReminder(\.doseReminders, $0) }))
        } header: {
            Text("Reminders")
        } footer: {
            Text("Reminders never mention your condition or medicines.")
        }
        .disabled(isAskingPermission)
    }

    /// Turning a reminder on asks iOS for permission first; if it's refused, the switch stays off.
    private func setReminder(_ key: ReferenceWritableKeyPath<AppSettings, Bool>, _ isOn: Bool) {
        guard isOn else {
            settings[keyPath: key] = false
            return
        }
        isAskingPermission = true
        Task {
            if await NotificationPermission.request() {
                settings[keyPath: key] = true
            } else {
                isNotificationsDenied = true
            }
            isAskingPermission = false
        }
    }

    // MARK: About

    private var aboutSection: some View {
        Section("About") {
            VStack(alignment: .leading, spacing: 8) {
                Label("MySkin is a diary, not a medical device.", systemImage: "book.closed")
                    .font(.rounded(.subheadline, weight: .semibold))
                Text("It does not diagnose, and it does not prescribe or change treatment. Discuss your results with your doctor. If you feel very unwell, contact your doctor or emergency services.")
                    .font(.rounded(.footnote))
                    .foregroundStyle(Theme.inkSoft)
            }
            .padding(.vertical, 4)
            Text("The skin impact and joint check questionnaires were written for MySkin. They are not validated clinical scores.")
                .font(.rounded(.footnote))
                .foregroundStyle(Theme.inkSoft)
            Text("Safety information is based on the American Academy of Dermatology psoriasis guidelines and NICE guideline CG153 (Psoriasis: assessment and management). Medication schedules are typical examples — use what your doctor prescribed.")
                .font(.rounded(.footnote))
                .foregroundStyle(Theme.inkSoft)
            aboutLink(String(localized: "Privacy Policy"), systemImage: "hand.raised", AppLinks.privacy)
            aboutLink(String(localized: "Terms & Medical Disclaimer"), systemImage: "doc.text", AppLinks.terms)
            aboutLink(String(localized: "Help & FAQ"), systemImage: "questionmark.circle", AppLinks.support)
            aboutLink(String(localized: "Contact support"), systemImage: "envelope", AppLinks.contactSupport)
            if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                LabeledContent("Version", value: version)
            }
        }
    }

    @ViewBuilder
    private func aboutLink(_ title: String, systemImage: String, _ url: URL?) -> some View {
        if let url {
            Link(destination: url) {
                Label(title, systemImage: systemImage)
                    .font(.rounded(.body))
            }
            .tint(Theme.accent)
        }
    }
}

/// The app's own language. iOS applies it at the next launch, so the user is asked to reopen MySkin.
private struct LanguageSection: View {
    @State private var chosen = AppLanguage.chosen()
    @State private var isAskingToReopen = false

    var body: some View {
        Section {
            Picker("Language", selection: $chosen) {
                ForEach(AppLanguage.allCases) { language in
                    Text(verbatim: language.nativeName).tag(language)
                }
            }
            .onChange(of: chosen) { _, language in
                AppLanguage.choose(language)
                isAskingToReopen = true
            }
        } header: {
            Text("Language")
        } footer: {
            Text("A new language shows after you close MySkin and open it again.")
        }
        .alert("Reopen MySkin", isPresented: $isAskingToReopen) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The new language shows after you close MySkin in the app switcher and open it again.")
        }
    }
}

/// Plan and renewal date, with Apple's own sheets to change or cancel, redeem a code, or restore.
private struct SubscriptionSection: View {
    /// nil in previews.
    @Environment(Subscriptions.self) private var subscriptions: Subscriptions?
    @State private var isManaging = false
    @State private var isRedeeming = false
    @State private var isRestoring = false
    @State private var restoreMessage: String?

    var body: some View {
        if let subscriptions {
            Section {
                if let current = subscriptions.current {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("MySkin Premium · \(current.title)")
                            .foregroundStyle(Theme.ink)
                        if let detail = current.detail {
                            Text(detail)
                                .font(.rounded(.footnote))
                                .foregroundStyle(current.hasBillingIssue ? Theme.flare : Theme.inkSoft)
                        }
                    }
                }
                Button("Manage subscription", systemImage: "creditcard") { isManaging = true }
                Button("Redeem a code", systemImage: "giftcard") { isRedeeming = true }
                Button("Restore purchases", systemImage: "arrow.clockwise") { restore(subscriptions) }
                    .disabled(isRestoring)
                #if DEBUG
                Button("Show paywall (debug build)", systemImage: "rectangle.on.rectangle") {
                    subscriptions.showPaywallForDebug()
                }
                .foregroundStyle(Theme.flare)
                #endif
            } header: {
                Text("Subscription")
            } footer: {
                Text("Change plan or cancel in your Apple Account. Cancel at least a day before renewal to avoid being charged.")
            }
            .manageSubscriptionsSheet(isPresented: $isManaging)
            .offerCodeRedemption(isPresented: $isRedeeming) { _ in
                Task { await subscriptions.refreshEntitlements() }
            }
            .alert("Restore purchases", isPresented: Binding(get: { restoreMessage != nil }, set: { if !$0 { restoreMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(restoreMessage ?? "")
            }
        }
    }

    private func restore(_ subscriptions: Subscriptions) {
        isRestoring = true
        Task {
            defer { isRestoring = false }
            do {
                try await subscriptions.restore()
                restoreMessage = subscriptions.isSubscribed ? String(localized: "Your subscription is active.") : String(localized: "No subscription found for this Apple Account.")
            } catch {
                restoreMessage = error.localizedDescription
            }
        }
    }
}

/// CSV export and «Delete all data» (two confirmations).
private struct DataSection: View {
    @Environment(AppSettings.self) private var settings
    @Environment(AppLock.self) private var lock
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Binding var isDeleting: Bool
    @State private var isExporting = false
    @State private var isConfirmingDelete = false
    @State private var isConfirmingDeleteAgain = false
    @State private var deleteError: String?

    var body: some View {
        Section {
            Button("Export diary as CSV", systemImage: "tablecells") { isExporting = true }
            Button("Delete all data", systemImage: "trash", role: .destructive) { isConfirmingDelete = true }
        } header: {
            Text("Your data")
        } footer: {
            Text("The export contains check-ins, body map assessments, treatments, doses and questionnaires. Photos aren't included.")
        }
        .healthDataShare(isPresented: $isExporting) {
            try DataExport.writeCSV(from: modelContext)
        }
        .confirmationDialog("Delete all data?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete all data", role: .destructive) { isConfirmingDeleteAgain = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Check-ins, body maps, photos, treatments and questionnaires will be removed from this iPhone.")
        }
        .alert("This can't be undone", isPresented: $isConfirmingDeleteAgain) {
            Button("Delete everything", role: .destructive, action: deleteAll)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Export your diary first if you might need it later.")
        }
        .alert("Couldn't delete", isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteError ?? "")
        }
    }

    private func deleteAll() {
        withAnimation(.smooth(duration: 0.2)) { isDeleting = true }
        Task {
            // Let the cover appear before the screens underneath empty out.
            try? await Task.sleep(for: .milliseconds(250))
            do {
                try DataReset.deleteAll(context: modelContext, photoStore: PhotoStore.shared, settings: settings)
                lock.isLocked = false
                await NotificationService.removeAll()
                dismiss()
            } catch {
                modelContext.rollback()
                isDeleting = false
                deleteError = error.localizedDescription
            }
        }
    }
}

#if DEBUG
/// Development only: walk through the onboarding again. Diary data is kept.
private struct DeveloperSection: View {
    @Environment(AppSettings.self) private var settings
    @Environment(AppLock.self) private var lock
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Section {
            Button("Show onboarding", systemImage: "arrow.counterclockwise") {
                dismiss()
                lock.isLocked = false
                settings.hasCompletedOnboarding = false
            }
        } header: {
            Text("Developer")
        } footer: {
            Text("Debug builds only. Your diary is kept; treatments added in onboarding are added again.")
        }
    }
}
#endif

/// Multi-select list of psoriasis forms.
private struct PsoriasisTypesPicker: View {
    @State var selected: [PsoriasisType]
    let onChange: ([PsoriasisType]) -> Void

    var body: some View {
        List {
            ForEach(PsoriasisType.allCases) { type in
                Button {
                    if let index = selected.firstIndex(of: type) { selected.remove(at: index) } else { selected.append(type) }
                    onChange(PsoriasisType.allCases.filter(selected.contains))
                } label: {
                    HStack {
                        Label(type.title, systemImage: type.systemImage)
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        if selected.contains(type) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Theme.accent)
                        }
                    }
                }
                .accessibilityAddTraits(selected.contains(type) ? .isSelected : [])
            }
        }
        .font(.rounded(.body))
        .scrollContentBackground(.hidden)
        .background(WarmBackground())
        .navigationTitle("Forms")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView()
        .previewSetup()
}
