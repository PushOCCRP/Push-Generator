# Push App Generator
This is the script that is the real heart of the Push ecosystem. Using some basic config files, this script can customize, build and upload beta and production Android and iOS apps fairly automatically.

The generator uses the Fastlane scripts to handle a lot of the build process and uploading to respective app stores.

# Setup
There are a few things to know:
*Note:* All of these also support an extension, which can be set in the push-mobile.yml file. This allows you to maintain multiple sites in one single instance of the software. Just add '-name_of_company' to the base name of any file. Ex: push-mobile-occrp.yml, creds-occrp.yml etc.
- push-mobile.yml
-- This is the basic config file. In this file you can set colors, names, logos etc.
- creds.yml
-- This should be customized to include your configuration keys for various services. *Do not check this file into the repository*
- /about-html
-- This folder will contain the about page html files for each language in the format about-html-en.html or about-html-ru.html etc.
- /images
-- This folder contains the images you need for your app. Specifically you need to provide a large logo file of 1200x1200 and a navigation bar image at least 60 pixels tall. The names of them are set in the push-mobile.yml file
- /promotions
-- All promotions.yml files should go here (right now, only one is supported, eventually it will merge them). The JSON file is generated automatically for the Android app.
- /finals
-- When every a build is created it is saved into this folder. The extension on the file name will indicate whether it's a beta or production build

### Steps

##### iOS Specific Steps

_If you're starting a new project_
1. If you haven't signed up for an Apple Developer Account log into the [Apple Developer Console](https://developer.apple.com/account). This will take by far the longest. Their system is arduous if you're working for a company. I wish I had better advice, but just be persistant through the D-U-N-S process.

1. Clone the repository

	git clone https://github.com/PushOCCRP/Push-iOS
	git clone https://github.com/PushOCCRP/Push-Generator

	cd Push-iOS
	git checkout tor      # This is the main working branch at the moment
	cd ../Push-Generator

1. Rename the customization file.

	mv push-mobile-occrp.yml push-mobile.yml

1. Open ```push-mobile.yml``` in your favorite text editor. This should be fairly well documented.

1. Make sure to edit ```name```, ```short-name```, ```company-name``` and ```ios-bundle-parameter```. For ```ios-bundle-parameter``` you can make something up, but make sure it's a reverse url like ```com.company.mobileapp```

1. Comment out line starting with ```suffix```

1. Change the line ```credentials-file: "creds-occrp.yml"``` to ```credentials-file: "creds.yml"```

1. Save file

1. Create a copy and rename the credentials file

1. Open ```creds.yml``` in your favorite text editor.

1. The most important things in here for iOS are ```server-url```, ```origin-url```, ```apple-developer-email``` and ```apple-developer-team-id```, make sure to set them correctly

1. Save the file and exit

1. You may have to create a few folders

	mkdir images/images-generated
	mkdir images/images-generated/ios
	mkdir ios
	touch about-html/about_text-en.html

1. Install Ruby gems that are needed

	```bundle install```

1. Run Cocoapods _this may take a LONG time because it has to download some pretty large source files for the CPAProxy_

	cd ../Push-iOS
	pod install
	cd ../Push-Generator

1. Run the generater in bootstrap mode ```ruby push.rb --development -m iOS -i ../Push-iOS```

	> If you get an error about PNG's you may have to install ImageMagick
	> First, install [Homebrew](https://brew.sh/) if you don't have it already.
	> ```brew install imagemagick --build-from-source```

1. You should be able to open the ```Push-iOS``` folder in XCode now and run the simulator or install on a test device.

##### Android Specific Steps 

1. Clone all repositories

	git clone https://github.com/PushOCCRP/Push-Generator
				# If building iOS
	git clone https://github.com/PushOCCRP/Push-Android		# If building Android
	cd Push-Generator


All other folders shouldn't be touched unless you're trying to extend the system.

# Operation

'''ruby push.rb''' will generate a test version of both Android and iOS apps that suitable for running on tethered test devices. This is the first step that you'll probably want to do. From here you can open XCode or Android Studio and build the project directly to a test device.

# Flags and options

- -f /file_name/
-- Read settings from a file name other than "push-mobile.yml", mostly used if you're supporting multiple organizations with one code base.
- -a /android_path_name/
-- Set the path for the Android code base. If not set you will be prompted to type it in
- -i /ios_path_name/
-- Set the path for the iOS code base. If not set you will be prompted to type it in
- -m /build_mode/
-- /Options: 'ios' or 'android'
-- Set whether to build iOS or Android. If not set both are built.
- -p
-- Build for production mode, which will upload the built app to their respective app stores.
- -b
-- Build for beta mode, which will upload the built app to their respective beta stores. *This, ironically, is still in beta and not recommended at the moment for use
- -o
-- Build offline, meaning none of the provisioning profiles are checked. Originally put in so that I could develop it on a plane without needing wifi. Also good for low-connectivity areas if you're in a developing world or what have you.

