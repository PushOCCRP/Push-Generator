# Push Generator - v1.0
# ©Christopher Guess/ICFJ 2016 
require 'optparse'
require 'pp'
require 'byebug'
require 'yaml'
require 'erb'
require 'fileutils'
require 'find'
require 'mini_magick'
require 'pp'
require 'colorize'

Options = Struct.new(:file_name, :production, :snapshot, :beta, :mode, :android_path, :ios_path, :offline)

class Parser
  def self.parse(options)
    args = Options.new(options)

    opt_parser = OptionParser.new do |opts|
      opts.banner = "Usage: example.rb [options]"

      opts.on("-fFILE", "--file=FILE", "File name for settings") do |n|
        args.file_name = n
      end

      opts.on("-p", "--production", "Flag for production push") do
      	args.production = true
      end

      opts.on("-s", "--snapshot", "Flag for only making screenshots") do
      	args.snapshot = true
      end

      opts.on("-b", "--beta", "Flag for beta push") do
      	args.beta = true
      end

      opts.on("-o", "--offline", "Flag for testing when offline, supercedes beta/production flags") do
      	args.offline = true
      end

      opts.on("-mMODE", "--mode=mode", "Flag for Android (android) or iOS (ios), e.g. -m android") do |n|
      	args.mode = n
      end

      opts.on("-aANDROID_PATH", "--android-path=android_path", "Path to Android base app, if not passed the user will be prompted during the build") do |n|
      	args.android_path = n
      end

      opts.on("-iIOS_PATH", "--ios-path=ios_path", "Path to iOS base app, if not passed the user will be prompted during the build") do |n|
      	args.ios_path = n
      end


      opts.on("-h", "--help", "Prints this help") do
        puts opts
        exit
      end
    end

    opt_parser.parse!(options)
    return args
  end
end

class Generator

	def self.generate options, version_number, build_number, mode
		#1.) Check if there's a file indicated in the call - DONE
		#2.) If there's not a file, look for push-mobile.haml - DONE
		file_content = load_file(options[:file_name], 'push-mobile.yml')
		if(file_content.nil?)
			return
		end
		#3.) Load and parse file - DONE
		settings = parse_yaml_content(file_content)

		credentials_content = load_file(settings['credentials-file'], 'push-mobile-credentials.yml')
		credentials = parse_yaml_content(credentials_content)
		#4.) Check format
		settings = verify_settings_format settings
		credentials = verify_credentials_format credentials
		if(credentials.nil?)
			return
		end

		settings[:credentials] = credentials
		settings[:build_number] = build_number
		settings[:version_number] = version_number
#		pp settings
		#5.) Parse file into iOS format
		case mode
		when :iOS
			generateiOSSettingsFile settings
		when :android
			generateAndroidSettingsFile settings
		end


		return settings

		#pp generateiOSSettingsFile settings
		#6.) Parse file into Android format
		#8.) Run Fastlane for iOS
		#9.) Run Fastlane for Android
		#10.) Success!!!
	end

	def self.load_file file_name, default_name
		if(file_name.nil? || file_name.empty?)
			file_name = default_name
		end

		if(File.file?(file_name) == false)
			pp "Missing file named #{file_name} to parse."
			return nil
		else
			content = ""
			File.open(file_name, "r") do |f|
			  f.each_line do |line|
		      	content += line
		  	  end
			end		
			return content
		end
	end

	def self.copy_file start_location, end_location
		error = nil
		if(start_location.nil? || start_location.empty?)
			error = "Start location cannot be empty"
		elsif(start_location.nil? || start_location.empty?)
			error = "Start location cannot be empty"
		elsif(File.file?(start_location) == false)
			error = "No file named #{start_location} found to copy"
		end
		
		if(!error.nil?)
			pp error
			return
		end

		FileUtils.cp(start_location, end_location)
	end

	def self.parse_yaml_content content
		return YAML.load(content)
	end

	def self.verify_settings_format settings
=begin
		Proper format:

		{"name"=>"Publisher's Test",
		 "short-name"=>"PubTest",
		 "languages"=>["en", "ro", "ru"],
		 "default-langauage"=>"en",
		 "icon-large"=>"icon-large.png",
		 "icon-small"=>"icon-small.png",
		 "icon-background-color"=>"#000000",
		 "launch-background-color"=>"#454545",
		 "navigation-bar-color"=>"#454545",
		 "navigation-text-color"=>"#000000",
		 "credentials-file"=>"creds.yml"}
