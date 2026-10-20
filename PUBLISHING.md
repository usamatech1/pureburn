# Publishing PureBurn on Google Play

Everything the app needs is already prepared in this repo. This file lists what is left for you to do on the Google side, in order.

## What is already done

- Every push to `main` builds the web app (GitHub Pages), an installable APK and a Google Play App Bundle (.aab). Both Android files are published at the link below and are signed with the permanent key.
  - APK: https://github.com/usamatech1/pureburn/releases/latest/download/PureBurn.apk
  - AAB for Play: https://github.com/usamatech1/pureburn/releases/latest/download/PureBurn.aab
- The build number goes up by itself on every build, as Play requires.
- App name (PureBurn), icons, feature graphic and the 512 px store icon are ready (see `platform_overrides/` and `play-store/assets/`).
- Privacy policy page: https://usamatech1.github.io/pureburn/privacy.html
- Store listing text and form answers: `play-store/listing.md` and `play-store/DATA-SAFETY.md`.

## Your steps on Google Play

1. **Create a Play Console developer account** at https://play.google.com/console (one-time registration fee and identity verification). Use an account you will keep for good.
2. **Create the app** in Play Console. Name: PureBurn: BMI, Diet & Workout. Default language English. App (not game), Free.
3. **Fill the store listing** and App content forms by copying from `play-store/listing.md` and `play-store/DATA-SAFETY.md`. Add at least 2 phone screenshots from the real app.
4. **Turn on Play App Signing** when you upload the first release (Play asks). The key in this repo's secrets (`ANDROID_KEYSTORE_BASE64` and friends) becomes your upload key. Keep `pureburn-release.jks` backed up.
5. **Upload the .aab** (download PureBurn.aab from the release link above) to a Closed testing release.
6. **Closed test.** Google's current rule for new personal developer accounts is a closed test with at least 12 testers who stay opted in for 14 days in a row, before you can apply for production. Check https://support.google.com/googleplay/android-developer/answer/14151465 for the latest wording, because Google changes these rules.
7. **Apply for production access** in Play Console after the test, then create the Production release with a newer .aab.

## The package name (application ID)

The app ID is `com.pureburn.pureburn`, built from `--org com.pureburn` and `--project-name pureburn` in `.github/workflows/apk.yml`.

- Before your first upload to Play you can change it by editing `--org` in that workflow. Choose it carefully.
- After your first upload to Play it can never change.
- Changing it makes Android treat the app as a different app, so a phone with the current APK would need the old one uninstalled.

## Updating the app after launch

Just keep adding features and push to `main`. Each build produces a new `PureBurn.aab` with a higher build number. Download it from the release link and upload it as a new release in Play Console. When you want a visible version name for users, change `version:` in `pubspec.yaml` (for example `1.1.0+1`, the part after `+` is ignored because the build number comes from the workflow).

## Optional: upload to Play from GitHub

`.github/workflows/play-upload.yml` can send the latest .aab to Play for you. It only runs when you start it by hand and needs a Google Cloud service account added as the secret `PLAY_SERVICE_ACCOUNT_JSON`. It cannot create the app or the very first release, so do steps 1 to 5 above by hand first. It has not been tested yet, because there is no Play account to test it on.

## Keep these safe

- `pureburn-release.jks` and the passwords (given to you separately).
- Your Play Console login.

## If you add features that collect data

If PureBurn ever adds login, cloud backup, ads, analytics or anything that sends data off the phone, update `site/privacy.html` and `play-store/DATA-SAFETY.md` first, and redo the Data safety form in Play Console.
