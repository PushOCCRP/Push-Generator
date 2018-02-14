# Push Generator - v1.0.1
# ©Christopher Guess 2018
require 'optparse'
require 'byebug'
require 'yaml'
require 'json'
require 'erb'
require 'fileutils'
require 'find'
require 'mini_magick'
require 'pp'
require 'colorize'
require 'commander/import'
require 'open3'
require 'java-properties'
require 'pty'
require 'expect'

program :name, 'Push App Generator'
program :version, '1.1.0'
program :description, 'A script to automatically generate iOS and Android apps for the Push ecosystem'

Options = Struct.new(:file_name, :production, :development, :snapshot, :beta, :mode, :android_path, :ios_path, :offline, :new)

Languages = { "az": "Azerbaijnai",
			  "bg": "Bulgaria",
				"bs": "Bosnian",
			  "en": "English",
			  "ka": "Georgian",
			  "ro": "Romanian",
			  "sr": "Serbian",
			  "ru": "Russian"
			}

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

			opts.on("-d", "--development", "Flag to set up an initial development version for using in XCode") do
				args.development = true
			end

      opts.on("-o", "--offline", "Flag for testing when offline, supercedes beta/production flags") do
      	args.offline = true
      end

      opts.on("-n", "--new", "Flag creating a new application, runs 'produce' to create app on iTunes and Apple Developer Console") do
      	args.new = true
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

	def self.generate options, version_number, build_number, mode, production=false
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
		settings[:language_names] = parse_languages settings['languages']
		settings[:itunes_languages] = handle_apple_languages settings['languages']
		if(!settings['default_language'].nil? && settings['default_language'].empty?)
			settings[:default_language_name] = settings[:language_names].first
		else
			settings[:default_language_name] = Languages[settings['default_language']]
		end

		# Check if the images coming in are the proper ratios
		if !ImageProcessor.check_image_is_square settings['icon-large']
			message = []
			message << "The icon image " + settings['icon-large'].yellow + " is not square."
			message << "Please crop the image so that it is the same height as width before proceeding."
			error message
		end

		if !ImageProcessor.check_image_is_longer_than_wide settings['icon-navigation-bar']
			message = []
			message << "The icon image " + settings['icon-large'].yellow + " must be wider than tall."
			message << "Please rotate or resize the image so that it is wider than tall."
			error message
		end

		settings[:debug] = !production
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
			settings['icon-background-color'] = '#FFFFFF'
		end

		if(settings.has_key?('launch-background-color') == false)
			settings['launch-background-color'] = '#FFFFFF'
		end

		if(settings.has_key?('credentials-file') == false)
			settings['credentials-file'] = 'push-mobile-credentials.yml'
		end

		return settings
	end

	def self.verify_credentials_format credentials
		settings_to_verify = ['server-url', 'origin-url', 'hockey-key', 'hockey-secret', 'uniqush', 'play-store-app-number', 'fabric-key', 'apple-developer-email','apple-developer-team-id']
		settings_to_verify.each do |setting|
			self.check_for_setting(setting, credentials)
		end

		return credentials
	end

	def self.check_for_setting setting_name, settings
		if(settings.has_key?(setting_name) == false)
			raise "No '#{setting_name}' key found in settings"
		end

		if(settings[setting_name].nil? || settings[setting_name].empty?)
			puts "'#{setting_name}' in settings file not properly formatted.".red
			exit
		end

		return true
	end

	def self.parse_languages languages

		language_strings = []

		languages.each do |language|
			if(Languages.has_key?(language.to_sym))
				language_strings << Languages[language.to_sym]
			else
				puts "The language '#{language}' is not currently supported by Push.\nIf you'd like to add it please check ***link to doc****".red
				exit
			end
		end

		return language_strings
	end

	def self.handle_apple_languages languages
		  # So Apple supports a lot less languages on the app store than it does in ios
  # This makes sure that we don't accidently try to register a wrong language
  # If there's none, we default to general "English"
  available_languages = ["Brazilian Portuguese", "Danish", "Dutch", "English", "English_Australian", "English_CA", "English_UK", "Finnish", "French", "French_CA", "German", "Greek", "Indonesian", "Italian", "Japanese", "Korean", "Malay", "Norwegian", "Portuguese", "Russian", "Simplified Chinese", "Spanish", "Spanish_MX", "Swedish", "Thai", "Traditional Chinese", "Turkish", "Vietnamese"]
  languages = languages.map{|language| Languages[language.to_sym] if available_languages.include?(Languages[language.to_sym])}.compact
  languages = ['English'] if languages.empty?
	return languages
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

		template = self.loadTemplate('Android-Fastfile')
		rendered_template = self.generateSettingsFile settings, template
		saveFile 'android/Fastfile', rendered_template

		template = self.loadTemplate('Android-Appfile')
		rendered_template = self.generateSettingsFile settings, template
		saveFile 'android/Appfile', rendered_template
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
			when 'Android-Fastfile'
				content = self.load_file('templates/android/android_fastfile.erb', 'templates/android/android_fastfile.erb')
			when 'Android-Appfile'
				content = self.load_file('templates/android/android_appfile.erb', 'templates/android/android_appfile.erb')
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
			if(language == "sr")
				folders << "values-b+sr+Latn"
			elsif(language != "en")
				folders << "values-" + language
			end
		end
	
		folders.each do |folder|
			path = root_path + "/app/src/main/res/" + folder + "/strings.xml"
			text = File.read(path)
			replaced_text = text.gsub(/<string name=\"app_name\">[A-z0-9\s]*<\/string>/, "<string name=\"app_name\">#{settings['name']}<\/string>")
			tmp_file_path = 'templates/android/strings/' + folder + '_strings.xml'
			File.write(tmp_file_path, replaced_text)
			FileUtils.cp(tmp_file_path, path)
		end
	end