=end
		settings_to_verify = ['name', 'short-name', 'ios-bundle-identifier', 'languages', 'icon-large', 'icon-navigation-bar', 'navigation-bar-color', 'navigation-text-color']
		settings_to_verify.each do |setting|
			self.check_for_setting(setting, settings)
		end

		# Make sure the languages is set up correctly etc.
		if(settings['languages'].size == 0)
			raise "More than one language must be included in the 'languages' array"
		end

		# If the default language is not in the languages array throw an error
		# If there is no default language, set the first in the list to it
		if(settings.has_key?('default-language'))
			default_language = settings['default-language']
			if(settings['languages'].include?(default_language) == false)
				raise "'default-language' must be included in 'language' array"
			end
		else
			settings['default-language'] = settings['languages'].first
			pp settings['languages']
		end

		if(settings.has_key?('icon-background-color') == false)
			settings['icon-background-color'] = '#FFFFFFF'
		end

		if(settings.has_key?('launch-background-color') == false)
			settings['launch-background-color'] = '#FFFFFFF'
		end

		if(settings.has_key?('credentials-file') == false)
			settings['credentials-file'] = 'push-mobile-credentials.yml'
		end

		return settings
	end

	def self.verify_credentials_format credentials
		settings_to_verify = ['server-url', 'origin-url', 'hockey-key', 'hockey-secret', 'infobip-application-id', 'infobip-application-secret', 'play-store-app-number', 'fabric-key']
		settings_to_verify.each do |setting|
			self.check_for_setting(setting, credentials)
		end

		return credentials
=begin
		{"server-url"=>"https://push-occrp.herokuapp.com",
		 "origin-url"=>"https://www.occrp.org",
		 "hockey-key"=>"xxxxxxxxxxxxxxxxxxx",
		 "infobip-application-id"=>"xxxxxxxxxx",
		 "infobip-application-secret"=>"xxxxxxxxxxxxx",
		 "play-store-app-number"=>"xxxxxxxxxxxxxxxxx",
		 "youtube-access-key"=>"xxxxxxxxxxxxxxxxx"}
