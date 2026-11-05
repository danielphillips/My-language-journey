#!/usr/bin/env python3
"""Generates MyRussian.xcodeproj (objectVersion 77, synchronized folders) and the shared scheme.

Synchronized root groups mean Xcode picks up every file in MyRussian/, MyRussianWidget/,
MyRussianTests/ and MyRussianUITests/ automatically, so the project file never needs per-file edits.
Re-run after changing targets or build settings:  python3 scripts/generate_xcodeproj.py
"""
import hashlib
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
BUNDLE_PREFIX = "com.danielphillips"
DEPLOYMENT_TARGET = "26.0"
DEVELOPMENT_TEAM = "EZ89RRBK7E"
# Shared by the app and the lock-screen widget; see Config/*.entitlements.
APP_GROUP = "group.com.danielphillips.MyRussian"


def oid(name: str) -> str:
    return hashlib.md5(name.encode()).hexdigest()[:24].upper()


ids = {n: oid(n) for n in [
    "project", "mainGroup", "productsGroup",
    "appGroup", "unitGroup", "uiGroup",
    "appProduct", "unitProduct", "uiProduct",
    "appTarget", "unitTarget", "uiTarget",
    "appSources", "appFrameworks", "appResources",
    "unitSources", "unitFrameworks", "unitResources",
    "uiSources", "uiFrameworks", "uiResources",
    "unitProxy", "uiProxy", "unitDependency", "uiDependency",
    "projectConfigs", "projectDebug", "projectRelease",
    "appConfigs", "appDebug", "appRelease",
    "unitConfigs", "unitDebug", "unitRelease",
    "uiConfigs", "uiDebug", "uiRelease",
    "corePackage", "coreProduct", "coreBuildFile",
    "widgetGroup", "widgetProduct", "widgetTarget",
    "widgetSources", "widgetFrameworks", "widgetResources",
    "widgetProxy", "widgetDependency", "widgetConfigs", "widgetDebug", "widgetRelease",
    "widgetCoreProduct", "widgetCoreBuildFile", "widgetEmbedBuildFile", "appEmbedExtensions",
]}


def settings_block(settings: dict) -> str:
    lines = []
    for key in sorted(settings):
        value = settings[key]
        if isinstance(value, list):
            items = "".join(f'\t\t\t\t\t"{v}",\n' for v in value)
            lines.append(f"\t\t\t\t{key} = (\n{items}\t\t\t\t);")
        else:
            text = str(value)
            needs_quotes = not text.replace("_", "").replace(".", "").isalnum()
            lines.append(f'\t\t\t\t{key} = "{text}";' if needs_quotes else f"\t\t\t\t{key} = {text};")
    return "\n".join(lines)


