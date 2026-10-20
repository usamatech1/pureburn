# PureBurn (Flutter)

Black and white BMI, goal, daily exercise and Pakistani diet tracker. Data is stored on the device with shared_preferences.

## Download and use

- Web app: https://usamatech1.github.io/pureburn/
- Android APK: https://github.com/usamatech1/pureburn/releases/latest/download/PureBurn.apk

- Google Play bundle (.aab): https://github.com/usamatech1/pureburn/releases/latest/download/PureBurn.aab
- Privacy policy: https://usamatech1.github.io/pureburn/privacy.html

All of these are rebuilt automatically every time code is pushed to `main`, so they always match the latest version. To publish on Google Play later, follow [PUBLISHING.md](PUBLISHING.md).

## Run
```
flutter create . --platforms=web,android,ios   # adds the platform folders once
flutter pub get
flutter run -d chrome
```

## Build for the web and put it on Netlify
```
flutter build web --release
```
Then open https://app.netlify.com/drop and drag the folder `build/web` onto the page.
You get a public link like https://something.netlify.app.

Needs Flutter 3.22 or newer (Dart 3.3+).