=end
	end

	def self.check_for_setting setting_name, settings
		if(settings.has_key?(setting_name) == false)
			raise "No '#{setting_name}' key found in settings"
		end

		if(settings[setting_name].nil? || settings[setting_name].empty?)
			raise "'#{setting_name}' in settings file not properly formatted."
		end

		return true
	end

	def self.generateiOSSettingsFile settings
		template = self.loadTemplate('iOS-Security')
		rendered_template = self.generateSettingsFile settings, template
		saveFile 'ios/SecretKeys.plist', rendered_template

		template = self.loadTemplate('iOS-Settings')
		rendered_template = self.generateSettingsFile settings, template
		saveFile 'ios/CustomizedSettings.plist', rendered_template

		template = self.loadTemplate('iOS-Info')
		rendered_template = self.generateSettingsFile settings, template
		saveFile 'ios/Info.plist', rendered_template

		template = self.loadTemplate('iOS-PBX')
		rendered_template = self.generateSettingsFile settings, template
		saveFile 'ios/project.pbxproj', rendered_template

		template = self.loadTemplate('iOS-Fastfile')
		rendered_template = self.generateSettingsFile settings, template
		saveFile 'ios/Fastfile', rendered_template

		template = self.loadTemplate('iOS-Appfile')
		rendered_template = self.generateSettingsFile settings, template
		saveFile 'ios/Appfile', rendered_template

		template = self.loadTemplate('iOS-Snapfile')
		rendered_template = self.generateSettingsFile settings, template
		saveFile 'ios/Snapfile', rendered_template

	end

	def self.generateAndroidSettingsFile settings
		template = self.loadTemplate('Android-Safe-Variables')
		rendered_template = self.generateSettingsFile settings, template
		saveFile 'android/safe_variables.gradle', rendered_template

		template = self.loadTemplate('Android-Colors')
		rendered_template = self.generateSettingsFile settings, template
		saveFile 'android/colors.xml', rendered_template

		template = self.loadTemplate('Android-Manifest')
		rendered_template = self.generateSettingsFile settings, template
		saveFile 'android/AndroidManifest.xml', rendered_template

		template = self.loadTemplate('Android-Manifest-Debug')
		rendered_template = self.generateSettingsFile settings, template
		saveFile 'android/AndroidManifestDebug.xml', rendered_template

		template = self.loadTemplate('Android-Build-Gradle')
		rendered_template = self.generateSettingsFile settings, template
		saveFile 'android/build.gradle', rendered_template

		template = self.loadTemplate('Android-Screengrabfile')
		rendered_template = self.generateSettingsFile settings, template
		saveFile 'android/Screengrabfile', rendered_template

	end


	def self.generateSettingsFile settings, template
		b = binding
		b.local_variable_set :setting, settings
		@rendered
    	ERB.new(template, nil, '%<>-', "@rendered").result(b)
    	
    	return @rendered
	end

	def self.loadTemplate type
		content = nil
		case type
			when 'iOS-Security'
				content = self.load_file('templates/ios/ios_secrets_template.erb', 'templates/ios/ios_secrets_template.erb')
			when 'iOS-Settings'
				content = self.load_file('templates/ios/ios_settings_template.erb', 'templates/ios/ios_settings_template.erb')
			when 'iOS-Info'
				content = self.load_file('templates/ios/ios_info_template.erb', 'templates/ios/ios_info_template.erb')
			when 'iOS-PBX'
				content = self.load_file('templates/ios/ios_project_pbxproj.erb', 'templates/ios/ios_project_pbxproj.erb')
			when 'iOS-Fastfile'
				content = self.load_file('templates/ios/ios_fastfile_template.erb', 'templates/ios/ios_fastfile_template.erb')
			when 'iOS-Appfile'
				content = self.load_file('templates/ios/ios_appfile_template.erb', 'templates/ios/ios_appfile_template.erb')
			when 'iOS-Snapfile'
				content = self.load_file('templates/ios/ios_snapfile_template.erb', 'templates/ios/ios_snapfile_template.erb')

			when 'Android-Safe-Variables'
				content = self.load_file('templates/android/android_safe_variable_gradle_template.erb', 'templates/android/android_safe_variable_gradle_template.erb')
			when 'Android-Colors'
				content = self.load_file('templates/android/android_colors_xml.erb', 'templates/android/android_colors_xml.erb')
			when 'Android-Manifest'
				content = self.load_file('templates/android/android_manifest_xml.erb', 'templates/android/android_manifest_xml.erb')
			when 'Android-Manifest-Debug'
				content = self.load_file('templates/android/android_manifest_debug_xml.erb', 'templates/android/android_manifest_debug_xml.erb')
				when 'Android-Build-Gradle'
				content = self.load_file('templates/android/android_build_gradle.erb', 'templates/android/android_build_gradle.erb')
			when 'Android-Screengrabfile'
				content = self.load_file('templates/android/android_screengrabfile.erb', 'templates/android/android_build_gradle.erb')
		end

		return content
	end

	def self.saveFile file_name, content
		if(File.exist?(file_name))
			File.delete(file_name)
		end

		File.open(file_name, 'w') do |file|
			file.puts(content)
		end
	end

	def self.setAndroidTitle settings, root_path
		#Set the name of the app in all relevant language files
		folders = ["values"]
		settings['languages'].each do |language|
			if(language != "en")
				folders << "values-" + language
			end
		end
	
		folders.each do |folder|
			path = root_path + "/app/src/main/res/" + folder + "/strings.xml"
			text = File.read(path)
			replaced_text = text.gsub /<string name=\"app_name\">[A-z\s]*<\/string>/, "<string name=\"app_name\">#{settings['name']}<\/string>"
			tmp_file_path = 'templates/android/strings/' + folder + '_strings.xml'
			File.write(tmp_file_path, replaced_text)
			FileUtils.cp(tmp_file_path, path)
		end
	end
end

