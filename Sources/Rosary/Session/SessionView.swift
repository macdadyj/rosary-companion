#if os(iOS)
import RosaryCore
import SwiftUI

/// The prayer screen. Everything is one big tap target: a tap anywhere moves to the next prayer.
struct SessionView: View {
    let session: ActiveSession
    let settings: AppSettings
    let library: SaintsLibrary
    let content: PrayerContent?
    let onClose: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var confirmingEnd = false

    private var controller: SessionController { session.controller }
    private var snapshot: SessionSnapshot { controller.snapshot }

    var body: some View {
        // The candle fill ignores the safe area. The controls stay inside it:
        // a ZStack sibling of that fill is laid out under the status bar, and
        // XCTest then never sees the end button.
        Group {
            if session.hasEnded {
                SessionSummaryView(session: session, onDone: onClose)
                    .transition(.opacity)
            } else if session.isPreparing {
                preparing
            } else {
                prayerScreen
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { CandleBackground() }
        .animation(.easeInOut(duration: 0.3), value: session.hasEnded)
        .preferredColorScheme(settings.appearance.colorScheme)
        .onAppear {
            if UITestLaunch.isEnabled {
                session.revealForUITest()
            }
        }
        .task { await session.begin() }
        .onChange(of: scenePhase) { _, phase in session.scenePhaseChanged(phase) }
        .onDisappear {
            session.close()
            PrayerLiveActivity.end()
        }
        .onChange(of: snapshot.stepIndex) { _, _ in
            PrayerLiveActivity.sync(
                title: snapshot.title,
                detail: sectionLine,
                completed: snapshot.completedDecades.count,
                total: snapshot.decadeTotal
            )
        }
    }

    private var preparing: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Getting ready to pray…")
                .font(.prayer(.title3))
                .foregroundStyle(Theme.secondaryInk)
            Button("Cancel") { session.endEarly() }
                .padding(.top, 12)
        }
    }

    // MARK: - Praying