project_common = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "YES",
    "CLANG_ANALYZER_NONNULL": "YES",
    "CLANG_ENABLE_MODULES": "YES",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "COPY_PHASE_STRIP": "NO",
    "ENABLE_STRICT_OBJC_MSGSEND": "YES",
    "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
    "GCC_C_LANGUAGE_STANDARD": "gnu17",
    "GCC_NO_COMMON_BLOCKS": "YES",
    "IPHONEOS_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
    "LOCALIZATION_PREFERS_STRING_CATALOGS": "YES",
    "SDKROOT": "iphoneos",
    "SWIFT_VERSION": "5.0",
}
project_debug = {**project_common,
    "DEBUG_INFORMATION_FORMAT": "dwarf",
    "ENABLE_TESTABILITY": "YES",
    "GCC_DYNAMIC_NO_PIC": "NO",
    "GCC_OPTIMIZATION_LEVEL": "0",
    "GCC_PREPROCESSOR_DEFINITIONS": ["DEBUG=1", "$(inherited)"],
    "ONLY_ACTIVE_ARCH": "YES",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG $(inherited)",
    "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
}
project_release = {**project_common,
    "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
    "ENABLE_NS_ASSERTIONS": "NO",
    "SWIFT_COMPILATION_MODE": "wholemodule",
    "VALIDATE_PRODUCT": "YES",
}
app_settings = {
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
    "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
    "CODE_SIGN_ENTITLEMENTS": "Config/MyRussian.entitlements",
    "CODE_SIGN_STYLE": "Automatic",
    "DEVELOPMENT_TEAM": DEVELOPMENT_TEAM,
    "CURRENT_PROJECT_VERSION": "1",
    "ENABLE_PREVIEWS": "YES",
    "GENERATE_INFOPLIST_FILE": "YES",
    "INFOPLIST_KEY_CFBundleDisplayName": "My Russian",
    "INFOPLIST_KEY_ITSAppUsesNonExemptEncryption": "NO",
    "INFOPLIST_KEY_LSApplicationCategoryType": "public.app-category.education",
    "INFOPLIST_KEY_NSMicrophoneUsageDescription":
        "My Russian records you saying Russian words so you can listen back to your pronunciation. Recordings stay on this device.",
    "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES",
    "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents": "YES",
    "INFOPLIST_KEY_UILaunchScreen_Generation": "YES",
    "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone": "UIInterfaceOrientationPortrait",
    "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"],
    "MARKETING_VERSION": "1.0",
    "PRODUCT_BUNDLE_IDENTIFIER": f"{BUNDLE_PREFIX}.MyRussian",
    "PRODUCT_NAME": "$(TARGET_NAME)",
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "TARGETED_DEVICE_FAMILY": "1",
}
unit_settings = {
    "BUNDLE_LOADER": "$(TEST_HOST)",
    "CODE_SIGN_STYLE": "Automatic",
    "DEVELOPMENT_TEAM": DEVELOPMENT_TEAM,
    "CURRENT_PROJECT_VERSION": "1",
    "GENERATE_INFOPLIST_FILE": "YES",
    "MARKETING_VERSION": "1.0",
    "PRODUCT_BUNDLE_IDENTIFIER": f"{BUNDLE_PREFIX}.MyRussianTests",
    "PRODUCT_NAME": "$(TARGET_NAME)",
    "SWIFT_EMIT_LOC_STRINGS": "NO",
    "TARGETED_DEVICE_FAMILY": "1",
    "TEST_HOST": "$(BUILT_PRODUCTS_DIR)/MyRussian.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/MyRussian",
}
widget_settings = {
    "CODE_SIGN_ENTITLEMENTS": "Config/MyRussianWidget.entitlements",
    "CODE_SIGN_STYLE": "Automatic",
    "DEVELOPMENT_TEAM": DEVELOPMENT_TEAM,
    "CURRENT_PROJECT_VERSION": "1",  # must match the app's
    "GENERATE_INFOPLIST_FILE": "YES",
    "INFOPLIST_FILE": "Config/MyRussianWidget-Info.plist",
    "INFOPLIST_KEY_CFBundleDisplayName": "My Russian",
    "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks", "@executable_path/../../Frameworks"],
    "MARKETING_VERSION": "1.0",  # must match the app's
    "PRODUCT_BUNDLE_IDENTIFIER": f"{BUNDLE_PREFIX}.MyRussian.Widget",
    "PRODUCT_NAME": "$(TARGET_NAME)",
    "SKIP_INSTALL": "YES",
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "TARGETED_DEVICE_FAMILY": "1",
}
ui_settings = {
    "CODE_SIGN_STYLE": "Automatic",
    "DEVELOPMENT_TEAM": DEVELOPMENT_TEAM,
    "CURRENT_PROJECT_VERSION": "1",
    "GENERATE_INFOPLIST_FILE": "YES",
    "MARKETING_VERSION": "1.0",
    "PRODUCT_BUNDLE_IDENTIFIER": f"{BUNDLE_PREFIX}.MyRussianUITests",
    "PRODUCT_NAME": "$(TARGET_NAME)",
    "SWIFT_EMIT_LOC_STRINGS": "NO",
    "TARGETED_DEVICE_FAMILY": "1",
    "TEST_TARGET_NAME": "MyRussian",
}


def config(key, name, settings):
    return f"""\t\t{ids[key]} /* {name} */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{settings_block(settings)}
\t\t\t}};
\t\t\tname = {name};
\t\t}};
"""


def config_list(key, debug, release, owner):
    return f"""\t\t{ids[key]} /* Build configuration list for {owner} */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{ids[debug]} /* Debug */,
\t\t\t\t{ids[release]} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
"""


def phase(key, isa, name, files=""):
    return f"""\t\t{ids[key]} /* {name} */ = {{
\t\t\tisa = {isa};
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{files}\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""


def target(key, name, configs, phases, group, product, product_type, dependency=None, packages=""):
    dependencies = [dependency] if isinstance(dependency, str) else (dependency or [])
    deps = "".join(f"\t\t\t\t{ids[d]} /* PBXTargetDependency */,\n" for d in dependencies)
    phase_lines = "".join(f"\t\t\t\t{ids[p]} /* {n} */,\n" for p, n in phases)
    package_block = f"\t\t\tpackageProductDependencies = (\n{packages}\t\t\t);\n" if packages else ""
    return f"""\t\t{ids[key]} /* {name} */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {ids[configs]} /* Build configuration list for PBXNativeTarget "{name}" */;
