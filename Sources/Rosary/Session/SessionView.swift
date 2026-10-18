#if os(iOS)
import RosaryCore
import SwiftUI

/// The prayer screen. Only the rosary beads move to the next prayer.
struct SessionView: View {
    let session: ActiveSession
    let settings: AppSettings
    let library: SaintsLibrary
    let art: SacredArtLibrary
    let content: PrayerContent?
    let onClose: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var confirmingEnd = false
    @State private var readingScripture = false
    @State private var viewingArt = false
    @State private var artGallery = ArtGallery(plates: [])
    @State private var pace = SpeechPacing.defaultRate

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
            pace = settings.narrationRate
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
            readAloudRow
            progressHeader
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    if let mystery = snapshot.mystery {
                        ChapelMeditationView(
                            mystery: mystery,
                            content: content,
                            library: art,
                            day: session.meditationDay,
                            textSize: settings.textSize,
                            cards: library.cards(for: mystery.id, on: session.meditationDay),
                            showsSaintCards: showsSaintCards,
                            showsArt: settings.showSacredArt,
                            onNewImage: { art.showAnother(mystery: mystery.id, on: session.meditationDay) },
                            onReadScripture: {
                                viewingArt = false
                                readingScripture = true
                            },
                            onOpenArt: {
                                readingScripture = false
                                if let mystery = snapshot.mystery {
                                    artGallery = art.gallery(focus: mystery.id, content: content)
                                }
                                viewingArt = true
                            }
                        )
                        .frame(height: chapelHeight(in: proxy.size.height))
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .id(mystery.id)
                    }
                    ScrollView {
                        PrayerTextView(
                            snapshot: snapshot,
                            textSize: settings.textSize,
                            card: snapshot.mystery == nil ? meditationCard : nil,
                            showsMysteryDetails: snapshot.mystery == nil,
                            content: content
                        )
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .id(snapshot.stepIndex)
                        .transition(.opacity)
                    }
                    .scrollIndicators(.hidden)
                    .animation(.easeInOut(duration: 0.25), value: snapshot.stepIndex)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: snapshot.mystery?.id)
            bottomBar
        }
        .overlay(alignment: .top) {
            if let name = snapshot.nextLeaderBanner {
                NextLeaderOverlay(name: name, caption: "leads the next decade")
                    .padding(.horizontal, 24)
                    .padding(.top, 72)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: snapshot.nextLeaderBanner)
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
        .overlay {
            // A system sheet is invisible to XCTest on the iOS 26 simulator, so the
            // reader and the painting viewer are drawn in the prayer screen.
            if viewingArt, !artGallery.plates.isEmpty {
                SacredArtViewer(
                    gallery: artGallery,
                    image: { art.imageData(for: $0, content: content) },
                    onStep: { artGallery = artGallery.stepped($0) },
                    onClose: { viewingArt = false }
                )
                .transition(.opacity)
            }
        }
        .overlay {
            if readingScripture, let mystery = snapshot.mystery {
                ScriptureReaderView(
                    mystery: mystery,
                    passage: content?.passage(for: mystery.id),
                    translation: content?.scripture.translation ?? "",
                    fruitPrayer: content?.fruitPrayer(for: mystery.id)?.prayer,
                    textStyle: settings.textSize.prayerStyle,
                    onClose: { readingScripture = false }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: readingScripture)
        .animation(.easeInOut(duration: 0.25), value: viewingArt)
        .onChange(of: snapshot.mystery?.id) { _, _ in
            readingScripture = false
            viewingArt = false
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

                if UITestLaunch.isEnabled {
                    // The bottom Back control is below the fold on this simulator,
                    // and the prayer screen does not scroll.
                    Button("Back") { session.back() }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(UITag.sessionBack)
                }

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

    private var readAloudRow: some View {
        HStack(spacing: 12) {
            Toggle(isOn: Binding(
                get: { snapshot.readsMeditations },
                set: { session.setReadsMeditations($0) }
            )) {
                Text("Read meditation")
                    .font(.footnote.weight(.semibold))
            }
            .font(.footnote)
            .tint(Theme.gold)
            .uiTag(UITag.sessionReadMeditation)
            Slider(value: $pace, in: SpeechPacing.rateRange) {
                Text("Speaking pace")
            } onEditingChanged: { editing in
                if !editing { session.setNarrationRate(pace) }
            }
            .tint(Theme.gold)
            .uiTag(UITag.sessionRate)
            .accessibilityLabel("Speaking pace")
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 2)
    }

    private var progressHeader: some View {
        VStack(spacing: 8) {
            Text(sectionLine)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.secondaryInk)
                .multilineTextAlignment(.center)
                .uiTag(UITag.sessionSurface)
                .gesture(mysterySwipe)
            mysteryStrip
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
        .accessibilityAction(named: Text("Next mystery")) { jumpMystery(by: 1) }
        .accessibilityAction(named: Text("Previous mystery")) { jumpMystery(by: -1) }
    }

    private var mysteryStrip: some View {
        HStack(spacing: 8) {
            mysteryStep(delta: -1, title: "Previous mystery", tag: UITag.sessionMysteryPrevious, symbol: "chevron.left")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(snapshot.mysterySet.mysteries) { mystery in
                        let selected = snapshot.mystery?.number == mystery.number
                        Button {
                            session.jumpToDecade(mystery.number)
                        } label: {
                            Text("\(mystery.number)")
                                .font(.headline.monospacedDigit())
                                .frame(width: 36, height: 36)
                                .background(selected ? Theme.gold : Theme.raisedSurface, in: Circle())
                                .foregroundStyle(selected ? Theme.background : Theme.ink)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(mystery.title)
                        .accessibilityIdentifier(UITag.sessionMystery(mystery.number))
                    }
                }
            }
            mysteryStep(delta: 1, title: "Next mystery", tag: UITag.sessionMysteryNext, symbol: "chevron.right")
        }
    }

    private func mysteryStep(delta: Int, title: String, tag: String, symbol: String) -> some View {
        Button {
            jumpMystery(by: delta)
        } label: {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .uiTag(tag)
    }

    private var mysterySwipe: some Gesture {
        DragGesture(minimumDistance: 36)
            .onEnded { value in
                let horizontal = value.translation.width
                guard abs(horizontal) > abs(value.translation.height), abs(horizontal) > 48 else { return }
                jumpMystery(by: horizontal < 0 ? 1 : -1)
            }
    }

    private func jumpMystery(by delta: Int) {
        let current = snapshot.mystery?.number ?? (delta > 0 ? 0 : 6)
        let target = current + delta
        guard (1...5).contains(target) else { return }
        session.jumpToDecade(target)
    }

    private var bottomBar: some View {
        VStack(spacing: 14) {
            if let progress = BeadProgress.progress(for: snapshot.step) {
                BeadRingView(
                    count: progress.count,
                    completed: progress.completed,
                    current: progress.current,
                    caption: progress.accessibilityLabel,
                    onAdvance: { session.tap() }
                )
                .padding(.horizontal, 28)
            } else {
                OpeningBeadControl { session.tap() }
                    .padding(.horizontal, 28)
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
                .uiTag(UITag.sessionBack, when: !UITestLaunch.isEnabled)
                Spacer()
                if showsTapHint {
                    Label("Tap the beads for the next prayer", systemImage: "hand.tap")
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
            guard let mystery = snapshot.mystery else { return "Decade" }
            if snapshot.decadeTotal == 1 {
                return "Decade \(mystery.number) · \(mystery.title)"
            }
            let position = snapshot.decadePosition.map { "Decade \($0) of \(snapshot.decadeTotal)" } ?? "Decade"
            return "\(position) · \(mystery.title)"
        }
    }

    private func decadeFill(_ position: Int) -> Color {
        // In a multi-decade Rosary, capsule 1 is decade 1. Membership keeps a skipped decade empty.
        if snapshot.completedDecades.contains(position) { return Theme.gold }
        if position == snapshot.decadePosition { return Theme.gold.opacity(0.45) }
        return Theme.beadEmpty
    }

    /// The painting and Scripture stay up for the whole decade. Saint cards can be hidden in tracking.
    private var showsSaintCards: Bool {
        snapshot.mode == .guided || snapshot.mode == .guidedRosary || session.showsMeditation
    }

    private func chapelHeight(in available: CGFloat) -> CGFloat {
        let room = max(available - 56, 180)
        return min(available * 0.74, room)
    }

    private var meditationCard: MeditationCard? {
        guard let mystery = snapshot.step.mystery else { return nil }
        return library.card(for: mystery.id, on: session.meditationDay)
    }
}
#endif
