# Push App Generator
This is the script that is the real heart of the Push ecosystem. Using some basic config files, this script can customize, build and upload beta and production Android and iOS apps fairly automatically.

The generator uses the Fastlane scripts to handle a lot of the build process and uploading to respective app stores.

# Setup
There are a few things to know:
*Note:* All of these also support an extension, which can be set in the push-mobile.yml file. This allows you to maintain multiple sites in one single instance of the software. Just add '-name_of_company' to the base name of any file. Ex: push-mobile-occrp.yml, creds-occrp.yml etc.
- push-mobile.yml
-- This is the basic config file. In this file you can set colors, names, logos etc.
- push-mobile-credentials.yml
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

##### Installing Pre-requisite Stuff
_If you don't have Ruby installed already you must do so. This is somewhat a bit of a chore, but required for the development machine._

1. Install Homebrew (skip if you have it installed already)
	1. In a terminal type ```/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"```
	1. Say yes, and type in your password
1. Install Git
	1. ```brew install git```
1. Install GPG (RVM uses this to verify ruby packages are legit)
	1. ```brew install gpg```
1. Install RVM. This is used to easily manage different types of the programming language Ruby, otherwise it can be a bit of a mess.
	1. ```curl -sSL https://rvm.io/mpapis.asc | gpg --import -```
	1. ```\curl -sSL https://get.rvm.io | bash -s stable```
	1. Now close your terminal window and reopen a new one. This reloads the shell so the ```rvm``` command now appears.
1. Install Ruby
	1. ```rvm install $(<.ruby-version)```
	1. Wait awhile. Depending on your machine this can take quite a bit of time.	
	1. rvm --default use $(<.ruby-version)```
	1. Install the main bundler gem ```gem install bundler```
	1. ```ruby -v``` should show a proper version of Ruby.
1. Install ImageMagick
	1. ```brew install imagemagick```
1. Pull the generator code
	1. ```git clone https://github.com/PushOCCRP/Push-Generator```
	1. ```cd Push-Generator```
1. Install all the gems needed
	1. ```bundle install```
1. If you've never opened XCode before, do so now, accept the terms of service and let the software install all the components.
1. After XCode does its thing go back to the terminal and make sure that the system is using the right version of tools. ```sudo xcode-select -s /Applications/Xcode.app/Contents/Developer```
1. The repositories come with sample images, but you should replace them. There are two:
	- A square image at least 512x512 for the icon logo and launch screen, I usually call this one ```logo-<<name>>".png```
	- An image wider than it is tall for the top navigation bar. I usually call this one ```logo-navbar-<<name>>.png```
1. Place the images in the ./images folder

##### iOS Specific Steps

_If you're starting a new project_
1. If you haven't signed up for an Apple Developer Account log into the [Apple Developer Console](https://developer.apple.com/account). This will take by far the longest. Their system is arduous if you're working for a company. I wish I had better advice, but just be persistant through the D-U-N-S process.

1. Clone the repository

```
git clone https://github.com/PushOCCRP/Push-iOS
```

##### Steps For All Targets
1. Rename the customization file.

```mv push-mobile-occrp.yml push-mobile.yml```

1. Open ```push-mobile.yml``` in your favorite text editor. This should be fairly well documented.

1. Make sure to edit ```name```, ```short-name```, ```company-name``` and ```ios-bundle-parameter```. For ```ios-bundle-parameter``` you can make something up, but make sure it's a reverse url like ```com.company.mobileapp```

1. Comment out line starting with ```suffix```

1. Change the line ```credentials-file: "push-mobile-credentials-template.yml"``` to ```credentials-file: "creds.yml"```

1. Save file

1. Create a copy and rename the credentials file

1. Open ```creds.yml``` in your favorite text editor.

1. The most important things in here for iOS are ```server-url```, ```origin-url```, ```apple-developer-email``` and ```apple-developer-team-id```, make sure to set them correctly

1. Save the file and exit

1. You may have to create a few folders

```
	mkdir images/images-generated
	mkdir images/images-generated/ios
	mkdir ios
	touch about-html/about_text-en-push.html
```

1. You need move over images for your organization. There are two specifically you'll n

1. Install Ruby gems that are needed

	```bundle install```

1. Run Cocoapods _this may take a LONG time because it has to download some pretty large source files for the CPAProxy_