\t\t\tbuildPhases = (
{phase_lines}\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
{deps}\t\t\t);
\t\t\tfileSystemSynchronizedGroups = (
\t\t\t\t{ids[group]} /* {name} */,
\t\t\t);
\t\t\tname = {name};
{package_block}\t\t\tproductName = {name};
\t\t\tproductReference = {ids[product]} /* {name} */;
\t\t\tproductType = "{product_type}";
\t\t}};
"""


pbxproj = f"""// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{
\t}};
\tobjectVersion = 77;
\tobjects = {{

/* Begin PBXBuildFile section */
\t\t{ids['coreBuildFile']} /* MyRussianCore in Frameworks */ = {{isa = PBXBuildFile; productRef = {ids['coreProduct']} /* MyRussianCore */; }};
\t\t{ids['widgetCoreBuildFile']} /* MyRussianCore in Frameworks */ = {{isa = PBXBuildFile; productRef = {ids['widgetCoreProduct']} /* MyRussianCore */; }};
\t\t{ids['widgetEmbedBuildFile']} /* MyRussianWidget.appex in Embed Foundation Extensions */ = {{isa = PBXBuildFile; fileRef = {ids['widgetProduct']} /* MyRussianWidget.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};
/* End PBXBuildFile section */

/* Begin PBXContainerItemProxy section */
\t\t{ids['unitProxy']} /* PBXContainerItemProxy */ = {{
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = {ids['project']} /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = {ids['appTarget']};
\t\t\tremoteInfo = MyRussian;
\t\t}};
\t\t{ids['uiProxy']} /* PBXContainerItemProxy */ = {{
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = {ids['project']} /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = {ids['appTarget']};
\t\t\tremoteInfo = MyRussian;
\t\t}};
\t\t{ids['widgetProxy']} /* PBXContainerItemProxy */ = {{
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = {ids['project']} /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = {ids['widgetTarget']};
\t\t\tremoteInfo = MyRussianWidget;
\t\t}};
/* End PBXContainerItemProxy section */

/* Begin PBXCopyFilesBuildPhase section */
\t\t{ids['appEmbedExtensions']} /* Embed Foundation Extensions */ = {{
\t\t\tisa = PBXCopyFilesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tdstPath = "";
\t\t\tdstSubfolderSpec = 13;
\t\t\tfiles = (
\t\t\t\t{ids['widgetEmbedBuildFile']} /* MyRussianWidget.appex in Embed Foundation Extensions */,
\t\t\t);
\t\t\tname = "Embed Foundation Extensions";
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXCopyFilesBuildPhase section */

/* Begin PBXFileReference section */
\t\t{ids['appProduct']} /* MyRussian.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = MyRussian.app; sourceTree = BUILT_PRODUCTS_DIR; }};
\t\t{ids['unitProduct']} /* MyRussianTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = MyRussianTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};
\t\t{ids['uiProduct']} /* MyRussianUITests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = MyRussianUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};
\t\t{ids['widgetProduct']} /* MyRussianWidget.appex */ = {{isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = MyRussianWidget.appex; sourceTree = BUILT_PRODUCTS_DIR; }};
/* End PBXFileReference section */

/* Begin PBXFileSystemSynchronizedRootGroup section */
\t\t{ids['appGroup']} /* MyRussian */ = {{isa = PBXFileSystemSynchronizedRootGroup; path = MyRussian; sourceTree = "<group>"; }};
\t\t{ids['unitGroup']} /* MyRussianTests */ = {{isa = PBXFileSystemSynchronizedRootGroup; path = MyRussianTests; sourceTree = "<group>"; }};
\t\t{ids['uiGroup']} /* MyRussianUITests */ = {{isa = PBXFileSystemSynchronizedRootGroup; path = MyRussianUITests; sourceTree = "<group>"; }};
\t\t{ids['widgetGroup']} /* MyRussianWidget */ = {{isa = PBXFileSystemSynchronizedRootGroup; path = MyRussianWidget; sourceTree = "<group>"; }};
/* End PBXFileSystemSynchronizedRootGroup section */

/* Begin PBXFrameworksBuildPhase section */
{phase('appFrameworks', 'PBXFrameworksBuildPhase', 'Frameworks', f"\t\t\t\t{ids['coreBuildFile']} /* MyRussianCore in Frameworks */,\n")}{phase('unitFrameworks', 'PBXFrameworksBuildPhase', 'Frameworks')}{phase('uiFrameworks', 'PBXFrameworksBuildPhase', 'Frameworks')}{phase('widgetFrameworks', 'PBXFrameworksBuildPhase', 'Frameworks', f"\t\t\t\t{ids['widgetCoreBuildFile']} /* MyRussianCore in Frameworks */,\n")}/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
\t\t{ids['mainGroup']} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{ids['appGroup']} /* MyRussian */,
\t\t\t\t{ids['widgetGroup']} /* MyRussianWidget */,
\t\t\t\t{ids['unitGroup']} /* MyRussianTests */,
\t\t\t\t{ids['uiGroup']} /* MyRussianUITests */,
\t\t\t\t{ids['productsGroup']} /* Products */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{ids['productsGroup']} /* Products */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{ids['appProduct']} /* MyRussian.app */,
\t\t\t\t{ids['widgetProduct']} /* MyRussianWidget.appex */,
\t\t\t\t{ids['unitProduct']} /* MyRussianTests.xctest */,
\t\t\t\t{ids['uiProduct']} /* MyRussianUITests.xctest */,
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
{target('appTarget', 'MyRussian', 'appConfigs', [('appSources', 'Sources'), ('appFrameworks', 'Frameworks'), ('appResources', 'Resources'), ('appEmbedExtensions', 'Embed Foundation Extensions')], 'appGroup', 'appProduct', 'com.apple.product-type.application', dependency=['widgetDependency'], packages=f"\t\t\t\t{ids['coreProduct']} /* MyRussianCore */,\n")}{target('widgetTarget', 'MyRussianWidget', 'widgetConfigs', [('widgetSources', 'Sources'), ('widgetFrameworks', 'Frameworks'), ('widgetResources', 'Resources')], 'widgetGroup', 'widgetProduct', 'com.apple.product-type.app-extension', packages=f"\t\t\t\t{ids['widgetCoreProduct']} /* MyRussianCore */,\n")}{target('unitTarget', 'MyRussianTests', 'unitConfigs', [('unitSources', 'Sources'), ('unitFrameworks', 'Frameworks'), ('unitResources', 'Resources')], 'unitGroup', 'unitProduct', 'com.apple.product-type.bundle.unit-test', dependency='unitDependency')}{target('uiTarget', 'MyRussianUITests', 'uiConfigs', [('uiSources', 'Sources'), ('uiFrameworks', 'Frameworks'), ('uiResources', 'Resources')], 'uiGroup', 'uiProduct', 'com.apple.product-type.bundle.ui-testing', dependency='uiDependency')}/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t{ids['project']} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 2600;
\t\t\t\tLastUpgradeCheck = 2600;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{ids['appTarget']} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 26.0;
\t\t\t\t\t}};
\t\t\t\t\t{ids['widgetTarget']} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 26.0;
\t\t\t\t\t}};
\t\t\t\t\t{ids['unitTarget']} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 26.0;
\t\t\t\t\t\tTestTargetID = {ids['appTarget']};
\t\t\t\t\t}};
\t\t\t\t\t{ids['uiTarget']} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 26.0;
\t\t\t\t\t\tTestTargetID = {ids['appTarget']};
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {ids['projectConfigs']} /* Build configuration list for PBXProject "MyRussian" */;
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {ids['mainGroup']};
\t\t\tminimizedProjectReferenceProxies = 1;
\t\t\tpackageReferences = (
\t\t\t\t{ids['corePackage']} /* XCLocalSwiftPackageReference "Packages/MyRussianCore" */,
\t\t\t);
\t\t\tpreferredProjectObjectVersion = 77;
\t\t\tproductRefGroup = {ids['productsGroup']} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{ids['appTarget']} /* MyRussian */,
\t\t\t\t{ids['widgetTarget']} /* MyRussianWidget */,
\t\t\t\t{ids['unitTarget']} /* MyRussianTests */,
\t\t\t\t{ids['uiTarget']} /* MyRussianUITests */,
\t\t\t);
\t\t}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
{phase('appResources', 'PBXResourcesBuildPhase', 'Resources')}{phase('unitResources', 'PBXResourcesBuildPhase', 'Resources')}{phase('uiResources', 'PBXResourcesBuildPhase', 'Resources')}{phase('widgetResources', 'PBXResourcesBuildPhase', 'Resources')}/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
{phase('appSources', 'PBXSourcesBuildPhase', 'Sources')}{phase('unitSources', 'PBXSourcesBuildPhase', 'Sources')}{phase('uiSources', 'PBXSourcesBuildPhase', 'Sources')}{phase('widgetSources', 'PBXSourcesBuildPhase', 'Sources')}/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
\t\t{ids['unitDependency']} /* PBXTargetDependency */ = {{
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = {ids['appTarget']} /* MyRussian */;
\t\t\ttargetProxy = {ids['unitProxy']} /* PBXContainerItemProxy */;
\t\t}};
\t\t{ids['uiDependency']} /* PBXTargetDependency */ = {{
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = {ids['appTarget']} /* MyRussian */;
\t\t\ttargetProxy = {ids['uiProxy']} /* PBXContainerItemProxy */;
\t\t}};
\t\t{ids['widgetDependency']} /* PBXTargetDependency */ = {{
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = {ids['widgetTarget']} /* MyRussianWidget */;
\t\t\ttargetProxy = {ids['widgetProxy']} /* PBXContainerItemProxy */;
\t\t}};
/* End PBXTargetDependency section */

