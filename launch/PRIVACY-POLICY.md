# InjectBuddy iOS — Privacy Policy (hostable)

This is the privacy policy for the InjectBuddy iOS app. It **must be reachable at a public URL**
before App Store submission (App Store Connect requires a Privacy Policy URL).

**Recommended hosting:** publish at `https://www.injectbuddy.com/app-privacy/` (a dedicated app
policy) or extend the existing `https://www.injectbuddy.com/privacy/` page with an app section.
The existing web policy states "no accounts, no data collected" — which is true of the *website* but
**not** of the app (the app has accounts and stores protocols). Do not point the app's privacy URL
at the existing web policy unchanged; host this version, or merge clearly-labelled "Website" vs
"iOS App" sections. <<CONFIRM: final hosted URL.>>

Fill every `<<CONFIRM: …>>` before publishing. The text below is the publishable body.

---

# Privacy Policy — InjectBuddy iOS App

**Last updated:** <<CONFIRM: effective date, e.g. June 2026>>

InjectBuddy is a dosage and cycle calculator app for TRT, peptide and GLP-1 protocols, built and
operated by <<CONFIRM: legal entity / individual name — web policy uses "Pouroa Frew, Auckland,
New Zealand">> ("we", "us"). This policy explains what the **iOS app** collects, how it is used, and
your choices. It is separate from the injectbuddy.com website policy.

## Summary

- We collect only what is needed to run your account and sync your data: your email, an account ID,
  and the protocols, cycles and dose logs you choose to save.
- We do **not** sell your data. We do **not** track you across other apps or websites. The app
  contains **no advertising and no analytics tracking SDK**.
- Your dose calculations run **on your device**. Your inputs are only sent to our servers if you
  choose to *save* a protocol, cycle or dose log to your account.

## What we collect

When you create an account and use the app, we store:

- **Email address** — used to create and sign you in to your account (via our authentication
  provider). If you sign in with Discord, we receive the email associated with that login.
- **Account identifier** — a unique user ID that owns your data.
- **Display name** — optional, if you set one.
- **Your saved content** — the protocols you save (calculator type, label, compound/dose/
  concentration values, start date), cycles and cycle items you plan, and your dose log (dates you
  marked a dose as taken, draw volume, and injection site if you record it).

We do **not** collect: your real name (unless you type it as a display name), phone number, physical
address, payment information, precise location, contacts, photos, advertising identifiers, or device
usage/diagnostics analytics.

## What we do NOT do

- We do not include any third-party **analytics** or **advertising** SDK in the iOS app.
- We do not use your data for **tracking** as defined by Apple (no cross-app/website tracking; we do
  not show the App Tracking Transparency prompt because we do not track).
- We do not **sell** or rent your personal data to anyone.

## On-device calculations

All calculator math runs locally on your device. The numbers you type into a calculator are used to
compute your result on-device. They are transmitted to our servers **only** when you explicitly save
a protocol, cycle or dose to your account so it can sync across your devices.

## Service providers (processors)

- **Supabase** — our backend and authentication provider. Supabase stores your account, profile,
  saved protocols, cycles and dose log on our behalf, under our instructions, with row-level
  security so you can only access your own data. Supabase acts as a data processor.
  <<CONFIRM: link to Supabase's privacy/DPA, e.g. https://supabase.com/privacy>>
- **Discord** (optional) — only if you choose "Continue with Discord" to sign in; Discord provides
  your email for authentication. Governed by Discord's own privacy policy.

We use no other third parties to process your app data.

## Data retention

We retain your account data for as long as your account exists. Saved protocols, cycles and dose
logs are kept until you delete them or delete your account. <<CONFIRM: any backup retention window,
e.g. encrypted backups purged within 30 days.>>

## Deleting your account and data

You can delete your account at any time from **Settings → Delete account** in the app. Deleting your
account removes your profile, saved protocols, cycles and dose log from our systems. You may also
delete individual protocols or dose-log entries without deleting your account. To request deletion by
email, contact <<CONFIRM: support@injectbuddy.com>>.

## Children

The app is not directed at children under 13 (or the minimum age in your jurisdiction). We do not
knowingly collect data from children under 13.

## Security

Data in transit is encrypted with standard TLS. Access to your stored data is restricted to your own
account via row-level security. No method of storage or transmission is 100% secure, but we take
reasonable measures to protect your information.

## Changes to this policy

We may update this policy; the "Last updated" date will change. Material changes will be reflected
here at the policy URL.

## Contact

Questions about this policy: <<CONFIRM: support@injectbuddy.com — confirm this inbox exists and is
monitored>>.

## Governing law

This policy is governed by the laws of <<CONFIRM: jurisdiction — web footer is "Auckland, NZ", so
likely New Zealand>>.

---

## Medical disclaimer

**InjectBuddy is an informational maths tool, not medical advice.** All calculations are provided
for informational purposes only. The app converts numbers you already have (such as vial
concentration, BAC water volume and a target dose) into a draw volume; it does **not** determine
what your dose, frequency or medication should be.

Prescription medications — including testosterone — must be used in accordance with the instructions
of a licensed prescriber. Your prescribed dose, injection frequency and vial concentration should
come from your doctor's prescription. If there is any discrepancy between a result shown by
InjectBuddy and what your doctor or pharmacist has told you, **follow your medical professional's
instruction** and contact them to clarify. InjectBuddy and its operator are not liable for decisions
made on the basis of the app's calculations. Always verify with your prescriber.
