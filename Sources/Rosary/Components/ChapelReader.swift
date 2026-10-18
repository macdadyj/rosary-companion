#if os(iOS)
import RosaryCore
import SwiftUI
import UIKit

/// The whole passage, large enough to read, on a full-screen cover.
struct ScriptureReaderView: View {
    let mystery: Mystery
    let passage: ScripturePassage?
    let translation: String
    let fruitPrayer: String?
    let textStyle: Font.TextStyle
    let onClose: () -> Void

    @State private var drop: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                passageBody
                    .padding(.horizontal, 24)
                    .padding(.bottom, 36)
                    .frame(maxWidth: 640, alignment: .leading)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { CandleBackground() }
        .offset(y: max(drop, 0))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(UITag.sessionScriptureReader)
        .accessibilityHint("Swipe down to close")
    }

    private var header: some View {
        VStack(spacing: 8) {
            Capsule()
                .fill(Theme.gold.opacity(0.7))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .gesture(dismissDrag)
                .accessibilityHidden(true)
            HStack(spacing: 12) {
                closeButton
                Text("Scripture")
                    .font(.prayer(.headline, weight: .semibold))
                    .foregroundStyle(Theme.gold)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .gesture(dismissDrag)
                Color.clear.frame(width: 48, height: 48).accessibilityHidden(true)
            }
            .padding(.horizontal, 12)
        }
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Label("Close", systemImage: "xmark")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.secondaryInk)
                .frame(minWidth: 48, minHeight: 48)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
        .accessibilityIdentifier(UITag.sessionScriptureClose)
    }

    private var passageBody: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(mystery.title)
                .font(.prayer(.title2, weight: .semibold))
                .foregroundStyle(Theme.gold)
                .fixedSize(horizontal: false, vertical: true)
            if let passage, !passage.verses.isEmpty {
                Text(passage.reference)
                    .font(.headline)
                    .foregroundStyle(Theme.gold)
                Text(passage.body)
                    .font(.prayer(textStyle))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(8)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier(UITag.sessionScriptureBody)
                if !translation.isEmpty {
                    Text(translation)
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryInk)
                }
                if let note = passage.note, !note.isEmpty {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text(mystery.scripture)
                    .font(.prayer(textStyle))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(UITag.sessionScriptureBody)
            }
            Text("Fruit of the mystery: \(mystery.fruit)")
                .font(.prayer(.body))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            if let fruitPrayer, !fruitPrayer.isEmpty {
                Text(fruitPrayer)
                    .font(.prayer(.body))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 8)
    }

    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 16)
            .onChanged { value in
                drop = max(value.translation.height, 0)
            }
            .onEnded { value in
                if value.translation.height > 120 {
                    onClose()
                } else {
                    withAnimation(.easeOut(duration: 0.2)) { drop = 0 }
                }
            }
    }
}

/// The painting, full screen, with pinch-to-zoom, pan, and the next and previous works.
struct SacredArtViewer: View {
    let gallery: ArtGallery
    let image: (ArtPlate) -> Data?
    let onStep: (Int) -> Void
    let onClose: () -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var pinching = false
    @State private var ignoreDragUntil = Date.distantPast

    private var plateID: String { gallery.plate?.id ?? "" }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            painting
                .scaleEffect(scale)
                .offset(offset)
                .allowsHitTesting(false)
            Color.clear
                .contentShape(Rectangle())
                .gesture(magnify)
                .simultaneousGesture(pan)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .top) { topChrome }
        .overlay(alignment: .leading) { stepButton(delta: -1, label: "Previous painting", systemImage: "chevron.left", tag: UITag.sessionArtPrevious) }
        .overlay(alignment: .trailing) { stepButton(delta: 1, label: "Next painting", systemImage: "chevron.right", tag: UITag.sessionArtNext) }
        .overlay(alignment: .bottom) { caption }
        .onChange(of: plateID) { _, _ in resetZoom() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(UITag.sessionArtViewer)
        .accessibilityHint("Swipe left or right for another painting. Swipe down to close.")
    }

    private var topChrome: some View {
        HStack {
            closeButton
            Spacer(minLength: 0)
            Text(gallery.positionLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.black.opacity(0.45), in: Capsule())
                .accessibilityIdentifier(UITag.sessionArtPage)
            Spacer(minLength: 0)
            Color.clear.frame(width: 48, height: 48).accessibilityHidden(true)
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }

    private func stepButton(delta: Int, label: String, systemImage: String, tag: String) -> some View {
        Button {
            onStep(delta)
        } label: {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(.black.opacity(0.45), in: Circle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .accessibilityLabel(label)
        .accessibilityIdentifier(tag)
    }

    private var caption: some View {
        let text = gallery.plate?.caption ?? ""
        return Text(text.isEmpty ? "Mystery artwork" : text)
            .font(.footnote)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(4)
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(.black.opacity(0.62))
            .accessibilityIdentifier(UITag.sessionArtCredit)
    }

    private func resetZoom() {
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Label("Close", systemImage: "xmark")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(minWidth: 48, minHeight: 48)
                .background(.black.opacity(0.45), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
        .accessibilityIdentifier(UITag.sessionArtClose)
    }

    @ViewBuilder
    private var painting: some View {
        GeometryReader { geo in
            let uiImage = gallery.plate.flatMap { image($0) }.flatMap { UIImage(data: $0) }
            let fitted = ImageFraming.fittedSize(
                imageWidth: Double(uiImage?.size.width ?? 0),
                imageHeight: Double(uiImage?.size.height ?? 0),
                containerWidth: Double(geo.size.width),
                containerHeight: Double(geo.size.height)
            )
            ZStack {
                if let uiImage, fitted.width > 1, fitted.height > 1 {
                    Image(uiImage: uiImage)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: CGFloat(fitted.width), height: CGFloat(fitted.height))
                } else {
                    Text("†")
                        .font(.prayer(.largeTitle))
                        .foregroundStyle(Theme.gold)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private var magnify: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                pinching = true
                scale = min(max(lastScale * value.magnification, 1), 5)
            }
            .onEnded { _ in
                pinching = false
                if scale <= 1.02 {
                    scale = 1
                    offset = .zero
                    lastOffset = .zero
                }
                lastScale = scale
                ignoreDragUntil = Date().addingTimeInterval(0.35)
            }
    }

    private var pan: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !pinching, scale > 1.05 else { return }
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { value in
                guard !pinching, Date() > ignoreDragUntil else { return }
                if scale > 1.05 {
                    lastOffset = offset
                    return
                }
                if abs(value.translation.width) > 70, abs(value.translation.width) > abs(value.translation.height) {
                    onStep(value.translation.width < 0 ? 1 : -1)
                    return
                }
                if value.translation.height > 120, value.translation.height > abs(value.translation.width) {
                    onClose()
                }
            }
    }
}
#endif
