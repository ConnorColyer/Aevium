require 'xcodeproj'

project_path = 'Aevium.xcodeproj'
app_dir = 'Aevium'
tests_dir = 'AeviumTests'

project = Xcodeproj::Project.new(project_path)
project.root_object.compatibility_version = 'Xcode 16.0'

main_group = project.main_group
app_group = main_group.new_group('Aevium')
tests_group = main_group.new_group('AeviumTests')

source_files = Dir.glob(File.join(app_dir, '**', '*.swift')).sort
resource_files = Dir.glob(File.join(app_dir, 'Resources', '*')).sort
test_source_files = Dir.glob(File.join(tests_dir, '**', '*.swift')).sort
test_resource_files = Dir.glob(File.join(tests_dir, '**', '*')).reject { |path| File.directory?(path) || path.end_with?('.swift') }.sort

target = project.new_target(:application, 'Aevium', :osx, '14.0')
target.product_name = 'Aevium'

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

project.build_configurations.each do |config|
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.aevium.desktop'
  config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
  config.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['INFOPLIST_KEY_NSHumanReadableCopyright'] = 'Aevium'
  config.build_settings['INFOPLIST_KEY_CFBundleDisplayName'] = 'Aevium'
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = ''
end

target.build_configurations.each do |config|
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.aevium.desktop'
  config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
  config.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['SWIFT_EMIT_LOC_STRINGS'] = 'YES'
end

test_target.build_configurations.each do |config|
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.aevium.desktop.tests'
  config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
  config.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/Aevium.app/Contents/MacOS/Aevium'
  config.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/../Frameworks @loader_path/../Frameworks @executable_path/../PlugIns'
end

# Create a shared launchable scheme.
scheme = Xcodeproj::XCScheme.new
scheme.set_launch_target(target)
scheme.add_build_target(target)
scheme.add_test_target(test_target)
scheme.save_as(project_path, 'Aevium', true)

project.save
