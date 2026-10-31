# Data safety form answers for PureBurn

These match how the app works today (accounts, cloud sync, challenges and the AI coach exist). If you add another feature that sends data anywhere (ads, analytics, crash reports, a new server), update this file and the privacy policy (site/privacy.html) first, then answer the Play form again before releasing.

## Top-level questions

| Question in Play Console | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | Yes |
| Is all of the user data collected by your app encrypted in transit? | Yes (HTTPS to Firebase, Cloudflare and Google) |
| Do you provide a way for users to request that their data is deleted? | Yes. In the app: Account, then "Delete my account". On the web: https://usamatech1.github.io/pureburn/delete-account.html (enter this as the account deletion URL in Play Console). |
| Can users create an account in the app? | Yes (email and password, or Google). Accounts are optional. |

## Data types to declare

Collection is **optional** for every type below: the app works without an account, and data only leaves the device after the user signs in or asks the coach a question.

| Data type (Play category) | What it is in PureBurn | Collected | Shared | Purpose |
|---|---|---|---|---|
| Personal info: Email address | Account email | Yes | No | Account management |
| Personal info: User IDs | Firebase account ID | Yes | No | Account management, app functionality |
| Personal info: Name | Optional display name in challenges (up to 20 characters, visible to other signed-in users) | Yes | No | App functionality |
| Health and fitness: Health info | Weight, height, sleep, optional blood sugar and blood pressure readings, diet type and allergies, synced backup and coach context | Yes | See note below | App functionality |
| Health and fitness: Fitness info | Exercise, workouts, steps, water, goals | Yes | See note below | App functionality |
| Messages / App activity: Other user-generated content | Questions typed into the AI coach (not stored by us, sent for processing) | Yes (processed, not stored) | See note below | App functionality |

Not collected: location, contacts, photos or files, financial info, device identifiers for ads, browsing history, crash logs, analytics.

**Note on "shared".** Firebase (Google) and Cloudflare act as service providers that process data for us, which Play does not count as sharing. The AI coach passes the question and a data summary to Google's Gemini API. If that API is used on the free tier, Google's terms may let it use requests to improve its own products, and Play can then treat this as sharing with a third party. The safe choice is to declare Health info, Fitness info and the coach questions as **shared with a third party** (purpose: App functionality). Check the current Gemini API terms at https://ai.google.dev/gemini-api/terms before you answer, and if you move the coach to a paid Gemini plan with no training on your data, you can change the answer to "not shared".

## Other questions

| Question | Answer |
|---|---|
| Does the app use third-party SDKs that collect data? | Firebase (REST calls) and Google Sign-In are used for accounts. No ads, analytics or tracking SDKs. |
| Is the data processed ephemerally? | Coach questions: yes. Synced backup: no, it is stored until the user's account is deleted. |
| Does the app follow the Families policy? | Not applicable. Target audience is 18 and over. |

## Still to do before you submit

- Test the "Delete my account" button on a real test account before you submit: sign up, sync, join a challenge, then delete, and check in the Firebase console that the user and the `users/{uid}/sync/state` document are gone.
- The "Health apps" declaration in Play Console may also apply, because the app reads Health Connect data. Answer it honestly.

## What stays on the device only

The app lock PIN, biometric setting and reminders are stored on the phone only and are not part of the cloud backup.
