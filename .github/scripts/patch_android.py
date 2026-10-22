"""Prepares the generated Android project for notifications, step counting and biometric lock.
Run from the repo root after `flutter create`. Safe to run more than once."""
import glob
import os
import re

app = "android/app"
man_path = f"{app}/src/main/AndroidManifest.xml"
man = open(man_path, encoding="utf-8").read()

perms = [
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.RECEIVE_BOOT_COMPLETED",
    "android.permission.VIBRATE",
    "android.permission.ACTIVITY_RECOGNITION",
    "android.permission.USE_BIOMETRIC",
]
add = "".join(f'    <uses-permission android:name="{p}" />\n' for p in perms if p not in man)
if add:
    man = man.replace("<application", add + "    <application", 1)

receivers = """        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON" />
            </intent-filter>
        </receiver>
"""
if "ScheduledNotificationReceiver" not in man:
    man = man.replace("</application>", receivers + "    </application>", 1)
open(man_path, "w", encoding="utf-8").write(man)

# local_auth needs a FragmentActivity.
for f in glob.glob(f"{app}/src/main/**/MainActivity.kt", recursive=True):
    s = open(f, encoding="utf-8").read()
    s = s.replace("import io.flutter.embedding.android.FlutterActivity", "import io.flutter.embedding.android.FlutterFragmentActivity")
    s = re.sub(r"\bFlutterActivity\(\)", "FlutterFragmentActivity()", s)
    open(f, "w", encoding="utf-8").write(s)
    print("patched", f)

# local_auth needs an AppCompat based launch theme.
for f in glob.glob(f"{app}/src/main/res/values*/styles.xml"):
    s = open(f, encoding="utf-8").read()
    s = re.sub(r'(<style name="(?:LaunchTheme|NormalTheme)" parent=")[^"]*(")', r"\1Theme.AppCompat.DayNight.NoActionBar\2", s)
    open(f, "w", encoding="utf-8").write(s)
    print("patched", f)

# Core library desugaring for scheduled notifications, and AppCompat for the biometric dialog.
kts = f"{app}/build.gradle.kts"
groovy = f"{app}/build.gradle"
if os.path.exists(kts):
    s = open(kts, encoding="utf-8").read()
    if "isCoreLibraryDesugaringEnabled" not in s:
        s = s.replace("compileOptions {", "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", 1)
    if "desugar_jdk_libs" not in s:
        s += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n    implementation("androidx.appcompat:appcompat:1.7.0")\n}\n'
    open(kts, "w", encoding="utf-8").write(s)
    print("patched", kts)
else:
    s = open(groovy, encoding="utf-8").read()
    if "coreLibraryDesugaringEnabled" not in s:
        s = s.replace("compileOptions {", "compileOptions {\n        coreLibraryDesugaringEnabled true", 1)
    if "desugar_jdk_libs" not in s:
        s += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n    implementation 'androidx.appcompat:appcompat:1.7.0'\n}\n"
    open(groovy, "w", encoding="utf-8").write(s)
    print("patched", groovy)