/* Begin XCBuildConfiguration section */
{config('projectDebug', 'Debug', project_debug)}{config('projectRelease', 'Release', project_release)}{config('appDebug', 'Debug', app_settings)}{config('appRelease', 'Release', app_settings)}{config('unitDebug', 'Debug', unit_settings)}{config('unitRelease', 'Release', unit_settings)}{config('uiDebug', 'Debug', ui_settings)}{config('uiRelease', 'Release', ui_settings)}{config('widgetDebug', 'Debug', widget_settings)}{config('widgetRelease', 'Release', widget_settings)}/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
{config_list('projectConfigs', 'projectDebug', 'projectRelease', 'PBXProject "MyRussian"')}{config_list('appConfigs', 'appDebug', 'appRelease', 'PBXNativeTarget "MyRussian"')}{config_list('unitConfigs', 'unitDebug', 'unitRelease', 'PBXNativeTarget "MyRussianTests"')}{config_list('uiConfigs', 'uiDebug', 'uiRelease', 'PBXNativeTarget "MyRussianUITests"')}{config_list('widgetConfigs', 'widgetDebug', 'widgetRelease', 'PBXNativeTarget "MyRussianWidget"')}/* End XCConfigurationList section */

/* Begin XCLocalSwiftPackageReference section */
\t\t{ids['corePackage']} /* XCLocalSwiftPackageReference "Packages/MyRussianCore" */ = {{
\t\t\tisa = XCLocalSwiftPackageReference;
\t\t\trelativePath = Packages/MyRussianCore;
\t\t}};
/* End XCLocalSwiftPackageReference section */

