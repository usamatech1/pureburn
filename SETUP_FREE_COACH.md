# Free AI coach (no credit card): Cloudflare Worker + free Gemini key

Challenges already run free on Firebase's free plan. This guide makes the AI coach free too.
Limits: about 400 coach questions a day for all users together, and 8 per person per day.
Google may use free-tier Gemini chats to improve its products, so the app tells users not to share private details.

1. Free Gemini key: https://aistudio.google.com/apikey > Create API key.
2. Free Cloudflare account: https://dash.cloudflare.com/sign-up
3. Workers & Pages > Create > Create Worker > name `pureburn-coach` > Deploy > Edit code.
   Replace all code with `worker/coach.js` from this repo, then Deploy.
4. Storage & Databases > KV > Create namespace `pureburn-limits`.
   Worker > Settings > Bindings > Add > KV namespace: variable name `LIMITS`, pick `pureburn-limits`.
5. Worker > Settings > Variables and Secrets > Add:
   - `GEMINI_API_KEY` (type Secret) = your Gemini key
   - `FB_API_KEY` (type Text) = the Firebase web apiKey
6. Copy the Worker address (like `https://pureburn-coach.<you>.workers.dev`).
7. GitHub repo Settings > Secrets and variables > Actions > Variables > New: `COACH_URL` = that address.
   Run the web and APK builds again.
