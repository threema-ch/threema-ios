# Custom Branding Manual

*To preview this file as DocC select "Editor" -> "Assistant"*

##
- Important: Make sure you edit the config files in the directory this manual is in `CustomOnPrem` and not in `ThreemaOnPrem`!

## Xcode
- Warning: Please construct the CustomOnPrem Application exclusively utilizing Xcode 16.4 (Command Line Tool 16.4 and MacOS Sequoia 15.7.x). Threema has not yet supported the building process with Xcode 26.

## Certificates
The following suffixes are required for the certificates:
* App
  * `iapp`
* NotificationExtension
  * `iapp.NotificationExtension`
* ShareExtension
  * `iapp.ShareExtension`

## Signing & Capabilities
- Warning: Not following these steps at the beginning might lead to all users loosing their data when changing later.

Fill in information configured beforehand from the developer portal:
1) Tap on 'Threema' at the top of the navigator on the left
2) Select target "Custom OnPrem"
3) Go to "App Groups" and select the group added in AppStore Connect beforehand
4) Go to "Keychain Sharing" remove the `com.custom.onprem.iapp` by clicking on the "-". Then click "+", Xcode should suggest your custom reverse domain automatically. \
⚠️ In the ShareExtension and NotificationExtension the string must be Exactly the same as in app. You might need to remove "ShareExtension" and "NotificationExtension" manually in these targets!

5) Repeat points 3 & 4 for "Custom OnPrem NotificationExtension" and "Custom OnPrem ShareExtension"

## xconfig Files
All config files are in the same directory this manual is in. Change the modifiable values according to your needs.

## Strings
Replace all occurrences of "`Custom OnPrem`" in all languages in the following string catalogs:
- `Threema/SupportingFiles/CustomOnPrem/InfoPlist.xcstrings`
- `ThreemaNotificationExtension/SupportingFiles/CustomOnPrem/CustomOnPremNotificationExtension-InfoPlist.xcstrings`
- `ThreemaShareExtension/SupportingFiles/CustomOnPrem/CustomOnPremShareExtension-InfoPlist.xcstrings`

#### CustomOnPremConfig.xconfig
Main config file. Other files inherit/reference some of these values.

