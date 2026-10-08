// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Tobi",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "Tobi", targets: ["Tobi"]),
    ],
    targets: [
        .target(
            name: "Tobi",
            path: "Tobi",
            exclude: [
                "App",
                "Views",
                "Character",
                "Onboarding",
                "Input",
                "Brands/ScanSheet.swift",
                "Brands/BarcodeScanner.swift",
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "TobiTests",
            dependencies: ["Tobi"],
            path: "TobiTests",
            exclude: [
                "NutritionPlanTests.swift",
                "FirstMealDemoTests.swift",
                "VoiceSpectrumTests.swift",
                "TobiFaceAssetTests.swift",
                "WelcomeFoodRouteTests.swift",
            ]
        ),
    ]
)