class ImageProcessor
	def self.process_ios_logo image_name, final_location
		image_sizes = {
		 ["images/images-generated/ios/app-store-icon.png"] => "1024x1024",
 		 ["images/images-generated/ios/launch-screen-logo@3x.png"] => "708x708",
 		 ["images/images-generated/ios/icon@3x.png","images/images-generated/ios/icon@3x-1.png"] => "540x540",
 		 ["images/images-generated/ios/logo-512.png"] => "512x512",
 		 ["images/images-generated/ios/icon@2x.png","images/images-generated/ios/icon@2x-1.png","images/images-generated/ios/icon@2x-2.png","images/images-generated/ios/icon@2x-3.png","images/images-generated/ios/icon@2x-4.png","images/images-generated/ios/icon@2x-5.png","images/images-generated/ios/icon@2x-6.png"] => "360x360",
 		 ["images/images-generated/ios/icon 167x167.png", "images/images-generated/ios/icon 167x167-1.png", "images/images-generated/ios/icon 167x167-2.png"] => "167x167",
 		 ["images/images-generated/ios/icon 152x152.png"] => "152x152",
 		 ["images/images-generated/ios/icon 120x120.png"] => "120x120",
 		 ["images/images-generated/ios/icon@1x.png", "images/images-generated/ios/icon@1x-1.png", "images/images-generated/ios/icon@1x-2.png"] => "76x76",
		}
		process image_sizes, image_name, final_location
	end

	def self.process_ios_header_icon image_name, final_location
		image_sizes = {
 		 ["images/images-generated/ios/logo@3x.png"] => "132x500",
 		 ["images/images-generated/ios/logo@2x.png"] => "88x500",
 		 ["images/images-generated/ios/logo@1x.png"] => "44x500",
		}
		process image_sizes, image_name, final_location
	end

	def self.process_android_logo image_name, final_location
		xxhdpi_image_sizes = {
		 ["images/images-generated/android/ic_launcher.png"] => "144x144",
		}

		xhdpi_image_sizes = {
			["images/images-generated/android/ic_launcher.png"] => "96x96",
		}

		hdpi_image_sizes = {
			["images/images-generated/android/ic_launcher.png"] => "72x72",
		}
		mdpi_image_sizes = {
			["images/images-generated/android/ic_launcher.png"] => "48x48",
		}

		process xxhdpi_image_sizes, image_name, (final_location + "/mipmap-xxhdpi")
		process xhdpi_image_sizes, image_name, (final_location + "/mipmap-xhdpi")
		process hdpi_image_sizes, image_name, (final_location + "/mipmap-hdpi")
		process mdpi_image_sizes, image_name, (final_location + "/mipmap-mdpi")
	end

	def self.process_android_header_icon image_name, final_location
		xxhdpi_image_sizes = {
		 ["images/images-generated/android/logo.png"] => "300x500",
		}

		xhdpi_image_sizes = {
			["images/images-generated/android/logo.png"] => "250x500",
		}

		hdpi_image_sizes = {
			["images/images-generated/android/logo.png"] => "200x500",
		}
		mdpi_image_sizes = {
			["images/images-generated/android/logo.png"] => "150x500",
		}

		process xxhdpi_image_sizes, image_name, (final_location + "/mipmap-xxhdpi")
		process xhdpi_image_sizes, image_name, (final_location + "/mipmap-xhdpi")
		process hdpi_image_sizes, image_name, (final_location + "/mipmap-hdpi")
		process mdpi_image_sizes, image_name, (final_location + "/mipmap-mdpi")
	end


	def self.process image_sizes, image_name, final_location
		image = MiniMagick::Image.open("images/#{image_name}")

		image_sizes.keys.each do |key|
			key.each do |file_name|
				image.resize image_sizes[key]
				image.format "png"
				image.write file_name
				FileUtils.cp(file_name, final_location)
			end
		end
	end

	#Takes hex
	def self.generateSolidColor color, file_name
		MiniMagick::Tool::Convert.new do |convert|
		  convert.merge! ["-size", "1200x1200", "xc:#{color}"]
		  convert << file_name
		end		
	end
end

def prompt(*args)
    print(*args)
    gets
end

