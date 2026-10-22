# Phase 3 setup: accounts, sync, challenges and AI coach

The app works fine without any of this. These steps switch on the cloud features.
You do them once, in your own accounts (I cannot create accounts or enter keys for you).

## 1. Create a Firebase project (free Spark plan is enough for login, sync and challenges)
1. Go to https://console.firebase.google.com and click **Add project**. Name it `pureburn`.
2. **Build > Authentication > Get started > Email/Password > Enable.**
3. **Build > Firestore Database > Create database** (production mode, any region near you).
4. In Firestore open the **Rules** tab, paste the contents of `firestore.rules`, and **Publish**.
5. **Project settings (gear) > General > Your apps > Web app (</>)**. Register an app and copy the `apiKey`
   and the **Project ID**. These two values are public identifiers, not secrets.

## 2. Give the two values to the build
In GitHub: repo **Settings > Secrets and variables > Actions > Variables tab > New repository variable**:
- `FB_API_KEY` = your apiKey
- `FB_PROJECT` = your project ID
- `FB_REGION` = `us-central1` (only change it if you deploy the function elsewhere)

Then push any change (or re-run the workflows). Web, APK and AAB are built with the cloud switched on.

## 3. Turn on the AI coach (needs the Blaze pay-as-you-go plan)
Cloud Functions require the Blaze plan. Each coach question costs a fraction of a cent, and the function
limits every user to 20 questions a day.
```
npm install -g firebase-tools
firebase login
firebase use <your-project-id>
firebase functions:secrets:set ANTHROPIC_API_KEY     # paste your key from console.anthropic.com
firebase deploy --only functions,firestore:rules
```
Without this step the coach still answers simple questions from your plan, offline.

## 4. Test
Open the app > **Account and sync** > create an account > sync. Sign in on a second phone with the same
email and your data appears. Open **Challenges** to join a weekly challenge, and **AI coach** to chat.

## Not built yet
Premium plan and ads, and the sugar / blood pressure modes (these need medical review and disclaimers).