| Identifier                                        | Description                                                                                                                                                                | Modifiable  | Mandatory |
| ------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :---------: | :-------: |
| `APP_NAME`                                        | Name of the app on the home screen etc.                                                                                                                                    | ✅          | ✅        |
| `LOCALIZED_APP_NAME`                              | Name in the app for all texts (Instead of Threema ID → {LOCALIZED_APP_NAME} ID                                                                                             | ✅          | ✅        |
| `BUNDLE_BASE_IDENTIFIER`                          | The base identifier for all certificates                                                                                                                                   | ✅          | ✅        |
| `APP_BUNDLE_IDENTIFIER`                           | The identifier for the app certificate                                                                                                                                     | ✅          | ✅        |
| `GROUP_IDENTIFIER`                                | The identifier for the app groups of the bundle                                                                                                                            | ✅          | ✅        |
| `PRESET_OPPF_URL`                                 | URL of the OPPF file (not editable for the user on the login screen when set)                                                                                              | ✅          | ✅        |
| `APP_URL_SCHEME`                                  | Define a custom URI scheme for the app (only scheme without separator, e.g. `customonprem`, this will result in `customonprem://` URIs)                                    | ✅          | ✅        |
| `APP_ENCRYPTION_EXPORT_COMPLIANCE_CODE`           | Declare the use of encryption to streamline the app submission process                                                                                                     | ✅          | ✅        |
| `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME`  | Name of the accent color defined in `SharedResources/TargetColorsCustomOnPrem`                                                                                             | ✅          | ✅        |
| `SUPPORT_FAQ_URL`                                 | FAQ URL; Use $(SLASH) for the first of double slashes                                                                                                                      | ✅          | ❌        |
| `DEVICE_JOIN_DOWNLOAD_URL`                        | URL to download the desktop 2.0 app; Use $(SLASH) for the first of double slashes. Without URL there is a text 'URL is missing'. Only mandatory if multi device is enabled | ✅          | ✅        |
| `TARGET_MANAGER_KEY`                              | Must be CustomOnPrem, do not change this                                          | ❌          | ✅        |


#### CustomOnPremAppConfig.xcconfig
Config file for the app target. Do **NOT CHANGE** these values!

| Identifier                                            | Description                                                       | Modifiable  | Mandatory |
| ----------------------------------------------------- | ----------------------------------------------------------------- | :---------: | :-------: |
| `PRODUCT_NAME`                                        | Name of the app on the home screen                                | ❌          | ✅        |
| `PRODUCT_BUNDLE_IDENTIFIER`                           | Bundle identifier of the app                                      | ❌          | ✅        |
| `APP_URL_TYPE_IDENTIFIER`                             | URL identifier                                                    | ❌          | ✅        |
| `ASSETCATALOG_COMPILER_APPICON_NAME`                  | Name of the asset for the app icons                               | ❌          | ✅        |
| `ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS`    | Only the primary app icon will be included in the built product   | ❌          | ✅        |
| `INFOPLIST_KEY_UILaunchStoryboardName`                | Name of the storyboard for the launch screen                      | ❌          | ✅        |
| `PRIVACY_DESCRIPTION_CONTACTS`                        | Description in the alert to get access to contacts                | ❌          | ✅        |

#### CustomOnPremNotificationExtensionConfig.xcconfig
Config file for the notification extension target. Do **NOT CHANGE** these values!

| Identifier                    | Description                                       | Modifiable  | Mandatory |
| ----------------------------- | ------------------------------------------------- | :---------: | :-------: |
| `PRODUCT_NAME`                | Name of the notification extension                | ❌          | ✅        |
| `PRODUCT_BUNDLE_IDENTIFIER`   | Bundle identifier of the notification extension   | ❌          | ✅        |

#### CustomOnPremShareExtensionConfig.xcconfig
Config file for the share extension target. Do **NOT CHANGE** these values!

| Identifier                    | Description                               | Modifiable  | Mandatory |
| ----------------------------- | ----------------------------------------- | :---------: | :-------: |
| `PRODUCT_NAME`                | Name of the share extension               | ❌          | ✅        |
| `PRODUCT_BUNDLE_IDENTIFIER`   | Bundle identifier of the share extension  | ❌          | ✅        |

## Images
**Important:**  Replace the images only, the **names must remain the same!**

#### Framework Images
Check appearances in the attributes inspector.\
Path: `ThreemaFramework/Resources/Framework Symbols.xcassets`

| Name                          | Description                                               | Type   | Size                 | Appearances | Mandatory |
| ----------------------------- | --------------------------------------------------------- | :----: | -------------------- | ----------- | :-------: |
| `VoipCustom`                  | Shown in iOS call overlay to open to app                  | `.svg` | *Not applicable*     | None        | ✅        |
| `ChatBackground`              | Chat background                                           | `.svg` | *Not applicable*     | None        | ✅        |
| `PasscodeLogoCustomOnprem`    | Shown when entering passcode, usually same as app icon    | `.png` | 1024x1024            | None        | ✅        |
| `CustomOnPrem`                | Shown in navigation bars                                  | `.svg` | *Not applicable*     | Any, Dark   | ✅        |

#### App Icon
Check appearances in the attributes inspector.\
Path: `SharedResources/AppIcons/CustomOnPrem.xcassets`

| Name              | Description                                               | Type   | Size      | Appearances       | Mandatory |
| ----------------- | --------------------------------------------------------- | :----: | --------- | ----------------- | :-------: |
| `AppIcon-image`   | Shown in notification settings, usually same as app icon  | `.png` | 1024x1024 | None              | ✅        |
| `AppIcon`         | Icon of the app, cannot be referenced directly in app.    | `.png` | 1024x1024 | Any, Dark, Tinted | ✅        |

#### Launch screen
Path: `SharedResources/LaunchScreens/Images`

| Name                       | Description                       | Type   | Size   | Appearances | Mandatory |
| -------------------------- | --------------------------------- | :----: | ------ | ----------- | :-------: |
| `SplashScreenCustomOnPrem` | Used as logo on the launch screen | `.png` | 411×28 | None        | ✅        |


## Colors
Colors used at various places in the app. Colors below are the default for OnPrem.\
Path: `SharedResources/Colors/TargetColorsCustomOnPrem`

| Name                              | Description                                                  | Any       | Dark                         | Mandatory |
| --------------------------------- | ------------------------------------------------------------ | :-------: | :--------------------------: | :-------: |
| `AccentColorCustomOnPrem`         | Main color of the app                                        | `#C8342E` | `#C8342E`                    | ✅        |
| `ChatBubbleSent`                  | Background of message bubbles sent by the user               | `#FDE6E8` | `#212121`                    | ✅        |
| `ChatBubbleSentSelected`          | Background of _selected_ message bubbles sent by the user    | `#E89A98` | `#757575`                    | ✅        |
| `ProminentButtonTextCustomOnPrem` | Text color for the colored buttons                           | `#FFFFFF` | `#000000`                    | ✅        |
| `CircleButtonCustomOnPrem`        | Color of circle buttons (example: edit contact image)        | `#FCD6DA` | `#quaternarySystemFillColor` | ✅        |
| `SecondaryCustomOnPrem`           | Secondary color of the app                                   | `#FCDBDE` | `#323232`                    | ✅        |