def generateIOS options
	version_number = "1.0"
	build_number = "1"

	if(options[:production] == true || options[:beta] == true)
		version_number = prompt "iOS Version number: "
		build_number = prompt "iOS Build number: "
	end

	settings = Generator.generate options, version_number.strip!, build_number.strip!, :iOS

	if(options[:ios_path].empty?)
		p "Current path is: #{Dir.pwd}"
		project_path = prompt "iOS Project Path: "
		project_path.strip!
	else
		project_path = options[:ios_path]
		p "iOS build path is #{project_path}"
	end

	if(File.exist?(project_path) == false)
		p "iOS build path directory not found."
		abort
	end

	keys_final_location = project_path + "/" + "Push"
	FileUtils.cp("./ios/SecretKeys.plist", keys_final_location)
	FileUtils.cp("./ios/CustomizedSettings.plist", keys_final_location)
	FileUtils.cp("./ios/Info.plist", keys_final_location)
	FileUtils.cp("./ios/project.pbxproj", project_path + "/Push.xcodeproj")
	FileUtils.cp("./ios/Fastfile", project_path + "/fastlane")
	FileUtils.cp("./ios/Appfile", project_path + "/fastlane")
	FileUtils.cp("./ios/Snapfile", project_path + "/fastlane")

	ImageProcessor.process_ios_logo settings['icon-large'], project_path + "/Push/Assets.xcassets/AppIcon.appiconset"
	ImageProcessor.process_ios_logo settings['icon-large'], project_path + "/Push"
	ImageProcessor.process_ios_header_icon settings['icon-navigation-bar'], project_path + "/Push"

	solid_color_image = "images/images-generated/launch-background-color@3x.png"
	ImageProcessor.generateSolidColor settings['launch-background-color'], solid_color_image
	FileUtils.cp(solid_color_image, project_path + "/Push")

	suffix = ""
	if(settings['suffix'].nil? == false && settings['suffix'].empty? == false)
		suffix = "-#{settings['suffix']}"
	end

	settings['languages'].each do |language|
		FileUtils.cp("about-html/about_text-#{language}#{suffix}.html", project_path + "/Push/" + "about_text-#{language}.html")
	end

	file_suffix = nil
	Dir.chdir(project_path) do
		if(options[:snapshot] == true)
			p system('snapshot')
			break
		end
		lane = nil

		if(options[:offline] == true)
			lane = "ios offline"
			file_suffix = "offline"
		elsif(options[:production] == true)
			lane = "ios deploy"
			file_suffix = "prod"
		elsif(options[:beta] == true)
			build_notes = prompt "Build notes?: "
			lane = "ios beta notes:#{build_notes}"
			file_suffix = "beta"
		else
			lane = "ios gen_test"
			file_suffix = "beta"
		end

		p system("fastlane #{lane}")
	end

	Generator.copy_file(project_path + "/Push.ipa", "#{Dir.pwd}/finals/ios/#{binaryName(settings, file_suffix)}.ipa")
end

def generateAndroid options
	version_number = "1.0"
	build_number = "1"

	if(options[:production] == true || options[:beta] == true)
		version_number = prompt "Android Version number: "
		build_number = prompt "Android Build number: "
	end

	settings = Generator.generate options, version_number.strip!, build_number.strip!, :android

	if(options[:android_path].empty?)
		p "Current path is: #{Dir.pwd}"
		project_path = prompt "Android Project Path: "
		project_path.strip!
	else
		project_path = options[:android_path]
		p "Android build path is #{project_path}"
	end

	if(File.exist?(project_path) == false)
		p "Android base project directory not found."
		abort
	end

	Generator.setAndroidTitle settings, project_path

	keys_final_location = project_path + "/" + "app"
	FileUtils.cp("./android/safe_variables.gradle", keys_final_location)
	FileUtils.cp("./android/colors.xml", keys_final_location + "/src/main/res/values/")
	FileUtils.cp("./android/AndroidManifest.xml", keys_final_location + "/src/main/")
	FileUtils.cp("./android/AndroidManifestDebug.xml", keys_final_location + "/src/debug/AndroidManifest.xml")
	FileUtils.cp("./android/build.gradle", keys_final_location)
	FileUtils.cp("./android/Screengrabfile", keys_final_location + "/fastlane")

	ImageProcessor.process_android_logo settings['icon-large'], project_path + "/app/src/main/res"
	ImageProcessor.process_android_header_icon settings['icon-navigation-bar'], project_path + "/app/src/main/res"

=begin
	solid_color_image = "images/images-generated/launch-background-color@3x.png"
	ImageProcessor.generateSolidColor settings['launch-background-color'], solid_color_image
	FileUtils.cp(solid_color_image, project_path + "/Push")
