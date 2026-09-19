#!/usr/bin/env ruby
# Nur bei Änderungen an Dateistruktur/Targets ausführen. Benötigt xcodeproj 1.27.0.
require 'xcodeproj'
root = File.expand_path('..', __dir__)
project = Xcodeproj::Project.new(File.join(root, 'Beratungstrainer.xcodeproj'))
target = project.new_target(:application, 'Beratungstrainer', :ios, '27.0')
# Swift importiert Apple-Frameworks automatisch. Keine vom Generator vorgegebene,
# versionsgebundene iPhoneOS-Frameworkreferenz in das plattformübergreifende Target übernehmen.
target.frameworks_build_phase.files.to_a.each(&:remove_from_project)
project.frameworks_group.files.to_a.each(&:remove_from_project)
sources = project.main_group.new_group('Beratungstrainer', 'Beratungstrainer')
Dir.glob(File.join(root, 'Beratungstrainer/**/*.swift')).sort.each do |path|
  ref = sources.new_file(path.delete_prefix(File.join(root, 'Beratungstrainer/')))
  target.source_build_phase.add_file_reference(ref)
end
Dir.glob(File.join(root, 'Beratungstrainer/Resources/**/*')).select { |path| File.file?(path) }.sort.each do |path|
  ref = sources.new_file(path.delete_prefix(File.join(root, 'Beratungstrainer/')))
  target.resources_build_phase.add_file_reference(ref)
end
%w[TrainerCore TrainerStorage].each do |name|
  package = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
  package.relative_path = "Packages/#{name}"
  project.root_object.package_references << package
  product = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  product.package = package
  product.product_name = name
  target.package_product_dependencies << product
  build = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build.product_ref = product
  target.frameworks_build_phase.files << build
end
project.build_configurations.each do |config|
  config.build_settings['SWIFT_VERSION'] = '6.0'
  config.build_settings['CLANG_ENABLE_MODULES'] = 'YES'
  config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'YES'
end
target.build_configurations.each do |config|
  settings = config.build_settings
  settings['SWIFT_VERSION'] = '6.0'
  settings['SWIFT_STRICT_CONCURRENCY'] = 'complete'
  settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'de.rogersrodeo.beratungstrainer'
  settings['INFOPLIST_KEY_CFBundleDisplayName'] = 'Rogers Rodeo'
  settings['INFOPLIST_KEY_LSApplicationCategoryType'] = 'public.app-category.education'
  settings['INFOPLIST_KEY_UIApplicationSceneManifest_Generation'] = 'YES'
  settings['INFOPLIST_KEY_UILaunchScreen_Generation'] = 'YES'
  settings['INFOPLIST_KEY_UISupportedInterfaceOrientations'] = 'UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight'
  settings['MARKETING_VERSION'] = '0.1.0'
  settings['CURRENT_PROJECT_VERSION'] = '1'
  settings['SUPPORTED_PLATFORMS'] = 'iphoneos iphonesimulator macosx'
  settings['MACOSX_DEPLOYMENT_TARGET'] = '15.0'
  settings['TARGETED_DEVICE_FAMILY'] = '1'
  settings['SUPPORTS_MACCATALYST'] = 'NO'
  settings['CODE_SIGN_STYLE'] = 'Automatic'
  settings['ENABLE_APP_SANDBOX'] = 'YES'
  settings['ENABLE_USER_SELECTED_FILES'] = 'readwrite'
  settings['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../Frameworks']
  if config.name == 'Debug'
    settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG $(inherited)'
  end
end
project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(target)
scheme.set_launch_target(target)
scheme.save_as(project.path, 'Beratungstrainer', true)
puts 'Beratungstrainer.xcodeproj erzeugt'
