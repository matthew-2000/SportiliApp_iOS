import Foundation
import XcodeProj
import PathKit

// Structured, idempotent XcodeProj editing. Sources use synchronized folders.
let path = Path(CommandLine.arguments.dropFirst().first ?? "SportiliApp.xcodeproj")
let project = try XcodeProj(path: path)
let pbx = project.pbxproj
let root = try pbx.rootProject()!
let phone = pbx.nativeTargets.first { $0.name == "SportiliApp" }!
if CommandLine.arguments.contains("--surfaces") {
    func group(_ name: String) -> PBXFileSystemSynchronizedRootGroup {
        if let found = root.mainGroup?.children.compactMap { $0 as? PBXFileSystemSynchronizedRootGroup }.first(where: { $0.path == name }) { return found }
        let g = PBXFileSystemSynchronizedRootGroup(sourceTree: .group, path: name)
        pbx.add(object: g); root.mainGroup?.children.append(g); return g
    }
    let shared = group("SurfaceShared")
    let widget = group("SportiliWidgets")
    let watch = pbx.nativeTargets.first { $0.name == "SportiliWatch" }!
    for (target, entitlement) in [(phone, "Phone"), (watch, "Watch")] {
        if !(target.fileSystemSynchronizedGroups ?? []).contains(shared) { target.fileSystemSynchronizedGroups = (target.fileSystemSynchronizedGroups ?? []) + [shared] }
        for config in target.buildConfigurationList?.buildConfigurations ?? [] { config.buildSettings["CODE_SIGN_ENTITLEMENTS"] = entitlement + ".entitlements" }
    }
    for (name, host, isWatch, entitlement) in [("SportiliWidgets", phone, false, "Widgets"), ("SportiliWatchWidgets", watch, true, "WatchWidgets")] {
        if pbx.nativeTargets.contains(where: { $0.name == name }) { continue }
        let configs = ["Debug", "Release"].map { name -> XCBuildConfiguration in
            var settings: [String: Any] = [
                "PRODUCT_NAME": "$(TARGET_NAME)", "SWIFT_VERSION": "5.0", "GENERATE_INFOPLIST_FILE": "NO",
                "INFOPLIST_FILE": "WidgetInfo.plist", "SKIP_INSTALL": "YES", "APPLICATION_EXTENSION_API_ONLY": "YES",
                "CODE_SIGN_ENTITLEMENTS": entitlement + ".entitlements", "CODE_SIGN_STYLE": "Automatic", "DEVELOPMENT_TEAM": "W5F66P2G2K",
                "CURRENT_PROJECT_VERSION": "16", "MARKETING_VERSION": "2.0",
                "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks", "@executable_path/../../Frameworks"],
                "SDKROOT": isWatch ? "watchos" : "iphoneos", "SUPPORTED_PLATFORMS": isWatch ? "watchos watchsimulator" : "iphoneos iphonesimulator",
                "PRODUCT_BUNDLE_IDENTIFIER": isWatch ? "com.matthew.SportiliApp.watchkitapp.widgets" : "com.matthew.SportiliApp.widgets",
                "TARGETED_DEVICE_FAMILY": isWatch ? "4" : "1,2"
            ]
            settings[isWatch ? "WATCHOS_DEPLOYMENT_TARGET" : "IPHONEOS_DEPLOYMENT_TARGET"] = isWatch ? "10.0" : "17.0"
            let c = XCBuildConfiguration(name: name, buildSettings: settings); pbx.add(object: c); return c
        }
        let list = XCConfigurationList(buildConfigurations: configs, defaultConfigurationName: "Release"); pbx.add(object: list)
        let product = PBXFileReference(sourceTree: .buildProductsDir, explicitFileType: "wrapper.app-extension", path: name + ".appex", includeInIndex: false)
        pbx.add(object: product); root.productsGroup?.children.append(product)
        let phases: [PBXBuildPhase] = [PBXSourcesBuildPhase(), PBXFrameworksBuildPhase(), PBXResourcesBuildPhase()]
        phases.forEach { pbx.add(object: $0) }
        let target = PBXNativeTarget(name: name, buildConfigurationList: list, buildPhases: phases, productName: name, product: product, productType: .appExtension)
        pbx.add(object: target); root.targets.append(target); target.fileSystemSynchronizedGroups = [shared, widget]
        _ = try host.addDependency(target: target)
        let file = PBXBuildFile(file: product, settings: ["ATTRIBUTES": ["RemoveHeadersOnCopy"]]); pbx.add(object: file)
        let copy = PBXCopyFilesBuildPhase(dstSubfolderSpec: .plugins, name: "Embed " + name, files: [file]); pbx.add(object: copy); host.buildPhases.append(copy)
    }
    try pbx.write(path: path + "project.pbxproj", override: true)
    exit(0)
}
if CommandLine.arguments.contains("--refresh-settings") {
    for config in phone.buildConfigurationList?.buildConfigurations ?? [] {
        var flags = config.buildSettings["OTHER_LDFLAGS"] as? [String]
            ?? (config.buildSettings["OTHER_LDFLAGS"] as? String).map { [$0] } ?? ["$(inherited)"]
        if !flags.contains("-ObjC") { flags.append("-ObjC") }
        config.buildSettings["OTHER_LDFLAGS"] = flags
    }
    for target in pbx.nativeTargets where target.name == "SportiliWatch" {
        for config in target.buildConfigurationList?.buildConfigurations ?? [] {
            config.buildSettings["ASSETCATALOG_COMPILER_APPICON_NAME"] = "AppIcon"
        }
    }
    try pbx.write(path: path + "project.pbxproj", override: true)
    for name in ["SportiliApp", "SportiliWatch"] {
        let schemePath = path + "xcshareddata/xcschemes/\(name).xcscheme"
        let scheme = try XCScheme(path: schemePath)
        scheme.buildAction?.parallelizeBuild = true
        scheme.buildAction?.buildImplicitDependencies = true
        try scheme.write(path: schemePath, override: true)
    }
    exit(0)
}
if CommandLine.arguments.contains("--phone-only-test") {
    phone.dependencies.removeAll { $0.target?.name == "SportiliWatch" }
    phone.buildPhases.removeAll { ($0 as? PBXCopyFilesBuildPhase)?.name == "Embed Watch Content" }
    try pbx.write(path: path + "project.pbxproj", override: true)
    exit(0)
}
if CommandLine.arguments.contains("--test-host") {
    for target in pbx.nativeTargets {
        for config in target.buildConfigurationList?.buildConfigurations ?? [] {
            config.buildSettings["PRODUCT_BUNDLE_IDENTIFIER"] = target.name == "SportiliApp" ? "com.sportili.local-watch-sdk" : "com.sportili.local-watch-sdk.watchkitapp"
            if target.name == "SportiliWatch" {
                config.buildSettings["INFOPLIST_KEY_WKCompanionAppBundleIdentifier"] = "com.sportili.local-watch-sdk"
            }
        }
    }
    try pbx.write(path: path + "project.pbxproj", override: true)
    exit(0)
}
guard !pbx.nativeTargets.contains(where: { $0.name == "SportiliWatch" }) else {
    print("Watch target already configured"); exit(0)
}
pbx.objectVersion = 77
func folder(_ path: String) -> PBXFileSystemSynchronizedRootGroup {
    let group = PBXFileSystemSynchronizedRootGroup(sourceTree: .group, path: path)
    pbx.add(object: group); root.mainGroup?.children.append(group)
    return group
}
let shared = folder("CompanionShared")
let bridge = folder("PhoneCompanion")
let watchSources = folder("SportiliWatch")
phone.fileSystemSynchronizedGroups = (phone.fileSystemSynchronizedGroups ?? []) + [shared, bridge]
let configs = ["Debug", "Release"].map { name -> XCBuildConfiguration in
    let config = XCBuildConfiguration(name: name, buildSettings: [
        "SDKROOT": "watchos", "SUPPORTED_PLATFORMS": "watchos watchsimulator",
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "WATCHOS_DEPLOYMENT_TARGET": "10.0", "TARGETED_DEVICE_FAMILY": "4",
        "PRODUCT_BUNDLE_IDENTIFIER": "com.matthew.SportiliApp.watchkitapp",
        "PRODUCT_NAME": "$(TARGET_NAME)", "SWIFT_VERSION": "5.0",
        "GENERATE_INFOPLIST_FILE": "YES", "INFOPLIST_KEY_WKApplication": "YES",
        "INFOPLIST_KEY_WKCompanionAppBundleIdentifier": "com.matthew.SportiliApp",
        "INFOPLIST_KEY_WKRunsIndependentlyOfCompanionApp": "NO",
        "INFOPLIST_KEY_CFBundleDisplayName": "SportiliApp",
        "DEVELOPMENT_TEAM": "W5F66P2G2K", "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "16", "MARKETING_VERSION": "2.0", "SKIP_INSTALL": "YES",
        "SWIFT_EMIT_LOC_STRINGS": "YES", "ENABLE_PREVIEWS": "YES",
        "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"]
    ])
    pbx.add(object: config); return config
}
let list = XCConfigurationList(buildConfigurations: configs, defaultConfigurationName: "Release")
pbx.add(object: list)
let product = PBXFileReference(sourceTree: .buildProductsDir, explicitFileType: "wrapper.application", path: "SportiliWatch.app", includeInIndex: false)
pbx.add(object: product); root.productsGroup?.children.append(product)
let sources = PBXSourcesBuildPhase(); let resources = PBXResourcesBuildPhase(); let frameworks = PBXFrameworksBuildPhase()
[sources as PBXBuildPhase, resources, frameworks].forEach { pbx.add(object: $0) }
let watch = PBXNativeTarget(name: "SportiliWatch", buildConfigurationList: list,
    buildPhases: [sources, frameworks, resources], productName: "SportiliWatch", product: product, productType: .application)
