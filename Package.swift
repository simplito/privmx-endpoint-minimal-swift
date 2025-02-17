// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "privmx-endpoint-minimal-swift",
	platforms: [
		.macOS(.v14)
	],
    dependencies: [
		.package(
			url: "https://github.com/simplito/privmx-endpoint-swift-extra",
			.upToNextMinor(from:.init(2, 2, 0,prereleaseIdentifiers: ["rc6"]))
		),
		.package(
			url: "https://github.com/simplito/privmx-endpoint-swift",
			.upToNextMinor(from:.init(2, 2, 0,prereleaseIdentifiers: ["rc6"]))
		),
    ],
    targets: [
        .executableTarget(
            name: "Low-Level_Thread_Example",
            dependencies: [
				.product(name: "PrivMXEndpointSwift", package: "privmx-endpoint-swift"),
            ],
			swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
		.executableTarget(
			name: "High-Level_Thread_Example",
			dependencies: [
				.product(name: "PrivMXEndpointSwiftExtra", package: "privmx-endpoint-swift-extra"),
			],
			swiftSettings: [.interoperabilityMode(.Cxx)]
		),
.executableTarget(
            name: "Low-Level_Store_Example",
            dependencies: [
				.product(name: "PrivMXEndpointSwift", package: "privmx-endpoint-swift"),
            ],
			swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
		.executableTarget(
			name: "High-Level_Store_Example",
			dependencies: [
				.product(name: "PrivMXEndpointSwiftExtra", package: "privmx-endpoint-swift-extra"),
			],
			swiftSettings: [.interoperabilityMode(.Cxx)]
		),
.executableTarget(
            name: "Low-Level_Inbox_Example",
            dependencies: [
				.product(name: "PrivMXEndpointSwift", package: "privmx-endpoint-swift"),
            ],
			swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
		.executableTarget(
			name: "High-Level_Inbox_Example",
			dependencies: [
				.product(name: "PrivMXEndpointSwiftExtra", package: "privmx-endpoint-swift-extra"),
			],
			swiftSettings: [.interoperabilityMode(.Cxx)]
		),
    ],
	cxxLanguageStandard: .cxx17
)

