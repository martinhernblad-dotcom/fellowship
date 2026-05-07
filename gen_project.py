#!/usr/bin/env python3
"""Generates Ours.xcodeproj/project.pbxproj for a SwiftUI iOS app."""

import uuid, os

def uid():
    return uuid.uuid4().hex[:24].upper()

BASE = os.path.dirname(os.path.abspath(__file__))
XCPROJ = os.path.join(BASE, "Ours.xcodeproj")
os.makedirs(XCPROJ, exist_ok=True)

# ── UUIDs ──────────────────────────────────────────
P          = uid()  # PBXProject
MAIN_GRP   = uid()  # root group
OURS_GRP   = uid()  # Ours/ source group
MDL_GRP    = uid()  # Models/
SVC_GRP    = uid()  # Services/
VM_GRP     = uid()  # ViewModels/
VIEW_GRP   = uid()  # Views/
EXT_GRP    = uid()  # Extensions/
PROD_GRP   = uid()  # Products group
TARGET     = uid()  # PBXNativeTarget
APP_PROD   = uid()  # app product reference
BCL_PROJ   = uid()  # XCConfigurationList project
BCL_TGT    = uid()  # XCConfigurationList target
DBG_PROJ   = uid()  # Debug config project
REL_PROJ   = uid()  # Release config project
DBG_TGT    = uid()  # Debug config target
REL_TGT    = uid()  # Release config target
SRC_PHASE  = uid()  # PBXSourcesBuildPhase
FWK_PHASE  = uid()  # PBXFrameworksBuildPhase
RES_PHASE  = uid()  # PBXResourcesBuildPhase
ASSETS_REF = uid()  # Assets.xcassets file ref
ASSETS_BF  = uid()  # Assets.xcassets build file
ENTL_REF   = uid()  # Ours.entitlements file ref

# ── Source files ────────────────────────────────────
SOURCES = [
    ("OursApp.swift",             "Ours/OursApp.swift",             OURS_GRP),
    ("AppModels.swift",           "Ours/Models/AppModels.swift",    MDL_GRP),
    ("CloudKitService.swift",     "Ours/Services/CloudKitService.swift", SVC_GRP),
    ("AppViewModel.swift",        "Ours/ViewModels/AppViewModel.swift",  VM_GRP),
    ("HomeView.swift",            "Ours/Views/HomeView.swift",       VIEW_GRP),
    ("CategoryView.swift",        "Ours/Views/CategoryView.swift",   VIEW_GRP),
    ("SubcategoryView.swift",     "Ours/Views/SubcategoryView.swift",VIEW_GRP),
    ("AddSubcategorySheet.swift", "Ours/Views/AddSubcategorySheet.swift", VIEW_GRP),
    ("AddItemSheet.swift",        "Ours/Views/AddItemSheet.swift",   VIEW_GRP),
    ("ProfileSetupView.swift",    "Ours/Views/ProfileSetupView.swift",VIEW_GRP),
    ("Color+Hex.swift",           "Ours/Extensions/Color+Hex.swift", EXT_GRP),
]

frefs  = {name: uid() for name, _, _ in SOURCES}
bfiles = {name: uid() for name, _, _ in SOURCES}

# ── Build sections ──────────────────────────────────
def pbx_build_files():
    lines = []
    for name, path, _ in SOURCES:
        lines.append(f"\t\t{bfiles[name]} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {frefs[name]} /* {name} */; }};")
    lines.append(f"\t\t{ASSETS_BF} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {ASSETS_REF} /* Assets.xcassets */; }};")
    return "\n".join(lines)