/* Begin XCSwiftPackageProductDependency section */
\t\t{ids['coreProduct']} /* MyRussianCore */ = {{
\t\t\tisa = XCSwiftPackageProductDependency;
\t\t\tproductName = MyRussianCore;
\t\t}};
\t\t{ids['widgetCoreProduct']} /* MyRussianCore */ = {{
\t\t\tisa = XCSwiftPackageProductDependency;
\t\t\tproductName = MyRussianCore;
\t\t}};
/* End XCSwiftPackageProductDependency section */
\t}};
\trootObject = {ids['project']} /* Project object */;
}}
"""


def buildable(target_key, name, product):
    return f"""<BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{ids[target_key]}"
               BuildableName = "{product}"
               BlueprintName = "{name}"
               ReferencedContainer = "container:MyRussian.xcodeproj">
            </BuildableReference>"""


scheme = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "2600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            {buildable('appTarget', 'MyRussian', 'MyRussian.app')}
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES"
      shouldAutocreateTestPlan = "YES">
      <Testables>
         <TestableReference
            skipped = "NO"
            parallelizable = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "MyRussianCoreTests"
               BuildableName = "MyRussianCoreTests"
               BlueprintName = "MyRussianCoreTests"
               ReferencedContainer = "container:Packages/MyRussianCore">
            </BuildableReference>
         </TestableReference>
         <TestableReference
            skipped = "NO"
            parallelizable = "YES">
            {buildable('unitTarget', 'MyRussianTests', 'MyRussianTests.xctest')}
         </TestableReference>
         <TestableReference
            skipped = "NO"
            parallelizable = "NO">
            {buildable('uiTarget', 'MyRussianUITests', 'MyRussianUITests.xctest')}
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         {buildable('appTarget', 'MyRussian', 'MyRussian.app')}
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         {buildable('appTarget', 'MyRussian', 'MyRussian.app')}
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""

project_dir = ROOT / "MyRussian.xcodeproj"
(project_dir / "xcshareddata" / "xcschemes").mkdir(parents=True, exist_ok=True)
(project_dir / "project.pbxproj").write_text(pbxproj)
(project_dir / "xcshareddata" / "xcschemes" / "MyRussian.xcscheme").write_text(scheme)
print(f"Wrote {project_dir}")
