# AskMario Commissions

Track projects and the commission each person earns on them.
SvelteKit + Supabase, hosted on Vercel.

## How commission works

```
Commission pool = project price × commission %
Person payout   = pool × person's split %   (splits must total 100%)
```

Example: R100,000 at 10% = R10,000 pool, split 50/50 = R5,000 each.

**Overdue rule:** a project finished after its deadline (or still open past it) earns **R0**.
An admin can tick *Waive overdue rule* on a project when the delay wasn't our fault.
Every deadline change is logged on the project page.

Statuses: Lead → Active → Completed → Paid (plus On hold and Cancelled).
Marking a project Completed or Paid fills in the completed date automatically.

## Access

- Sign in with Google. Only `@askmario.co.za` accounts are accepted (the database enforces this).
- New users are **pending** until approved (see step 4).
- **Admins** see and edit every project and can delete projects or waive the overdue rule.
- **Members** can create projects and edit any project they're on or created.
  They see the full split and every payout on those projects.

---

## Setup

### 1. Run the database migration

Supabase dashboard → **SQL Editor** → New query → paste `supabase/migrations/001_init.sql` → **Run**.

### 2. Turn on Google sign-in

1. In **Google Cloud Console** → APIs & Services → Credentials, open your OAuth client (type *Web application*).
   Add this **Authorised redirect URI**:
   `https://<your-project-ref>.supabase.co/auth/v1/callback`
   (Tip: set the OAuth consent screen to **Internal** if askmario.co.za is a Google Workspace. Then only your domain can sign in.)
2. In Supabase → **Authentication → Sign In / Providers → Google**, enable it and paste the Client ID and Secret.

### 3. Run it locally

```bash
cp .env.example .env
```

Fill in `.env` from Supabase → **Project Settings → API**: the Project URL and the anon/publishable key.

```bash
npm install
```

```bash
npm run dev
```

In Supabase → **Authentication → URL Configuration**, add `http://localhost:5173/auth/callback` to **Redirect URLs**.

### 4. Approve users and make yourself admin

Sign in once so your profile row exists. Then in the Supabase SQL Editor run:

```sql
update profiles set approved = true, role = 'admin' where email = 'you@askmario.co.za';
```

To approve colleagues later, go to **Table Editor → profiles** and tick `approved` on their row.
You can also run `update profiles set approved = true where email = '...';`.

### 5. Deploy to Vercel and connect Supabase

1. Push this folder to a GitHub repo. In Vercel click **Add New → Project** and import it. The framework preset is detected as SvelteKit.
2. Add environment variables. Pick one of these two options:
   - **Option A: Vercel's Supabase integration.** Go to Vercel → your project → **Integrations/Storage → Supabase → Connect** and link your existing Supabase project.
     It creates `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY`. This app expects `PUBLIC_…` names,
     so also add the two variables below with the same values.
   - **Option B: manual (simplest).** Go to Vercel → Project → **Settings → Environment Variables** and add these for Production, Preview and Development:
     - `PUBLIC_SUPABASE_URL` = `https://<ref>.supabase.co`
     - `PUBLIC_SUPABASE_ANON_KEY` = your anon/publishable key
3. Deploy. Your URL will look like `https://coms-app.vercel.app`.
4. Go back to Supabase → **Authentication → URL Configuration**:
   - **Site URL:** `https://coms-app.vercel.app`
   - **Redirect URLs:** add `https://coms-app.vercel.app/auth/callback`.
     Also add `https://*-<your-vercel-team>.vercel.app/auth/callback` if you want preview deploys to log in.

You don't need to change anything in Google for step 5. Google only ever redirects to Supabase, and Supabase redirects to Vercel.

## Project structure

```
supabase/migrations/001_init.sql   tables, RLS, commission views, save_project()
src/hooks.server.ts                Supabase client + login/approval guard
src/routes/+page.svelte            dashboard: pipeline + total payout per person
src/routes/projects/…              create / edit project with live split calculator
src/lib/components/ProjectForm     the project + split form
```