end

class ImageProcessor
	def self.check_image_is_square image_name
		image = MiniMagick::Image.open("images/#{image_name}")
		raise "Image not found at images/#{image_name}" if image.nil?

		return image.dimensions[0] == image.dimensions[1] ? true : false
	end
	
	def self.check_image_is_longer_than_wide image_name
		image = MiniMagick::Image.open("images/#{image_name}")
		raise "Image not found at images/#{image_name}" if image.nil?

		return image.dimensions[0] >= image.dimensions[1] ? true : false
	end

	def self.process_ios_logo image_name, final_location
		image_sizes = {
		 ["images/images-generated/ios/app-store-icon.png"] => "1024x1024",
 		 ["images/images-generated/ios/launch-screen-logo@3x.png"] => "708x708",
 		 ["images/images-generated/ios/logo-512.png"] => "512x512",
		 ["images/images-generated/ios/icon-appstore.png"] => "512x512",
 		 ["images/images-generated/ios/icon@2x-2.png","images/images-generated/ios/icon@2x-6.png"] => "360x360",
 		 ["images/images-generated/ios/icon 167x167-1.png"] => "180x180",
 		 ["images/images-generated/ios/icon 167x167.png", "images/images-generated/ios/icon 167x167-2.png"] => "167x167",
 		 ["images/images-generated/ios/icon@2x-4.png", "images/images-generated/ios/icon 152x152.png"] => "152x152",
 		 ["images/images-generated/ios/icon 120x120.png", "images/images-generated/ios/icon@3x-1.png"] => "120x120",
		 ["images/images-generated/ios/icon-spotlight@3x.png"] => "80x80",
 		 ["images/images-generated/ios/icon@3x.png"] => "87x87",
 		 ["images/images-generated/ios/icon@2x-3.png","images/images-generated/ios/icon@2x-5.png",] => "80x80",
		 ["images/images-generated/ios/icon-spotlight@2x.png"] => "80x80",
 		 ["images/images-generated/ios/icon@1x-2.png"] => "76x76",
 		 ["images/images-generated/ios/icon@2x-1.png","images/images-generated/ios/icon@2x.png"] => "58x58",
 		 ["images/images-generated/ios/icon@1x-1.png"] => "40x40",
		 ["images/images-generated/ios/icon-spotlight.png"] => "80x80",
 		 ["images/images-generated/ios/icon@1x.png"] => "29x29",
		}
		process image_sizes, image_name, final_location
	end

	def self.process_ios_header_icon image_name, final_location
		image_sizes = {
 		 ["images/images-generated/ios/logo@3x.png"] => "500x132",
 		 ["images/images-generated/ios/logo@2x.png"] => "500x88",
 		 ["images/images-generated/ios/logo@1x.png"] => "500x44",
		}
		process image_sizes, image_name, final_location
	end

	def self.process_android_logo image_name, final_location
		xxhdpi_image_sizes = {
		 ["images/images-generated/android/ic_launcher.png"] => "144x144",
		}
		drawable_image_sizes = {
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
		process drawable_image_sizes, image_name, (final_location + "/drawable")
		process xhdpi_image_sizes, image_name, (final_location + "/mipmap-xhdpi")
		process hdpi_image_sizes, image_name, (final_location + "/mipmap-hdpi")
		process mdpi_image_sizes, image_name, (final_location + "/mipmap-mdpi")
	end

	def self.process_android_button_images color, final_location
		change_color 'images/android/ic_language.png', color, 'ic_language.png'

		xxhdpi_image_sizes = {

		 ["images/images-generated/android/ic_language.png"] => "108x78",
		}

		xhdpi_image_sizes = {
			["images/images-generated/android/ic_language.png"] => "72x52",
		}

		hdpi_image_sizes = {
			["images/images-generated/android/ic_language.png"] => "54x39",
		}
		mdpi_image_sizes = {
			["images/images-generated/android/ic_language.png"] => "36x26",
		}

		process_mipmap_images [xxhdpi_image_sizes, xhdpi_image_sizes, hdpi_image_sizes, mdpi_image_sizes], 'images-generated/android/ic_language.png', final_location

		change_color 'images/android/about.png', color, 'about.png'
		xxhdpi_image_sizes = {

		 ["images/images-generated/android/about.png"] => "68x70",
		}

		xhdpi_image_sizes = {
			["images/images-generated/android/about.png"] => "68x70",
		}

		hdpi_image_sizes = {
			["images/images-generated/android/about.png"] => "34x35",
		}
		mdpi_image_sizes = {
			["images/images-generated/android/about.png"] => "34x35",
		}

		process_mipmap_images [xxhdpi_image_sizes, xhdpi_image_sizes, hdpi_image_sizes, mdpi_image_sizes], 'images-generated/android/about.png', final_location

		change_color 'images/android/ic_action_cancel.png', color, 'ic_action_cancel.png'
		xxhdpi_image_sizes = {

		 ["images/images-generated/android/ic_action_cancel.png"] => "96x96",
		}

		xhdpi_image_sizes = {
			["images/images-generated/android/ic_action_cancel.png"] => "64x64",
		}

		hdpi_image_sizes = {
			["images/images-generated/android/ic_action_cancel.png"] => "34x35",
		}
		mdpi_image_sizes = {
			["images/images-generated/android/ic_action_cancel.png"] => "34x35",
		}

		process_mipmap_images [xxhdpi_image_sizes, xhdpi_image_sizes, hdpi_image_sizes, mdpi_image_sizes], 'images-generated/android/ic_action_cancel.png', final_location

		change_color 'images/android/ic_search_white.png', color, 'ic_search_white.png'
		xxhdpi_image_sizes = {

		 ["images/images-generated/android/ic_search_white.png"] => "144x144",
		}

		xhdpi_image_sizes = {
			["images/images-generated/android/ic_search_white.png"] => "96x96",
		}

		hdpi_image_sizes = {
			["images/images-generated/android/ic_search_white.png"] => "72x72",
		}
		mdpi_image_sizes = {
			["images/images-generated/android/ic_search_white.png"] => "48x48",
		}

		process_mipmap_images [xxhdpi_image_sizes, xhdpi_image_sizes, hdpi_image_sizes, mdpi_image_sizes], 'images-generated/android/ic_search_white.png', final_location

		change_color 'images/android/ic_share_white_48dp.png', color, 'ic_share_white_48dp.png'
		xxhdpi_image_sizes = {

		 ["images/images-generated/android/ic_share_white_48dp.png"] => "144x144",
		}

		xhdpi_image_sizes = {
			["images/images-generated/android/ic_share_white_48dp.png"] => "96x96",
		}

		hdpi_image_sizes = {
			["images/images-generated/android/ic_share_white_48dp.png"] => "72x72",
		}
		mdpi_image_sizes = {
			["images/images-generated/android/ic_share_white_48dp.png"] => "48x48",
		}

		process_mipmap_images [xxhdpi_image_sizes, xhdpi_image_sizes, hdpi_image_sizes, mdpi_image_sizes], 'images-generated/android/ic_share_white_48dp.png', final_location

		#1.) change the colors
		#2.) size the files correctly
		#3.) place them into the correct android mipmap folders
		#copy from the header right below
	end

	def self.process_mipmap_images sizes, name, final_location
		process sizes[0], name, (final_location + "/mipmap-xxhdpi")
		process sizes[1], name, (final_location + "/mipmap-xhdpi")
		process sizes[2], name, (final_location + "/mipmap-hdpi")
		process sizes[3], name, (final_location + "/mipmap-mdpi")

	end

	def self.process_android_header_icon image_name, final_location
		xxhdpi_image_sizes = {
		 	["images/images-generated/android/logo.png"] => "800x128",
		}

		xhdpi_image_sizes = {
			["images/images-generated/android/logo.png"] => "800x92",
		}

		hdpi_image_sizes = {
			["images/images-generated/android/logo.png"] => "800x64",
		}
		mdpi_image_sizes = {
			["images/images-generated/android/logo.png"] => "800x48",
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

	def self.change_color image_name, color, final_name
		#image = MiniMagick::Image.open("images/#{image_name}")
		MiniMagick::Tool::Convert.new do |convert|
			#convert.fill(start_color)	
			convert.merge! [image_name, '-channel', 'RGB', '-fill', color, '+opaque', color, '-fuzz', '20%', "images/images-generated/android/#{final_name}"]
		  	
		end #=> `mogrify -resize 100x100 -negate image.jpg`
	end

	#Takes hex
	def self.generateSolidColor color, file_name
		MiniMagick::Tool::Convert.new do |convert|
		  convert.merge! ["-size", "1200x1200", "xc:#{color}"]
		  convert << file_name
		end		
	end
end

def generateIOS options, version_number = "1.0", build_number = "1"

	settings = Generator.generate options, version_number.strip!, build_number.strip!, :iOS

	if(options[:ios_path].nil? || options[:ios_path].empty?)
		p "Current path is: #{Dir.pwd}"
		project_path = ask "iOS Project Path: "
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

		about_file_path = project_path + "/Push/" + "about_text-#{language}.html"
		if(File.file?(about_file_path))
			File.delete(about_file_path)
		end

		begin
			FileUtils.cp("about-html/about_text-#{language}#{suffix}.html", about_file_path)
		rescue
			message = []	
			message << "    No " + "about-html/about_text-#{language}#{suffix}.html".yellow + " file found for "+"#{settings['suffix']}".green
			message << "    This is because you have not added the about.html file for the language "+ Languages[language.to_sym].green+"."
			message << "\n"
			message << "    Please create the about file and try running this again."
			error message
		end
	end

	if(File.file?("promotions/promotions#{suffix}.yml"))
		FileUtils.cp("promotions/promotions#{suffix}.yml", project_path + "/Assets/promotions.yml")
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
		elsif(options[:development] == true)
			lane = "ios bootstrap"
			file_suffix = "dev"
		elsif(options[:production] == true)
			lane = "ios deploy"
			file_suffix = "prod"
		elsif(options[:beta] == true)
			build_notes = ask "Build notes?: "
			lane = "ios beta notes:#{build_notes}"
			file_suffix = "beta"
		else
			lane = "ios gen_test"
			file_suffix = "beta"
		end
		
		# The first time through we need to make sure that all the gems are installed in the iOS
		# app repository.
		p system("bundle install")
		p system("bundle exec fastlane create") if(options[:new] == true)
		loop do
			cmd = "bundle exec fastlane #{lane}"
			status = true
			error = nil
			exit_status = nil
			PTY.spawn(cmd) do |reader, writer, pid|
				begin
		      # Do stuff with the output here. Just printing to show it works
		      reader.each { |line| print line }
					reader.expect "Please enter the 6 digit code:"
					code = ask ("Two factor code: ")
					writer.puts code

					reader.expect /(Password \(for).+/
					password = ask ("Password: ")
					writer.puts password

					reader.expect /(Multiple Teams found on the Developer Portal, please enter).+/
					code = ask "Number of organization."
					writer.puts code

					reader.expect /(Could not find App with App Identifier).+/ do
						status = false
						error = :no_app
					end

					reader.expect /(Missing password for user).+/ do
						status = false
						error = :missing_password
					end
				rescue Errno::EIO
		      puts "Errno:EIO error, but this probably just means " +
		            "that the process has finished giving output"
		    end

			end
#			response = process(cmd, {log: true, pty: true})
			# Open3.popen3(cmd) do |stdin, stdout, stderr, wait_thr|
			# 	while line = stdout.gets
			# 		puts line
			# 		if line.include?("Could not find App with App Identifier")
			# 			status = false
			# 			error = :no_app 
			# 		elsif line.include?("Missing password for user")
			# 			status = false
			# 			error = :missing_password
			# 		end
			# 	end
			#   exit_status = wait_thr.value
			# end

			# if line.include?("Could not find App with App Identifier")
			# 	status = false
			# 	error = :no_app
			# elsif line.include?("Missing password for user") 
			# 	status = false
			# 	error = :missing_password
			# else
				exit_status = :success
			# end

			if(!status)
				case error
				when :no_app
					say "It seems as if the app doesn't exist yet on your Apple developer account"
					should_continue = agree "Would you like to add it [yes/no]?: "
				when :missing_password
					add_apple_developer_user settings[:credentials]['apple-developer-email']
					should_continue = true
				else
					p "Unknown error occured. Please file a bug report at https://github.com/PushOCCRP/Push-Generator"
					should_continue = false
				end
				
				exit if should_continue == false

				add_appple_developer_app settings
			else
				exit unless exit_status == :success
	  		break;
			end
		end
	end

	Generator.copy_file(project_path + "/Push.ipa", "#{Dir.pwd}/finals/ios/#{binaryName(settings, file_suffix)}.ipa")
end

def add_appple_developer_app settings
	cmd = "produce -q '#{settings['name']}' -c '#{settings['company-name']}'"
	status = true
	exit_status = nil
	Open3.popen3(cmd) do |stdin, stdout, stderr, wait_thr|
		while line = stdout.gets
			puts line
			status = false if line.include?("Missing password for user")
		end
		exit_status = wait_thr.value
	end

	if(!status)
		add_appple_developer_user settings[:credentials]['apple-developer-email']
	else
		exit unless exit_status.success?
	end
end

def add_apple_developer_user email
	say "Please login to your Apple Developer Account: #{email}".green
	password = ask("Password:  ") { |q| q.echo = "*" }
	cmd = "fastlane fastlane-credentials add --username #{email} --password #{password}"
	status = false
	Open3.popen3(cmd) do |stdin, stdout, stderr, wait_thr|
		while line = stdout.gets
			puts line
			status = true if line.include?("added to keychain.")
		end
		exit_status = wait_thr.value
		exit unless exit_status.success?
	end

	p "Added #{email} to your keychain."
end

def generateAndroid options, version_number = "1.0", build_number = "1"

	settings = Generator.generate options, version_number, build_number, :android, options[:production]

	suffix = ""
	if(settings['suffix'].nil? == false && settings['suffix'].empty? == false)
		suffix = "-#{settings['suffix']}"
	end

	if(options[:android_path].empty?)
		p "Current path is: #{Dir.pwd}"
		project_path = ask "Android Project Path: "
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

	if(!File.file?("./google-service/google-services#{suffix}.json"))
		message = []	
		message << "    No " + "google-services.json".yellow + " file found for "+"#{settings['suffix']}".green
		message << "    You probably need to create one still."
		message << "\n"
		message << "    Instructions can be found in the README.md files, but here are some tips:"
		message << "    You can create your App in the Firebase console at " + "https://console.firebase.google.com".blue
		message << "    Next, click 'Add Firebase to your Android app' and fill in the details"
		message << "    Copy the "+"google-services.json".green + " file to the "+"./google-services".green + " folder in this repository"
		error message
		return
	end

	# First we have to get the previous name being set
	old_application_id = getPreviousAndroidApplicationID project_path

	FileUtils.cp("./google-service/google-services#{suffix}.json", keys_final_location + "/google-services.json");

	FileUtils.cp("./android/safe_variables.gradle", keys_final_location)
	FileUtils.cp("./android/colors.xml", keys_final_location + "/src/main/res/values/")
	FileUtils.cp("./android/AndroidManifest.xml", keys_final_location + "/src/main/")
	FileUtils.cp("./android/AndroidManifestDebug.xml", keys_final_location + "/src/debug/AndroidManifest.xml")
	FileUtils.cp("./android/build.gradle", keys_final_location)
	FileUtils.cp("./android/Screengrabfile", keys_final_location + "/../fastlane/Screengrabfile")
	FileUtils.cp("./android/Fastfile", keys_final_location + "/../fastlane/Fastfile")
	FileUtils.cp("./android/Appfile", keys_final_location + "/../fastlane/Appfile")

	ImageProcessor.process_android_logo settings['icon-large'], project_path + "/app/src/main/res"
	ImageProcessor.process_android_header_icon settings['icon-navigation-bar'], project_path + "/app/src/main/res"
	ImageProcessor.process_android_button_images settings['navigation-text-color'], project_path + "/app/src/main/res"
=begin
	solid_color_image = "images/images-generated/launch-background-color@3x.png"
	ImageProcessor.generateSolidColor settings['launch-background-color'], solid_color_image
	FileUtils.cp(solid_color_image, project_path + "/Push")
=end

	settings['languages'].each do |language|
		FileUtils.cp("about-html/about_text-#{language}#{suffix}.html", project_path + "/app/src/main/assets/" + "about_text-#{language}.html")
	end

	if(File.file?("promotions/promotions#{suffix}.yml"))
		#since android <5.0 is terrible, we're switching to json parsing here

		input_filename = "promotions/promotions#{suffix}.yml"
		output_filename = input_filename.sub(/(yml|yaml)$/, 'json')

		input_file = File.open(input_filename, 'r')
		input_yml = input_file.read
		input_file.close

		output_json = JSON.dump(YAML::load(input_yml))

		output_file = File.open(output_filename, 'w+')
		output_file.write(output_json)
		output_file.close
		FileUtils.cp("promotions/promotions#{suffix}.json", project_path + "/app/src/main/assets/promotions.json")
	end


	#requires https://github.com/PushOCCRP/android-rename-package
	p "Changing Android package name to #{settings['android-bundle-identifier']}"
	renameAndroidImports project_path, settings['android-bundle-identifier'], old_application_id
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
	elsif(options[:development] == true)
		final_name_suffix = "dev"
	elsif(options[:production] == true)
		command = "supply init --json_key '#{settings[:credentials]['android-dev-console-json-path']}' --package_name #{settings['android-bundle-identifier']}"
		p command
		p system(command)
		command = "supply --apk #{project_path}/app/build/outputs/apk/release/app-release.apk --json_key '#{settings[:credentials]['android-dev-console-json-path']}' --package_name #{settings['android-bundle-identifier']}"
		p command
		success = p system(command)
		if(success == false)
			message = []
			message << "Error uploading APK, if this is the very first build of a new app you have to upload the APK file manually".white.on_red
			message << "The production APK is found at #{project_path}/app/build/outputs/apk/app-release.apk".white.on_red
			message << "Go to https://play.google.com/apps to create the application in the Google Play Store and upload the APK.".white.on_red
			error message, false
		end
		final_name_suffix = "_prod"
		#lane = "ios deploy"
	elsif(options[:beta] == true)
		build_notes = ask "Build notes?: "
		lane = "android beta notes:#{build_notes}"
	end

	Generator.copy_file("#{project_path}/app/build/outputs/apk/release/app-release.apk", "#{Dir.pwd}/finals/android/#{binaryName(settings, final_name_suffix)}.apk")
	p exec("cd #{project_path}")
	p exec("cd #{project_path} && fastlane #{lane} apk:#{Dir.pwd}/finals/android/#{binaryName(settings, final_name_suffix)}.apk") if(lane != nil)
end

def binaryName settings, suffix
	return "#{settings['short-name']}_#{Time.now.strftime("%Y%m%d_%H%M%S")}_#{suffix}"
end

def renameAndroidImports project_path, identifier, old_application_id
	Find.find(project_path) do |path|
	  if FileTest.directory?(path)
	    if File.basename(path)[0] == ?.
	      Find.prune       # Don't look any further into this directory.
	    else
	      next
	    end
	  elsif File.extname(path) == ".java" || File.extname(path) == '.xml'
		text = File.read(path)
			puts("Changing name in file: #{path}")
			# Two passes, one to switch package names
			# Second pass takes care of defaults in the package templates
			# byebug unless text[/#{old_application_id}[A-z]*/].nil?
			text.gsub!(/#{old_application_id}[A-z]*/, identifier)
			text.gsub!(/com\.push\.[A-z]*/, identifier)
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
				finished_path += identifier_parts[i]
				finished_path += "/" unless finished_path.end_with? "/"
				i += 1
			end
			
			Dir.chdir(finished_path) do
				directories = Dir['*/'] 
				start_dir = Dir.pwd + "/" + directories[0]
				end_dir = Dir.pwd + "/" + identifier_parts[item_index] + "/"

				p "Changing #{start_dir} to #{end_dir}"

				if(start_dir != end_dir)
					begin
						FileUtils.mv(start_dir, end_dir)
					rescue Exception => e
						message = []
						message << "Copying Android folders raised an error:"
						message << e
						error message
					end
				end
			end
		end
	end

end

def getPreviousAndroidApplicationID project_path
	project_path += "/" unless project_path[-1] == '/'
	begin
		properties = JavaProperties.load(project_path + "app/build.gradle")		
		app_name = properties[:applicationId].tr('"', '')
	rescue Exception => e
		app_name = "com.push.meydan"
	end

	return app_name
end

# This takes in a message, that can be a string or an array of string, each will be printed on a different line
def error message, exit_on_print = true
		raise "Error message only takes 'String' or 'Array'" if !message.is_a?(Array) && !message.is_a?(String)

		say "\n-----------------------------------------------------------------".red
		say "    Error:\n".red
		say "    " + message if message.is_a?(String)
		message.each {|line| say "    " + line } if message.is_a?(Array)
		say "-----------------------------------------------------------------\n".red
		exit if exit_on_print
end

options = Parser.parse ARGV

ios_version_number = "1.0"
ios_build_number = "1"
android_version_number = "1.0"
android_build_number = "1"

case options[:mode]
when "android"
	if(options[:production] == true || options[:beta] == true)
		android_version_number = ask "Android Version number: "
		android_build_number = ask "Android Build number: "
		android_version_number.strip!
		android_build_number.strip!
		if(android_build_number.to_i < 100)
			android_build_number = (android_build_number.to_i * 100).to_s
		end
	end

	generateAndroid options, android_version_number, android_build_number
when "ios"
	if(options[:production] == true || options[:beta] == true)
		ios_version_number = ask "iOS Version number: "
		ios_build_number = ask "iOS Build number: "
	end

	generateIOS options, ios_version_number, ios_build_number
else
	if(options[:production] == true || options[:beta] == true)
		ios_version_number = ask "iOS Version number: "
		ios_build_number = ask "iOS Build number: "
	end

	if(options[:production] == true || options[:beta] == true)
		puts "Link to Google Developer Console (I always need to be reminded): https://play.google.com/apps/publish/"
		android_version_number = ask "Android Version number: "
		android_build_number = ask "Android Build number: "
		android_version_number.strip!
		android_build_number.strip!
		if(android_build_number.to_i < 100)
			android_build_number = (android_build_number.to_i * 100).to_s
		end
	end

	generateIOS options, ios_version_number, ios_build_number
	generateAndroid options, android_version_number, android_build_number
end