pbx.add(object: watch); root.targets.append(watch)
watch.fileSystemSynchronizedGroups = [shared, watchSources]
_ = try phone.addDependency(target: watch)
let embedded = PBXBuildFile(file: product, settings: ["ATTRIBUTES": ["RemoveHeadersOnCopy"]])
pbx.add(object: embedded)
let copy = PBXCopyFilesBuildPhase(dstPath: "$(CONTENTS_FOLDER_PATH)/Watch", dstSubfolderSpec: .productsDirectory,
    name: "Embed Watch Content", files: [embedded])
pbx.add(object: copy); phone.buildPhases.append(copy)
try pbx.write(path: path + "project.pbxproj", override: true)
for target in [phone, watch] {
    let ref = XCScheme.BuildableReference(referencedContainer: "container:SportiliApp.xcodeproj", blueprint: target,
        buildableName: target.name + ".app", blueprintName: target.name)
    let scheme = XCScheme(name: target.name, lastUpgradeVersion: "2700", version: "1.3",
        buildAction: XCScheme.BuildAction(buildActionEntries: [.init(buildableReference: ref, buildFor: [.running, .testing, .profiling, .archiving, .analyzing])], parallelizeBuild: true, buildImplicitDependencies: true),
        launchAction: XCScheme.LaunchAction(runnable: XCScheme.BuildableProductRunnable(buildableReference: ref), buildConfiguration: "Debug"))
    let directory = path + "xcshareddata/xcschemes"
    try directory.mkpath()
    try scheme.write(path: directory + "\(target.name).xcscheme", override: false)
}
print("Configured companion target and shared schemes")
