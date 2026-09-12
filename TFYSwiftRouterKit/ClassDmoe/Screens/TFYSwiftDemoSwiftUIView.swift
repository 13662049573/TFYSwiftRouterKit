import SwiftUI

struct TFYSwiftDemoSwiftUIView: View {
    let message: String

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "swift")
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text("SwiftUI Destination")
                .font(.largeTitle.bold())
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("由 TFYSwiftUIKitDestinationRegistry 创建 UIHostingController，业务 Route 不依赖 SwiftUI。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .navigationTitle("混合路由")
        .navigationBarTitleDisplayMode(.inline)
    }
}
