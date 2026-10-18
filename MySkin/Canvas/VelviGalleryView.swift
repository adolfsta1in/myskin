#if DEBUG
import SwiftUI

/// Debug-only playground for the mascot: every mood, prop and reaction, at any size.
/// Opened from Settings › Developer to judge Velvi on a real device.
struct VelviGalleryView: View {
    @State private var mood: VelviMood = .happy
    @State private var prop: VelviProp?
    @State private var motion: VelviMotion = .hop
    @State private var trigger = 0
    @State private var size: CGFloat = 220
    @State private var isIdle = true
    @State private var showsBubble = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                stage
                controls
                grid
            }
            .padding(Theme.screenPadding)
        }
        .screenScaffold()
        .navigationTitle(Text(verbatim: "Velvi"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var stage: some View {
        HStack(alignment: .bottom, spacing: 4) {
            VelviMascot(mood: mood, prop: prop, size: size, motion: motion, trigger: trigger, isIdle: isIdle)
                .onTapGesture { trigger += 1 }
            if showsBubble {
                VelviBubble("Logged. See you tomorrow." as String)
                    .transition(.scale(scale: 0.6, anchor: .bottomLeading).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 280)
        .animation(.spring(duration: 0.4, bounce: 0.3), value: showsBubble)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            chips(VelviMood.allCases, selected: mood) { mood = $0 }
            chips(VelviProp.allCases, selected: prop) { prop = prop == $0 ? nil : $0 }
            HStack {
                ForEach(VelviMotion.allCases) { item in
                    Button {
                        motion = item
                        trigger += 1
                    } label: {
                        Text(verbatim: item.rawValue)
                    }
                    .buttonStyle(.glass)
                }
            }
            Slider(value: $size, in: 44...300)
            Toggle(isOn: $isIdle) { Text(verbatim: "Idle animation") }
            Toggle(isOn: $showsBubble) { Text(verbatim: "Speech bubble") }
        }
        .font(.rounded(.subheadline))
        .glassCard()
    }

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96))], spacing: 12) {
            ForEach(VelviMood.allCases) { item in
                VStack(spacing: 2) {
                    VelviMascot(mood: item, size: 88, isIdle: false)
                    Text(verbatim: item.rawValue)
                        .font(.rounded(.caption))
                        .foregroundStyle(Theme.inkSoft)
                }
                .onTapGesture { mood = item }
            }
        }
        .glassCard()
    }

    private func chips<Item: Identifiable & RawRepresentable<String>>(
        _ items: [Item], selected: Item?, onTap: @escaping (Item) -> Void
    ) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(items) { item in
                Button {
                    onTap(item)
                } label: {
                    Text(verbatim: item.rawValue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .foregroundStyle(selected?.id == item.id ? .white : Theme.ink)
                        .background(Capsule().fill(selected?.id == item.id ? Theme.accent : Theme.sand))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    NavigationStack { VelviGalleryView() }
        .previewSetup()
}
#endif
