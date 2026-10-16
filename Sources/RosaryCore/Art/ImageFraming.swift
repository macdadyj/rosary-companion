import Foundation

/// The size of a picture after it has been fitted inside a frame without cropping.
public struct FittedSize: Equatable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public enum ImageFraming {
    /// Aspect-fit. The result stays inside the container on both axes, for a tall or a wide picture.
    public static func fittedSize(
        imageWidth: Double,
        imageHeight: Double,
        containerWidth: Double,
        containerHeight: Double
    ) -> FittedSize {
        guard imageWidth > 0, imageHeight > 0, containerWidth > 0, containerHeight > 0 else {
            return FittedSize(width: 0, height: 0)
        }
        let scale = min(containerWidth / imageWidth, containerHeight / imageHeight)
        return FittedSize(width: imageWidth * scale, height: imageHeight * scale)
    }
}