```
	cd ../Push-iOS
	pod update
	bundle update
	cd ../Push-Generator
```
1. Run the generater in bootstrap mode ```bundle exec ruby push.rb --development -m iOS -i ../Push-iOS```

	> If you get an error about PNG's you may have to install ImageMagick
	> First, install [Homebrew](https://brew.sh/) if you don't have it already.
	> ```brew install imagemagick --build-from-source```

	> If this is your first time you will have to log into your Apple Developer Account, so watch out.

	> If you're using 2-Factor Authentication on your Apple account (you should) it gets more difficult. Follow the following steps:
	1. ```cd ../Push-iOS```
	1. ```bundle exec fastlane cert```
	1. Go through the whole process of logging in, generating the key and continuing

<!-- 	1. Visit appleid.apple.com/account/manage
	1. Login, persumably using your two factor auth.
	1. Scroll down to the "Security" section, and click the "Generate Password..." link in the right column
	1. Type in a name: "Push Generator" is a good one.
	1. Since your normal username is now save, we have to remove it first. Go to your terminal and type ```bundle exec fastlane fastlane-credentials remove```. Then type in your Apple Id email.
	1. ```cd ../Push-iOS```
	1. ```bundle exec fastlane fastlane-credentials add```
	1. Type in your apple id and then the password we generated above.
	1. ```cd ../Push-Generator```
	1. Run ```bundle exec ruby push.rb --development -m iOS -i ../Push-iOS``` again (yes, again)

	> If this still doesn't work try to do the ```remove``` feature in both the ```Push-Generator``` and ```Push-iOS``` folder. -->

	> You may get an error about your account not having a device. If this happens just continue to the next step.

1. Open XCode
	1. File menu -> Open -> Navigate to the Push-iOS folder -> Click Open
	1. Plug in your test device (iPhone or iPad)

	> If this is a brand new Apple Developer Account you need to add at least one device to the store. Xcode can do this for you.
	1. Unlock your device (passcode, FaceID, TouchID etc.)
	1. Click "trust" on your device.
	1. XCode menu -> Preferences -> Accounts tab -> Plus button in lower left corner
	1. Choose "Apple ID" and click "Continue"
	1. Login to your Apple ID account.
	1. Go to the "Push" Project item on the left side navigator.
	1. Make sure "Automatically manage signing" is chcecked.
	1. In the "Signing" section, click "Register Device"

1. If you ran into error about devices before you can rerun ```ruby push.rb --development -m iOS -i ../Push-iOS``` and it should work through without any bugs.

1. Choose your test device in the device drop down near the top of XCode

1. Product menu -> Run 
	> You may have to click "Enable" and type in your password if a "Enable Developer Mode on this Mac?" dialoug appears.

##### Android Specific Steps 

1. Update Homebrew ```brew tap caskroom/versions```

1. Install Java build requirements ```brew cask install java8``` (yes, the '8' is not a typo)

1. Install Gradle command line. ```brew install gradle```

1. Download Android Studio from https://developer.android.com/studio/index.html

1. Open the DMG file, drag the Android Studio icon to the 'Applications' folder.

1. Open Android Studio, click "do not import settings"

1. Click through the installation choosing "standard" when prompted. It will then download a bunch of components, let it do so.

1. It'll ask you a put in your password as well as allow a system extension. Do so, and click "allow" in the lower right when the preferences open up.

1. Clone all repositories
```
git clone https://github.com/PushOCCRP/Push-Generator
git clone https://github.com/PushOCCRP/Push-Android
```

1. We want to add specific git hooks into this repository. This is so that we don't screw up the master repositories.

```
cd Push-Android
bundle install
git config core.hooksPath hooks
cd ../Push-Generator
```
1. Create the app in the [Google Play Developer Console](https://play.google.com/apps/publish)
1. Create the app in the [Firebase Console](https://console.firebase.google.com/?pli=1)
1. After choosing your new app in the Firebase Console, you should have a page that says "Get started here." Click the "Add Firebase to your Android app"
1. Enter the app id and name (make sure it's the same as in the push generator configuration file)
1. Click the "Download google-services.json" button.
1. Click the small link in the lower left that says "Skip to the console"
1. Copy the ```google-services.json``` file that was just downloaded to the ```/google-services/``` folder in the generator.
1. Add a suffix to your google-service.json file the same as you set in the settings.yml file earlier.
1. Run the generator https://github.com/PushOCCRP/Push-Generator in offline mode with the ```-o``` flag
1. Open the cloned Push-Android repository in Android Studio. This will automatically install a bunch of files that are needed.
1. We need to install the NDK. 
	1. File menu -> Project Structure -> Install NDK
	1. Wait awhile.
1. We now need to sign the app, so that it'll actually run on devices. There are a couple of ways to do this, and all the options are [here](https://developer.android.com/studio/publish/app-signing.html). For this we'll self-sign, since it's the easiest. Please note though, do NOT lose these keys. You won't get them back and it'll be a pain to contact Google. 

    I know, this is a bit of a pain, but please bear with me, it should only take a few minutes.

    1. In the menu bar, click Build > Generate Signed APK
    1. The drop down should be appropriate, so click Next
    1. Click 'Create New...'
    1. In the 'Key store path: ' please put a location for your key somewhere on your local machine. Something like ```/Users/yourname/AndroidKeystore``` Note this location, because we're going to need it in a minutes.
    1. For first 'Password' and 'Confirm' go ahead and put that in a good password you can remember.
    1. In 'Alias' choose a name ('Push app keystore' would work well). Note this as well.
    1. For the second password field, choose another password. I suggest using a [password manager](https://lifehacker.com/5529133/five-best-password-managers) to save these.
    1. Keep validity to '25'
    1. Put in your contact information for the key.
    1. Click 'Save'
    1. The passwords should be prefilled for you in the screen now. Click 'Remember passwords' checkbox.
    1. Click 'Next'
    1. Click the 'V2 (Full APK Signature)' checkbox.
    1. Click 'Finish'

1. Opens the credentials file that you created earlier. Find the line that starts with ```android-store-file-path:``` and add the path you typed in in step four above. It should look like ```android-store-file-path: /path/to/your/keystore``` on its own line.

1. In the credentials file add the first password to the line beginning with ```android-store-password: ```

1. Add the keystore alias name to the line ```android-key-alias:```.

1. Add the second password to the line ```android-key-password:```.

1. Save the credentials file.

1. Go back to the command line and run the generater in bootstrap mode ```ruby push.rb -m android -a ../Push-Android```

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
- -d /development/
-- Flag to set up an initial development version. In Android this changes the app name to com.pushapp.press for Git purposes.
- -m /build_mode/
-- /Options: 'ios' or 'android'
-- Set whether to build iOS or Android. If not set both are built.
- -p
-- Build for production mode, which will upload the built app to their respective app stores.
- -b
-- Build for beta mode, which will upload the built app to their respective beta stores. *This, ironically, is still in beta and not recommended at the moment for use
- -o
-- Build offline, meaning none of the provisioning profiles are checked. Originally put in so that I could develop it on a plane without needing wifi. Also good for low-connectivity areas if you're in a developing world or what have you.

