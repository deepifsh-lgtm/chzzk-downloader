// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ChzzkDownloaderMac",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "ChzzkDownloaderMac", targets: ["ChzzkDownloaderMac"])],
    targets: [.executableTarget(name: "ChzzkDownloaderMac")]
)
