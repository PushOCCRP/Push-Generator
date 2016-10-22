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

