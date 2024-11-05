// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "single-file-command-line-swift-thread-example",
	platforms: [.macOS(.v14)],
    dependencies: [
		.package(url: "https://github.com/simplito/privmx-endpoint-swift", .upToNextMajor(from: .init(2, 0, 0)))
    ],
    targets: [
        .executableTarget(
            name: "single-file-command-line-swift-thread-example",
            dependencies: [
				.product(name: "PrivMXEndpointSwift", package: "privmx-endpoint-swift"),
            ],
			resources: [
				.copy("cacert.pem")],
			swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
    ],
	cxxLanguageStandard: .cxx17
)

