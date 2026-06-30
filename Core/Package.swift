// swift-tools-version: 5.9
import PackageDescription

// BedtimeBooksCore holds all platform-independent (Foundation-only) logic so it
// can be unit-tested with `swift test` on any platform — including this Linux CI
// box — without Xcode, UIKit, AVFoundation, or SwiftData. The iOS app target
// depends on this package locally and layers the Apple-framework code on top.
let package = Package(
    name: "BedtimeBooksCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "BedtimeBooksCore", targets: ["BedtimeBooksCore"]),
    ],
    targets: [
        .target(name: "BedtimeBooksCore"),
        .testTarget(
            name: "BedtimeBooksCoreTests",
            dependencies: ["BedtimeBooksCore"]
        ),
    ]
)
