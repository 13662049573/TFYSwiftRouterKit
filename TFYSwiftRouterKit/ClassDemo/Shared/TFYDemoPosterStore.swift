import UIKit

/// 只读取参考图中的封面区域。布局、文字、搜索和底栏均由原生控件构建。
final class TFYDemoPosterStore: @unchecked Sendable {
    static let shared = TFYDemoPosterStore()
    private let cache = NSCache<NSNumber, UIImage>()
    private let queue = DispatchQueue(label: "demo.posters", qos: .userInitiated)
    private let rectangles: [CGRect] = [
        .init(x: 8, y: 149, width: 204, height: 273),
        .init(x: 220, y: 149, width: 204, height: 273),
        .init(x: 8, y: 495, width: 204, height: 273),
        .init(x: 220, y: 495, width: 204, height: 273),
        .init(x: 8, y: 841, width: 204, height: 44),
        .init(x: 220, y: 841, width: 204, height: 44),
    ]

    func load(_ index: Int, completion: @escaping @MainActor @Sendable (UIImage?) -> Void) {
        let key = NSNumber(value: index)
        if let image = cache.object(forKey: key) {
            Task { @MainActor in completion(image) }
            return
        }
        queue.async { [self] in
            // 首帧多个回调可能同时排队，解码前再次查缓存。
            if let cached = cache.object(forKey: key) {
                Task { @MainActor in completion(cached) }
                return
            }
            guard rectangles.indices.contains(index), let source = UIImage(named: "VideoPosterSource")?.cgImage else {
                Task { @MainActor in completion(nil) }
                return
            }
            let scale = CGFloat(source.width) / 432
            let rect = rectangles[index].applying(.init(scaleX: scale, y: scale))
            let image = source.cropping(to: rect).map { UIImage(cgImage: $0) }
            let decoded = image?.preparingForDisplay() ?? image
            if let decoded { cache.setObject(decoded, forKey: key) }
            Task { @MainActor in completion(decoded) }
        }
    }
}
