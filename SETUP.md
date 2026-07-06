# FX Logistics — Backend Setup Guide

You now have 4 files. Here's what each does and the exact steps to wire them together.

| File | Purpose |
|---|---|
| `fx-logistics-website.html` | Public site — home, about, services, tracking, **Price Quote**, contact |
| `staff-login.html` | Staff portal — real Supabase login, shipment CRUD, enquiries list. Deploy this at `staff.fxlogistics.org` |
| `supabase-setup.sql` | Database schema — run once in Supabase |
| `send-quote-email.ts` | Edge Function — emails you when someone submits a quote or contact form |

---

## 1. Run the database schema

1. Open your Supabase project → **SQL Editor** → **New query**.
2. Paste in the entire contents of `supabase-setup.sql` and click **Run**.
3. This creates three tables (`shipments`, `shipment_updates`, `quote_requests`), sets up permissions (Row Level Security), and seeds 3 sample shipments so you can test tracking immediately (`FX82619614`, `FX40213877`, `FX55927301`).

## 2. Get your API keys and fill them into both HTML files

1. In Supabase, go to **Project Settings → API**.
2. Copy the **Project URL** and the **anon / public key**.
3. In both `fx-logistics-website.html` and `staff-login.html`, find these two lines near the bottom and replace the placeholders:
   ```js
   const SUPABASE_URL = 'YOUR_SUPABASE_URL';
   const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY';
   ```

⚠️ Only ever use the **anon/public** key in these files, never the `service_role` key — the anon key is safe to expose in a browser because the database permissions (RLS policies) do the real access control.

## 3. Create staff login accounts

1. In Supabase, go to **Authentication → Users → Add user**.
2. Create one user per staff member (email + password). No public sign-up page exists — accounts are created by you only.
3. Staff log in at `staff-login.html` with those credentials.

## 4. Get quote/contact enquiries emailed to you

This uses a free email API called **Resend** (resend.com) plus a Supabase Edge Function.

1. Sign up at resend.com and grab an API key. For real delivery (not just their test inbox), verify your own sending domain in Resend — otherwise you can test using their shared `onboarding@resend.dev` sender.
2. Install the Supabase CLI if you haven't: `npm install -g supabase`
3. From your project folder:
   ```bash
   supabase login
   supabase link --project-ref YOUR_PROJECT_REF
   supabase functions deploy send-quote-email
   supabase secrets set RESEND_API_KEY=your_resend_key
   supabase secrets set QUOTE_NOTIFY_EMAIL=info@fxlogistics.org
   supabase secrets set QUOTE_FROM_EMAIL="FX Logistics Website <quotes@yourdomain.com>"
   ```
   (Put `send-quote-email.ts` inside `supabase/functions/send-quote-email/index.ts` in your local project before deploying.)
4. Back in the Supabase Dashboard → **Database → Webhooks → Create a new webhook**:
   - Table: `quote_requests`
   - Event: `Insert`
   - Type: **Supabase Edge Functions**
   - Function: `send-quote-email`
5. Test it: submit the Price Quote form on the live site — you should get an email within a few seconds.

## 5. Put the staff portal on staff.fxlogistics.org

1. Host `staff-login.html` anywhere that serves static files (the same host as your main site, or something like Netlify/Vercel — since Vercel is already connected here, just say the word and I'll deploy it there for you).
2. At your domain registrar / DNS provider, add a **CNAME** record: `staff` → wherever the file is hosted (or an **A record** if your host gives you an IP instead).
3. Once DNS propagates, `staff.fxlogistics.org` opens the login screen directly.

## 6. About the compromised main domain

fxlogistics.org currently has a large number of spammy "hacklink" pages injected into it (visible when fetching pages like `/get-a-quote-2/`). That's a sign the WordPress install has been compromised. Worth flagging to your hosting provider and changing your WordPress admin password, before or alongside launching this new site.

---

### What's already working without any setup
Nothing — the site needs steps 1–2 done at minimum (schema + API keys) before tracking, quote requests, or staff login will function. Everything else (design, copy, layout) is ready as-is.
