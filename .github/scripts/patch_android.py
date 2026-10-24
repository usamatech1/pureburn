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
    "android.permission.health.READ_STEPS",
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
# Health Connect: the app must be visible to it and answer its permission rationale request.
if "com.google.android.apps.healthdata" not in man:
    q = '        <package android:name="com.google.android.apps.healthdata" />\n        <intent><action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" /></intent>\n'
    if "<queries>" in man:
        man = man.replace("<queries>", "<queries>\n" + q, 1)
    else:
        man = man.replace("<application", "<queries>\n" + q + "    </queries>\n    <application", 1)
if "ACTION_SHOW_PERMISSIONS_RATIONALE\" />\n            </intent-filter>" not in man:
    rationale = """            <intent-filter>
                <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />
            </intent-filter>
"""
    man = man.replace("</activity>", rationale + "        </activity>", 1)
if "ViewPermissionUsageActivity" not in man:
    alias = """        <activity-alias android:name="ViewPermissionUsageActivity" android:exported="true" android:targetActivity=".MainActivity" android:permission="android.permission.START_VIEW_PERMISSION_USAGE">
            <intent-filter>
                <action android:name="android.intent.action.VIEW_PERMISSION_USAGE" />
                <category android:name="android.intent.category.HEALTH_PERMISSIONS" />
            </intent-filter>
        </activity-alias>
"""
    man = man.replace("</application>", alias + "    </application>", 1)
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

# The health plugin needs Android 8 (API 26) or newer.
for gf in (kts, groovy):
    if os.path.exists(gf):
        t = open(gf, encoding="utf-8").read()
        t2 = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 26", t)
        t2 = re.sub(r"minSdkVersion\s+flutter\.minSdkVersion", "minSdkVersion 26", t2)
        if t2 != t:
            open(gf, "w", encoding="utf-8").write(t2)
            print("minSdk 26 in", gf)
