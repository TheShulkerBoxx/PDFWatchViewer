#!/usr/bin/env ruby
require 'xcodeproj'
require 'fileutils'

project_path = 'PDFWatchViewer.xcodeproj'
FileUtils.rm_rf(project_path) if File.exist?(project_path)

project = Xcodeproj::Project.new(project_path)

# Create iOS App target
ios_target = project.new_target(:application, 'PDFWatchViewer', :ios, '17.0')

# Create watchOS App target - use :application for modern watchOS apps
watch_target = project.new_target(:application, 'PDFWatchViewer Watch App', :watchos, '10.0')

# iOS source group - files are at PDFWatchViewer/filename.swift
ios_group = project.main_group.new_group('PDFWatchViewer', 'PDFWatchViewer')
ios_sources = [
  'PDFWatchViewerApp.swift',
  'ContentView.swift',
  'PDFDocumentManager.swift',
  'WatchConnectivityManager.swift'
]

ios_sources.each do |file|
  file_ref = ios_group.new_file(file)
  ios_target.add_file_references([file_ref])
end

# iOS Assets - path is PDFWatchViewer/Assets.xcassets
ios_assets = ios_group.new_file('Assets.xcassets')
ios_target.add_resources([ios_assets])

# iOS Info.plist
ios_group.new_file('Info.plist')

# watchOS source group - files are at "PDFWatchViewer Watch App/filename.swift"
watch_group = project.main_group.new_group('PDFWatchViewer Watch App', 'PDFWatchViewer Watch App')
watch_sources = [
  'PDFWatchViewerApp.swift',
  'ContentView.swift',
  'PDFViewerView.swift',
  'WatchConnectivityManager.swift'
]

watch_sources.each do |file|
  file_ref = watch_group.new_file(file)
  watch_target.add_file_references([file_ref])
end

# watchOS Assets - path is "PDFWatchViewer Watch App/Assets.xcassets"
watch_assets = watch_group.new_file('Assets.xcassets')
watch_target.add_resources([watch_assets])

# watchOS Info.plist
watch_group.new_file('Info.plist')

# Configure iOS target build settings
ios_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.pdfwatchviewer.ios'
  config.build_settings['INFOPLIST_FILE'] = 'PDFWatchViewer/Info.plist'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['CODE_SIGN_IDENTITY'] = 'Apple Development'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
  config.build_settings['MARKETING_VERSION'] = '1.0'
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  config.build_settings['ENABLE_PREVIEWS'] = 'YES'
  config.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
end

# Configure watchOS target build settings
watch_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.pdfwatchviewer.ios.watchkitapp'
  config.build_settings['INFOPLIST_FILE'] = 'PDFWatchViewer Watch App/Info.plist'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['CODE_SIGN_IDENTITY'] = 'Apple Development'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['WATCHOS_DEPLOYMENT_TARGET'] = '10.0'
  config.build_settings['SDKROOT'] = 'watchos'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
  config.build_settings['MARKETING_VERSION'] = '1.0'
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  config.build_settings['ENABLE_PREVIEWS'] = 'YES'
  config.build_settings['SKIP_INSTALL'] = 'YES'
  config.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '4' # Watch
end

# Add dependency - iOS embeds watchOS app
ios_target.add_dependency(watch_target)

# Add embed watch content build phase
embed_phase = ios_target.new_copy_files_build_phase('Embed Watch Content')
embed_phase.dst_subfolder_spec = '16' # Watch content
embed_phase.add_file_reference(watch_target.product_reference)

project.save

puts "Project created successfully at #{project_path}"