def pbx_file_refs():
    lines = []
    for name, path, _ in SOURCES:
        lines.append(f"\t\t{frefs[name]} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = \"{name}\"; path = \"{path}\"; sourceTree = SOURCE_ROOT; }};")
    lines.append(f"\t\t{ASSETS_REF} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; name = Assets.xcassets; path = \"Ours/Assets.xcassets\"; sourceTree = SOURCE_ROOT; }};")
    lines.append(f"\t\t{ENTL_REF} /* Ours.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; name = \"Ours.entitlements\"; path = \"Ours/Ours.entitlements\"; sourceTree = SOURCE_ROOT; }};")
    lines.append(f"\t\t{APP_PROD} /* Ours.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Ours.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
    return "\n".join(lines)

def group_children(grp_id):
    """Return file refs whose group matches grp_id"""
    refs = [frefs[name] for name, _, g in SOURCES if g == grp_id]
    return refs

def pbx_groups():
    def grp(gid, name, path, children, source_tree="<group>"):
        child_str = "\n".join(f"\t\t\t\t{c}," for c in children)
        pt = f"path = \"{path}\";" if path else f"name = \"{name}\";"
        return f"""\t\t{gid} /* {name} */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{child_str}
\t\t\t);
\t\t\t{pt}
\t\t\tsourceTree = "{source_tree}";
\t\t}};"""

    models_grp    = grp(MDL_GRP,  "Models",     "Models",     group_children(MDL_GRP))
    services_grp  = grp(SVC_GRP,  "Services",   "Services",   group_children(SVC_GRP))
    vm_grp        = grp(VM_GRP,   "ViewModels", "ViewModels", group_children(VM_GRP))
    views_grp     = grp(VIEW_GRP, "Views",      "Views",      group_children(VIEW_GRP))
    ext_grp       = grp(EXT_GRP,  "Extensions", "Extensions", group_children(EXT_GRP))

    ours_children = ([frefs[name] for name, _, g in SOURCES if g == OURS_GRP]
                     + [MDL_GRP, SVC_GRP, VM_GRP, VIEW_GRP, EXT_GRP, ASSETS_REF, ENTL_REF])
    ours_grp = grp(OURS_GRP, "Ours", "Ours", ours_children)

    products_grp = grp(PROD_GRP, "Products", None, [APP_PROD])

    main_children = [OURS_GRP, PROD_GRP]
    main_grp = f"""\t\t{MAIN_GRP} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{OURS_GRP} /* Ours */,
\t\t\t\t{PROD_GRP} /* Products */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};"""

    return "\n".join([main_grp, ours_grp, models_grp, services_grp, vm_grp, views_grp, ext_grp, products_grp])

def pbx_sources_phase():
    files = "\n".join(f"\t\t\t\t{bfiles[name]} /* {name} in Sources */," for name, _, _ in SOURCES)
    return f"""\t\t{SRC_PHASE} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{files}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};"""

def pbx_resources_phase():
    return f"""\t\t{RES_PHASE} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{ASSETS_BF} /* Assets.xcassets in Resources */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};"""

def pbx_frameworks_phase():
    return f"""\t\t{FWK_PHASE} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};"""

# ── Build configurations ────────────────────────────
COMMON_DEBUG = """
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;
\t\t\t\tCLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
\t\t\t\tCLANG_WARN_BOOL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_COMMA = YES;
\t\t\t\tCLANG_WARN_CONSTANT_CONVERSION = YES;
\t\t\t\tCLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
\t\t\t\tCLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
\t\t\t\tCLANG_WARN_DOCUMENTATION_COMMENTS = YES;
\t\t\t\tCLANG_WARN_EMPTY_BODY = YES;
\t\t\t\tCLANG_WARN_ENUM_CONVERSION = YES;
\t\t\t\tCLANG_WARN_INFINITE_RECURSION = YES;
\t\t\t\tCLANG_WARN_INT_CONVERSION = YES;
\t\t\t\tCLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_OBJC_IMPLICIT_RETAIN_CYCLE = YES;
\t\t\t\tCLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
\t\t\t\tCLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
\t\t\t\tCLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
\t\t\t\tCLANG_WARN_STRICT_PROTOTYPES = YES;
\t\t\t\tCLANG_WARN_SUSPICIOUS_MOVE = YES;
\t\t\t\tCLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
\t\t\t\tCLANG_WARN_UNREACHABLE_CODE = YES;
\t\t\t\tCLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu11;
\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;
\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = ("DEBUG=1", "$(inherited)");
\t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;
\t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
\t\t\t\tGCC_WARN_UNDECLARED_SELECTOR = YES;
\t\t\t\tGCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
\t\t\t\tGCC_WARN_UNUSED_FUNCTION = YES;
\t\t\t\tGCC_WARN_UNUSED_VARIABLE = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
\t\t\t\tMTL_FAST_MATH = YES;
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";"""

COMMON_RELEASE = """
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;
\t\t\t\tCLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
\t\t\t\tCLANG_WARN_BOOL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_COMMA = YES;
\t\t\t\tCLANG_WARN_CONSTANT_CONVERSION = YES;
\t\t\t\tCLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
\t\t\t\tCLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
\t\t\t\tCLANG_WARN_DOCUMENTATION_COMMENTS = YES;
\t\t\t\tCLANG_WARN_EMPTY_BODY = YES;
\t\t\t\tCLANG_WARN_ENUM_CONVERSION = YES;
\t\t\t\tCLANG_WARN_INFINITE_RECURSION = YES;
\t\t\t\tCLANG_WARN_INT_CONVERSION = YES;
\t\t\t\tCLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_OBJC_IMPLICIT_RETAIN_CYCLE = YES;
\t\t\t\tCLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
\t\t\t\tCLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
\t\t\t\tCLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
\t\t\t\tCLANG_WARN_STRICT_PROTOTYPES = YES;
\t\t\t\tCLANG_WARN_SUSPICIOUS_MOVE = YES;
\t\t\t\tCLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
\t\t\t\tCLANG_WARN_UNREACHABLE_CODE = YES;
\t\t\t\tCLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
\t\t\t\tENABLE_NS_ASSERTIONS = NO;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu11;
\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
\t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;
\t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
\t\t\t\tGCC_WARN_UNDECLARED_SELECTOR = YES;
\t\t\t\tGCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
\t\t\t\tGCC_WARN_UNUSED_FUNCTION = YES;
\t\t\t\tGCC_WARN_UNUSED_VARIABLE = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tMTL_FAST_MATH = YES;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-O";
\t\t\t\tVALIDATE_PRODUCT = YES;"""

def xc_build_configs():
    tgt_debug = f"""\t\t{DBG_TGT} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSTCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = "Ours/Ours.entitlements";
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
\t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;
\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = UIInterfaceOrientationPortrait;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/Frameworks");
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "com.ours.app";
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = 1;
\t\t\t}};
\t\t\tname = Debug;
\t\t}};"""

    tgt_release = f"""\t\t{REL_TGT} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSTCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = "Ours/Ours.entitlements";
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
\t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;
\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = UIInterfaceOrientationPortrait;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/Frameworks");
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "com.ours.app";
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = 1;
\t\t\t}};
\t\t\tname = Release;
\t\t}};"""

    proj_debug = f"""\t\t{DBG_PROJ} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{{COMMON_DEBUG}
\t\t\t}};
\t\t\tname = Debug;
\t\t}};"""

    proj_release = f"""\t\t{REL_PROJ} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{{COMMON_RELEASE}
\t\t\t}};
\t\t\tname = Release;
\t\t}};"""

    return "\n".join([proj_debug, proj_release, tgt_debug, tgt_release])

def xc_config_lists():
    return f"""\t\t{BCL_PROJ} /* Build configuration list for PBXProject "Ours" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{DBG_PROJ} /* Debug */,
\t\t\t\t{REL_PROJ} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{BCL_TGT} /* Build configuration list for PBXNativeTarget "Ours" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{DBG_TGT} /* Debug */,
\t\t\t\t{REL_TGT} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};"""

def pbx_native_target():
    return f"""\t\t{TARGET} /* Ours */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {BCL_TGT} /* Build configuration list for PBXNativeTarget "Ours" */;
\t\t\tbuildPhases = (
\t\t\t\t{SRC_PHASE} /* Sources */,
\t\t\t\t{FWK_PHASE} /* Frameworks */,
\t\t\t\t{RES_PHASE} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = Ours;
\t\t\tproductName = Ours;
\t\t\tproductReference = {APP_PROD} /* Ours.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};"""

def pbx_project():
    return f"""\t\t{P} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1600;
\t\t\t\tLastUpgradeCheck = 1600;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{TARGET} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {BCL_PROJ} /* Build configuration list for PBXProject "Ours" */;
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {MAIN_GRP};
\t\t\tproductRefGroup = {PROD_GRP} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{TARGET} /* Ours */,
\t\t\t);
\t\t}};"""

# ── Assemble the full file ──────────────────────────
content = f"""// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{
\t}};
\tobjectVersion = 56;
\tobjects = {{

/* Begin PBXBuildFile section */
{pbx_build_files()}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{pbx_file_refs()}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
{pbx_frameworks_phase()}
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
{pbx_groups()}
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
{pbx_native_target()}
/* End PBXNativeTarget section */

/* Begin PBXProject section */
{pbx_project()}
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
{pbx_resources_phase()}
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
{pbx_sources_phase()}
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
{xc_build_configs()}
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
{xc_config_lists()}
/* End XCConfigurationList section */

\t}};
\trootObject = {P} /* Project object */;
}}
"""

out = os.path.join(XCPROJ, "project.pbxproj")
with open(out, "w") as f:
    f.write(content)

print(f"Written: {out}")
