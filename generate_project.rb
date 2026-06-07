require 'xcodeproj'

project_path = 'Aevium.xcodeproj'
app_dir = 'Aevium'
tests_dir = 'AeviumTests'
app_config_path = 'Aevium/Config/AppConfig.xcconfig'

compiled_source_extensions = %w[swift metal m mm c cc cpp].freeze

def file_paths(root, extensions)
  Dir.glob(File.join(root, '**', '*'))
    .select do |path|
      File.file?(path) && extensions.include?(File.extname(path).delete_prefix('.').downcase)
    end
    .sort
end

def apply_settings(build_configuration, settings)
  settings.each do |key, value|
    build_configuration.build_settings[key] = value
  end
end

project = Xcodeproj::Project.new(project_path)
project.instance_variable_set(:@object_version, 77)
project.root_object.compatibility_version = 'Xcode 16.0'
project.root_object.development_region = 'en'
project.root_object.has_scanned_for_encodings = '0'
project.root_object.known_regions = %w[en Base]
project.root_object.preferred_project_object_version = '77'
project.root_object.project_dir_path = ''
project.root_object.project_root = ''
project.root_object.attributes['LastSwiftUpdateCheck'] = '1600'
project.root_object.attributes['LastUpgradeCheck'] = '1600'

main_group = project.main_group
app_group = main_group.new_group('Aevium')
tests_group = main_group.new_group('AeviumTests')
config_group = app_group.new_group('Config')
app_config_ref = config_group.new_file(app_config_path)

source_files = file_paths(app_dir, compiled_source_extensions)
resource_files = Dir.glob(File.join(app_dir, 'Resources', '**', '*'))
                   .select { |path| File.file?(path) }
                   .sort
test_source_files = file_paths(tests_dir, %w[swift])
test_resource_files = Dir.glob(File.join(tests_dir, '**', '*'))
                        .select { |path| File.file?(path) && File.extname(path).downcase != '.swift' }
                        .sort

target = project.new_target(:application, 'Aevium', :osx, '14.0')
target.product_name = 'Aevium'

sparkle_package = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
sparkle_package.repositoryURL = 'https://github.com/sparkle-project/Sparkle'
sparkle_package.requirement = {
  'kind' => 'upToNextMajorVersion',
  'minimumVersion' => '2.9.2'
}
project.root_object.package_references << sparkle_package

sparkle_product = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
sparkle_product.package = sparkle_package
sparkle_product.product_name = 'Sparkle'
target.package_product_dependencies << sparkle_product

sparkle_build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
sparkle_build_file.product_ref = sparkle_product
target.frameworks_build_phase.files << sparkle_build_file

source_files.each do |path|
  file_ref = app_group.new_file(path)
  target.add_file_references([file_ref])
end

resource_files.each do |path|
  file_ref = app_group.new_file(path)
  target.resources_build_phase.add_file_reference(file_ref)
end

test_target = project.new_target(:unit_test_bundle, 'AeviumTests', :osx, '14.0')
test_target.product_name = 'AeviumTests'
test_target.add_dependency(target)

test_source_files.each do |path|
  file_ref = tests_group.new_file(path)
  test_target.add_file_references([file_ref])
end

test_resource_files.each do |path|
  file_ref = tests_group.new_file(path)
  test_target.resources_build_phase.add_file_reference(file_ref)
end

shared_project_settings = {
  'ALWAYS_SEARCH_USER_PATHS' => 'NO',
  'ASSETCATALOG_COMPILER_APPICON_NAME' => '',
  'CLANG_ANALYZER_NONNULL' => 'YES',
  'CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION' => 'YES_AGGRESSIVE',
  'CLANG_CXX_LANGUAGE_STANDARD' => 'gnu++14',
  'CLANG_CXX_LIBRARY' => 'libc++',
  'CLANG_ENABLE_MODULES' => 'YES',
  'CLANG_ENABLE_OBJC_ARC' => 'YES',
  'CLANG_ENABLE_OBJC_WEAK' => 'YES',
  'CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING' => 'YES',
  'CLANG_WARN_BOOL_CONVERSION' => 'YES',
  'CLANG_WARN_COMMA' => 'YES',
  'CLANG_WARN_CONSTANT_CONVERSION' => 'YES',
  'CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS' => 'YES',
  'CLANG_WARN_DIRECT_OBJC_ISA_USAGE' => 'YES_ERROR',
  'CLANG_WARN_DOCUMENTATION_COMMENTS' => 'YES',
  'CLANG_WARN_EMPTY_BODY' => 'YES',
  'CLANG_WARN_ENUM_CONVERSION' => 'YES',
  'CLANG_WARN_INFINITE_RECURSION' => 'YES',
  'CLANG_WARN_INT_CONVERSION' => 'YES',
  'CLANG_WARN_NON_LITERAL_NULL_CONVERSION' => 'YES',
  'CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF' => 'YES',
  'CLANG_WARN_OBJC_LITERAL_CONVERSION' => 'YES',
  'CLANG_WARN_OBJC_ROOT_CLASS' => 'YES_ERROR',
  'CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER' => 'YES',
  'CLANG_WARN_RANGE_LOOP_ANALYSIS' => 'YES',
  'CLANG_WARN_STRICT_PROTOTYPES' => 'YES',
  'CLANG_WARN_SUSPICIOUS_MOVE' => 'YES',
  'CLANG_WARN_UNGUARDED_AVAILABILITY' => 'YES_AGGRESSIVE',
  'CLANG_WARN_UNREACHABLE_CODE' => 'YES',
  'CLANG_WARN__DUPLICATE_METHOD_MATCH' => 'YES',
  'GCC_C_LANGUAGE_STANDARD' => 'gnu11',
  'GCC_NO_COMMON_BLOCKS' => 'YES',
  'GCC_WARN_64_TO_32_BIT_CONVERSION' => 'YES',
  'GCC_WARN_ABOUT_RETURN_TYPE' => 'YES_ERROR',
  'GCC_WARN_UNDECLARED_SELECTOR' => 'YES',
  'GCC_WARN_UNINITIALIZED_AUTOS' => 'YES_AGGRESSIVE',
  'GCC_WARN_UNUSED_FUNCTION' => 'YES',
  'GCC_WARN_UNUSED_VARIABLE' => 'YES',
  'CURRENT_PROJECT_VERSION' => '10',
  'GENERATE_INFOPLIST_FILE' => 'NO',
  'INFOPLIST_FILE' => 'Aevium/App/Info.plist',
  'MACOSX_DEPLOYMENT_TARGET' => '14.0',
  'MARKETING_VERSION' => '0.0.10',
  'MTL_FAST_MATH' => 'YES',
  'PRODUCT_BUNDLE_IDENTIFIER' => 'com.aevium.desktop',
  'PRODUCT_NAME' => '$(TARGET_NAME)',
  'SWIFT_VERSION' => '5.0',
  'VERSIONING_SYSTEM' => 'apple-generic'
}