=end

	suffix = ""
	if(settings['suffix'].nil? == false && settings['suffix'].empty? == false)
		suffix = "-#{settings['suffix']}"
	end

	settings['languages'].each do |language|
		FileUtils.cp("about-html/about_text-#{language}#{suffix}.html", project_path + "/app/src/main/assets/" + "about_text-#{language}.html")
	end

	#requires https://github.com/PushOCCRP/android-rename-package
	p "Changing Android package name to #{settings['android-bundle-identifier']}"

	renameAndroidImports project_path, settings['android-bundle-identifier']
	#p exec("rp r #{project_path} --package-name #{settings['android-bundle-identifier']}")
	renameAndroidPackageFolders 'main', settings['android-bundle-identifier'], project_path
	renameAndroidPackageFolders 'test', settings['android-bundle-identifier'], project_path

	#if(options[:snapshot] == true)
	#	p exec('snapshot')
	#	break
	#end
	#lane = nil

	Dir.chdir(project_path) do
		p system("gradle clean")
		p system("gradle build")
		p system("gradle assembleRelease")
		#apk is here: app/build/outputs/apk/app-release.apk
		#use fastlane to upload now
	end

	final_name_suffix = "_beta"
	if(options[:offline] == true)
		final_name_suffix = "offline"
	elsif(options[:production] == true)
		command = "supply init --json_key '#{settings[:credentials]['android-dev-console-json-path']}' --package_name #{settings['android-bundle-identifier']}"
		p command
		p system(command)
		command = "supply --apk #{project_path}/app/build/outputs/apk/app-release.apk --json_key '#{settings[:credentials]['android-dev-console-json-path']}' --package_name #{settings['android-bundle-identifier']}"
		p command
		success = p system(command)
		if(success == false)
			puts "Error uploading APK, if this is the very first build of a new app you have to upload the APK file manually".white.on_red
			puts "The production APK is found at #{project_path}/app/build/outputs/apk/app-release.apk".white.on_red
			puts "Go to https://play.google.com/apps to create the application in the Google Play Store and upload the APK.".white.on_red
		end
		final_name_suffix = "_prod"
		#lane = "ios deploy"
	elsif(options[:beta] == true)
		#build_notes = prompt "Build notes?: "
		#lane = "ios beta notes:#{build_notes}"
	end

	Generator.copy_file("#{project_path}/app/build/outputs/apk/app-release.apk", "#{Dir.pwd}/finals/android/#{binaryName(settings, final_name_suffix)}.apk")
	#p exec("fastlane #{lane}")
end

def binaryName settings, suffix
	return "#{settings['short-name']}_#{Time.now.strftime("%Y%m%d_%H%M%S")}_#{suffix}"
end

def renameAndroidImports project_path, identifier
	Find.find(project_path) do |path|
	  if FileTest.directory?(path)
	    if File.basename(path)[0] == ?.
	      Find.prune       # Don't look any further into this directory.
	    else
	      next
	    end
	  elsif File.extname(path) == ".java" || File.extname(path) == '.xml'
		text = File.read(path)
		text.gsub!(/com.push.[A-z]*/, identifier)
		File.write(path, text)
	  else
 		#cleaning...
	  	if(File.basename(path) == '.byebug_history')
	  		FileUtils.rm path
	  	end
 	  end
	end


end

def renameAndroidPackageFolders mode, identifier, project_path
	path = nil
	case mode
	when "main"
		path = '/app/src/main/java/'
	when "test"
		path = '/app/src/androidTest/java/'
	end

	identifier_parts = identifier.split('.')
	identifier_parts.insert 0, ""

	identifier_parts.each do |part|
		part_index = identifier_parts.find_index(part)
		item_index = part_index + 1
		if(identifier_parts.count > item_index)

			i = 0
			finished_path = project_path + path
			until i > part_index
				finished_path += identifier_parts[i] + "/"
				i += 1
			end

			Dir.chdir(finished_path) do
				directories = Dir['*/'] 
				start_dir = Dir.pwd + "/" + directories[0]
				end_dir = Dir.pwd + "/" + identifier_parts[item_index] + "/"

				p "Chaging #{start_dir} to #{end_dir}"

				if(start_dir != end_dir)
					begin
						FileUtils.mv(start_dir, end_dir)
					rescue Exception => e
						byebug
					end
				end
			end
		end
	end

end

options = Parser.parse ARGV

case options[:mode]
when "android"
	generateAndroid options	
when "ios"
	generateIOS options
else
	generateIOS options
	generateAndroid options
end



