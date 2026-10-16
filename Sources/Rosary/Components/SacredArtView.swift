#if os(iOS)
import RosaryCore
import SwiftUI
import UIKit

/// A painting inside a gold iconostasis frame. Every aspect ratio fits inside the well.
struct SacredArtView: View {
    let data: Data?
    var credit: String?
    var height: CGFloat = 220
    var sessionTag: String?
    var frameTag: String?
    var imageTag: String?
    var isLoading = false
    var token = ""
    var onTap: (() -> Void)?

    @State private var veil = 0.0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            tappablePicture
            if let credit, !credit.isEmpty {
                Text(credit)
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onChange(of: token) { _, _ in
            veil = 1
            withAnimation(.easeInOut(duration: 0.45)) { veil = 0 }
        }
    }

    private var tappablePicture: some View {
        framedPicture
            .overlay {
                if let onTap {
                    Button(action: onTap) {
                        Color.white.opacity(0.001)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open the painting")
                    .uiTag(sessionTag ?? "", when: sessionTag != nil)
                }
            }
            .overlay {
                if let frameTag {
                    GeometryReader { geo in
                        AccessibilityFrameProbe(identifier: frameTag, label: "Artwork frame", value: "frame")
                            .frame(width: geo.size.width, height: geo.size.height)
                            .allowsHitTesting(false)
                    }
                    .allowsHitTesting(false)
                }
            }
    }

    private var framedPicture: some View {
        GeometryReader { geo in
            fittedWell(in: geo.size)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .iconostasis()
    }

    private func fittedWell(in size: CGSize) -> some View {
        let uiImage = data.flatMap { UIImage(data: $0) }
        let fitted = ImageFraming.fittedSize(
            imageWidth: Double(uiImage?.size.width ?? 0),
            imageHeight: Double(uiImage?.size.height ?? 0),
            containerWidth: Double(size.width),
            containerHeight: Double(size.height)
        )
        return ZStack {
            Theme.raisedSurface
            if isLoading || uiImage == nil {
                Text("†")
                    .font(.prayer(.largeTitle))
                    .foregroundStyle(Theme.gold)
                if isLoading {
                    ArtShimmer()
                }
            }
            if let uiImage, !isLoading, fitted.width > 1, fitted.height > 1 {
                let fittedWidth = CGFloat(fitted.width)
                let fittedHeight = CGFloat(fitted.height)
                let sizeValue = "\(Int(fitted.width.rounded()))x\(Int(fitted.height.rounded()))"
                ZStack {
                    Image(uiImage: uiImage)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: fittedWidth, height: fittedHeight)
                        .overlay {
                            Theme.raisedSurface
                                .opacity(veil)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityAddTraits(.isImage)
                        .accessibilityLabel(credit ?? "Mystery artwork")
                        .accessibilityHidden(imageTag != nil)
                    if let imageTag {
                        // A real view at the fitted size, so a test can measure the picture
                        // rather than the well behind it.
                        AccessibilityFrameProbe(
                            identifier: imageTag,
                            label: credit ?? "Mystery artwork",
                            value: sizeValue
                        )
                        .frame(width: fittedWidth, height: fittedHeight)
                        .allowsHitTesting(false)
                    }
                }
                .frame(width: fittedWidth, height: fittedHeight)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }
}

/// Reports a rectangle as its own accessibility element, at that view's exact size.
private struct AccessibilityFrameProbe: UIViewRepresentable {
    var identifier: String
    var label: String
    var value: String

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = true
        view.accessibilityTraits = .image
        apply(to: view)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        apply(to: view)
    }

    private func apply(to view: UIView) {
        view.accessibilityIdentifier = identifier
        view.accessibilityLabel = label
        view.accessibilityValue = value
    }
}

/// A gold band moving across the empty well while a painting is on its way.
private struct ArtShimmer: View {
    @State private var phase: CGFloat = -0.6

    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [.clear, Theme.gold.opacity(0.45), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: geo.size.width, height: geo.size.height * 0.45)
            .offset(y: phase * geo.size.height)
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(.linear(duration: 1.15).repeatForever(autoreverses: false)) {
                phase = 1.3
            }
        }
    }
}
#endif
