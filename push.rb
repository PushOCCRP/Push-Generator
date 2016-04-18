# Push Generator - v1.0
# ©Christopher Guess/ICFJ 2016 
require 'optparse'
require 'pp'
require 'byebug'
require 'yaml'
require 'erb'
require 'fileutils'
require 'mini_magick'

Options = Struct.new(:file_name)

class Parser
  def self.parse(options)
    args = Options.new(options)

    opt_parser = OptionParser.new do |opts|
      opts.banner = "Usage: example.rb [options]"

      opts.on("-fFILE", "--file=FILE", "File name for settings") do |n|
        args.file_name = n
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
	def self.generate options
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
#		pp settings
		#5.) Parse file into iOS format
		generateiOSSettingsFile settings

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
		settings_to_verify = ['name', 'short-name', 'languages', 'icon-large', 'icon-navigation-bar', 'navigation-bar-color', 'navigation-text-color']
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
		settings_to_verify = ['server-url', 'origin-url', 'hockey-key', 'infobip-application-id', 'infobip-application-secret', 'play-store-app-number', 'fabric-key']
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
	end

	def self.generateSettingsFile settings, template
		b = binding
		b.local_variable_set :setting, settings
		@rendered
    	ERB.new(template, 0, ">", "@rendered").result(b)
    	
    	return @rendered
	end

	def self.loadTemplate type
		content = nil
		case type
		when 'iOS-Security'
			content = self.load_file('ios_secrets_template.erb', 'ios_secrets_template.erb')
		when 'iOS-Settings'
			content = self.load_file('ios_settings_template.erb', 'ios_settings_template.erb')
		when 'iOS-Info'
			content = self.load_file('ios_info_template.erb', 'ios_info_template.erb')
		when 'android'
			content = self.load_file('android_template.erb', 'android_template.erb')
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
end

class ImageProcessor
	def self.process_logo image_name, final_location
		image_sizes = {
 		 ["images/images-generated/launch-screen-logo@3x.png"] => "708x708",
 		 ["images/images-generated/icon@3x.png","images/images-generated/icon@3x-1.png"] => "540x540",
 		 ["images/images-generated/logo-512.png"] => "512x512",
 		 ["images/images-generated/icon@2x.png","images/images-generated/icon@2x-1.png","images/images-generated/icon@2x-2.png","images/images-generated/icon@2x-3.png","images/images-generated/icon@2x-4.png","images/images-generated/icon@2x-5.png","images/images-generated/icon@2x-6.png"] => "360x360",
 		 ["images/images-generated/icon 167x167.png", "images/images-generated/icon 167x167-1.png", "images/images-generated/icon 167x167-2.png"] => "167x167",
 		 ["images/images-generated/icon 152x152.png"] => "152x152",
 		 ["images/images-generated/icon 120x120.png"] => "120x120",
 		 ["images/images-generated/icon@1x.png", "images/images-generated/icon@1x-1.png", "images/images-generated/icon@1x-2.png"] => "76x76",
		}
		process image_sizes, image_name, final_location
	end

	def self.process_header_icon image_name, final_location
		image_sizes = {
 		 ["images/images-generated/logo@3x.png"] => "132x500",
 		 ["images/images-generated/logo@2x.png"] => "88x500",
 		 ["images/images-generated/logo@1x.png"] => "44x500",
		}
		process image_sizes, image_name, final_location
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

options = Parser.parse ARGV
settings = Generator.generate options

p "Current path is: #{Dir.pwd}"
ios_project_path = prompt "iOS Project Path: "
ios_project_path.strip!

if(File.exist?(ios_project_path) == false)
	p "Directory not found."
	abort
end

keys_final_location = ios_project_path + "/" + "Push"
FileUtils.cp("./ios/SecretKeys.plist", keys_final_location)
FileUtils.cp("./ios/CustomizedSettings.plist", keys_final_location)
FileUtils.cp("./ios/Info.plist", keys_final_location)

ImageProcessor.process_logo settings['icon-large'], ios_project_path + "/Push/Assets.xcassets/AppIcon.appiconset"
ImageProcessor.process_logo settings['icon-large'], ios_project_path + "/Push"
ImageProcessor.process_header_icon settings['icon-navigation-bar'], ios_project_path + "/Push"

solid_color_image = "images/images-generated/launch-background-color@3x.png"
ImageProcessor.generateSolidColor settings['launch-background-color'], solid_color_image
FileUtils.cp(solid_color_image, ios_project_path + "/Push")

suffix = ""
if(settings['suffix'].nil? == false && settings['suffix'].empty? == false)
	suffix = "-#{settings['suffix']}"
end

settings['languages'].each do |language|
	FileUtils.cp("about-html/about_text-#{language}#{suffix}.html", ios_project_path + "/Push/" + "about_text-#{language}.html")
end



Dir.chdir(ios_project_path) do
	p exec('fastlane gen_test')
end