project_debug_settings = shared_project_settings.merge(
  'COPY_PHASE_STRIP' => 'NO',
  'DEBUG_INFORMATION_FORMAT' => 'dwarf',
  'ENABLE_STRICT_OBJC_MSGSEND' => 'YES',
  'ENABLE_TESTABILITY' => 'YES',
  'GCC_DYNAMIC_NO_PIC' => 'NO',
  'GCC_OPTIMIZATION_LEVEL' => '0',
  'GCC_PREPROCESSOR_DEFINITIONS' => ['DEBUG=1', '$(inherited)'],
  'MTL_ENABLE_DEBUG_INFO' => 'INCLUDE_SOURCE',
  'ONLY_ACTIVE_ARCH' => 'YES',
  'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => 'DEBUG',
  'SWIFT_OPTIMIZATION_LEVEL' => '-Onone'
)

project_release_settings = shared_project_settings.merge(
  'COPY_PHASE_STRIP' => 'NO',
  'DEBUG_INFORMATION_FORMAT' => 'dwarf-with-dsym',
  'ENABLE_NS_ASSERTIONS' => 'NO',
  'ENABLE_STRICT_OBJC_MSGSEND' => 'YES',
  'MTL_ENABLE_DEBUG_INFO' => 'NO',
  'SWIFT_COMPILATION_MODE' => 'wholemodule',
  'SWIFT_OPTIMIZATION_LEVEL' => '-O'
)

target_debug_settings = {
  'ASSETCATALOG_COMPILER_APPICON_NAME' => 'AppIcon',
  'ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME' => 'AccentColor',
  'CODE_SIGNING_ALLOWED' => 'NO',
  'CODE_SIGNING_REQUIRED' => 'NO',
  'COMBINE_HIDPI_IMAGES' => 'YES',
  'ENABLE_HARDENED_RUNTIME' => 'NO',
  'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/../Frameworks',
  'MACOSX_DEPLOYMENT_TARGET' => '14.0',
  'PRODUCT_BUNDLE_IDENTIFIER' => 'com.aevium.desktop',
  'SDKROOT' => 'macosx',
  'SWIFT_EMIT_LOC_STRINGS' => 'YES',
  'SWIFT_VERSION' => '5.0'
}

target_release_settings = target_debug_settings.merge(
  'CODE_SIGNING_ALLOWED' => 'NO',
  'CODE_SIGNING_REQUIRED' => 'NO',
  'ENABLE_HARDENED_RUNTIME' => 'NO'
)

test_target_settings = {
  'BUNDLE_LOADER' => '$(TEST_HOST)',
  'CODE_SIGNING_ALLOWED' => 'NO',
  'CODE_SIGNING_REQUIRED' => 'NO',
  'GENERATE_INFOPLIST_FILE' => 'YES',
  'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/../Frameworks @loader_path/../Frameworks @executable_path/../PlugIns',
  'MACOSX_DEPLOYMENT_TARGET' => '14.0',
  'PRODUCT_BUNDLE_IDENTIFIER' => 'com.aevium.desktop.tests',
  'SDKROOT' => 'macosx',
  'SWIFT_VERSION' => '5.0',
  'TEST_HOST' => '$(BUILT_PRODUCTS_DIR)/Aevium.app/Contents/MacOS/Aevium'
}

project.build_configurations.each do |config|
  case config.name
  when 'Debug'
    apply_settings(config, project_debug_settings)
  when 'Release'
    apply_settings(config, project_release_settings)
  end
end

target.build_configurations.each do |config|
  config.base_configuration_reference = app_config_ref
  case config.name
  when 'Debug'
    apply_settings(config, target_debug_settings)
  when 'Release'
    apply_settings(config, target_release_settings)
  end
end

test_target.build_configurations.each do |config|
  apply_settings(config, test_target_settings)
end

scheme = Xcodeproj::XCScheme.new
scheme.set_launch_target(target)
scheme.add_build_target(target)
scheme.add_test_target(test_target)
scheme.save_as(project_path, 'Aevium', true)

project.save