    private var prayerScreen: some View {
        VStack(spacing: 0) {
            topBar
            progressHeader
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    if let mystery = trackingMystery {
                        TrackingMeditationPanel(
                            mystery: mystery,
                            cards: library.cards(for: mystery.id, on: session.meditationDay),
                            textSize: settings.textSize,
                            isExpanded: session.showsMeditation,
                            maxHeight: proxy.size.height * 0.5,
                            onToggle: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    session.setShowsMeditation(!session.showsMeditation)
                                }
                            },
                            content: content
                        )
                        .id(mystery.id)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .transition(.opacity)
                    }
                    ScrollView {
                        PrayerTextView(
                            snapshot: snapshot,
                            textSize: settings.textSize,
                            card: panelShowsMeditation ? nil : meditationCard,
                            showsMysteryDetails: !panelShowsMeditation,
                            content: content
                        )
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                        .id(snapshot.stepIndex)
                        .transition(.opacity)
                    }
                    .scrollIndicators(.hidden)
                    .animation(.easeInOut(duration: 0.25), value: snapshot.stepIndex)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: trackingMystery?.id)
            bottomBar
        }
        .contentShape(Rectangle())
        .uiTag(UITag.sessionSurface)
        .onTapGesture { session.tap() }
        .overlay {
            if let name = snapshot.nextLeaderBanner {
                NextLeaderOverlay(name: name, caption: "leads the next decade")
                    .contentShape(Rectangle())
                    .onTapGesture { session.tap() }
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: snapshot.nextLeaderBanner)
        .accessibilityAction(.magicTap) { session.tap() }
        .accessibilityAction(named: Text("Next prayer")) { session.tap() }
        .accessibilityAction(named: Text("Previous prayer")) { session.back() }
        .confirmationDialog("End this prayer?", isPresented: confirmingEndPresented, titleVisibility: .visible) {
            Button("End now", role: .destructive) { confirmEnd() }
            Button("Keep praying", role: .cancel) {}
        } message: {
            Text(snapshot.completedDecades.isEmpty
                ? "No decade is finished yet, so nothing will be saved."
                : "The decades you finished will be saved.")
        }
        .overlay {
            // The system confirmation dialog is another presentation XCTest misses
            // on the iOS 26 simulator. The same choice is drawn in the prayer screen.
            if UITestLaunch.isEnabled, confirmingEnd {
                endConfirmation
            }
        }
    }

    private var confirmingEndPresented: Binding<Bool> {
        Binding(
            get: { confirmingEnd && !UITestLaunch.isEnabled },
            set: { confirmingEnd = $0 }
        )
    }

    private var endConfirmation: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("End this prayer?")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Button("End now", role: .destructive) { confirmEnd() }
                Button("Keep praying", role: .cancel) { confirmingEnd = false }
            }
            .padding(24)
            .frame(maxWidth: 320)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func confirmEnd() {
        confirmingEnd = false
        session.endEarly()
        if UITestLaunch.isEnabled {
            Task { @MainActor in onClose() }
        }
    }

    private var topBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    confirmingEnd = true
                } label: {
                    Label("End", systemImage: "xmark")
                        .font(.title3.weight(.semibold))
                        .frame(minWidth: 48, minHeight: 48)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("End prayer")
                .accessibilityIdentifier(UITag.sessionEnd)

                Spacer(minLength: 0)

                Button {
                    session.togglePause()
                } label: {
                    Label(isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill")
                        .font(.title3.weight(.semibold))
                        .frame(minWidth: 48, minHeight: 48)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPaused ? "Resume" : "Pause")
                .accessibilityIdentifier(UITag.sessionPause)
            }
            .accessibilityElement(children: .contain)

            Picker("Mode", selection: Binding(
                get: { snapshot.mode },
                set: { session.switchMode($0) }
            )) {
                ForEach(PrayerMode.allCases) { mode in
                    Text(mode.shortTitle).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityHint("Guided: Rosary leads and you answer. Tracking: you pray and Rosary follows.")
        }
        .foregroundStyle(Theme.secondaryInk)
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }

    private var progressHeader: some View {
        VStack(spacing: 6) {
            Text(sectionLine)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.secondaryInk)
                .multilineTextAlignment(.center)
            if snapshot.decadeTotal > 1 {
                HStack(spacing: 8) {
                    ForEach(1...snapshot.decadeTotal, id: \.self) { position in
                        Capsule()
                            .fill(decadeFill(position))
                            .frame(width: 26, height: 5)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(snapshot.completedDecades.count) of \(snapshot.decadeTotal) decades complete")
            }
            if let leader = snapshot.leader {
                Text("\(leader) is leading")
                    .font(.headline)
                    .foregroundStyle(Theme.gold)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    private var bottomBar: some View {
        VStack(spacing: 14) {
            if let progress = BeadProgress.progress(for: snapshot.step) {
                BeadRingView(
                    count: progress.count,
                    completed: progress.completed,
                    current: progress.current,
                    caption: progress.accessibilityLabel
                )
                .padding(.horizontal, 28)
            }
            if settings.showSacredArt, let mystery = snapshot.mystery, let content,
               let work = content.work(for: mystery.id) {
                SacredArtView(work: work, data: content.imageData(for: mystery.id), height: 120)
                    .padding(.horizontal, 40)
            }
            VoiceIndicatorView(
                indicator: controller.voiceIndicator,
                listeningFor: snapshot.listeningFor,
                lastHeard: controller.lastHeard
            )
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)

            HStack {
                Button {
                    session.back()
                } label: {
                    Label("Back", systemImage: "arrow.uturn.backward")
                        .font(.callout)
                        .frame(minHeight: 44)
                }
                .disabled(snapshot.stepIndex == 0 && !UITestLaunch.isEnabled)
                .accessibilityLabel("Previous prayer")
                .uiTag(UITag.sessionBack)
                Spacer()
                if showsTapHint {
                    Label("Tap anywhere for the next prayer", systemImage: "hand.tap")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(Theme.gold)
                        .transition(.opacity)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(Theme.secondaryInk)
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(Theme.surface.opacity(0.6).ignoresSafeArea(edges: .bottom))
        .animation(.easeInOut, value: showsTapHint)
    }

    // MARK: - Derived

    private var isPaused: Bool {
        if case .paused = snapshot.phase { return true }
        return false
    }

    private var showsTapHint: Bool {
        if snapshot.showTapHint { return true }
        if case .unavailable = controller.voiceIndicator { return true }
        return false
    }

    private var sectionLine: String {
        switch snapshot.section {
        case .opening:
            return "Opening prayers · \(snapshot.mysterySet.title)"
        case .closing:
            return "Closing prayers"
        case .decade:
            let position = snapshot.decadePosition.map { "Decade \($0) of \(snapshot.decadeTotal)" } ?? "Decade"
            guard let mystery = snapshot.mystery else { return position }
            return "\(position) · \(mystery.title)"
        }
    }

    private func decadeFill(_ position: Int) -> Color {
        if position <= snapshot.completedDecades.count { return Theme.gold }
        if position == snapshot.decadePosition { return Theme.gold.opacity(0.45) }
        return Theme.beadEmpty
    }

    /// Tracking mode keeps the meditation on screen for the whole decade; guided mode shows it
    /// with the announcement, while the narrator pauses.
    private var trackingMystery: Mystery? {
        snapshot.mode == .tracking ? snapshot.mystery : nil
    }

    private var panelShowsMeditation: Bool {
        trackingMystery != nil && session.showsMeditation
    }

    private var meditationCard: MeditationCard? {
        guard let mystery = snapshot.step.mystery else { return nil }
        return library.card(for: mystery.id, on: session.meditationDay)
    }
}
#endif
