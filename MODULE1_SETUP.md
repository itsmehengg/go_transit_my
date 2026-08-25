# Module 1 - User Account & Personalisation Setup

Module 1 uses **Supabase** for authentication/profile data and **SharedPreferences** for device personalisation data.

## Implemented functions

- Register with email/password
- Email confirmation handling
- Login and logout
- Forgot password email
- In-app new password screen through a recovery deep link
- View and edit profile name/phone
- Upload profile photo to Supabase Storage
- Favourite stations: add/remove/persist
- Favourite routes: add/remove/persist
- Recent searches: persistent list service and clear history screen
- Preferred transport preference service/screen
- Notification preference
- Language preference
- Dark mode with persistence
- Help/About screen

## Required Supabase setting for Forgot Password

In Supabase Dashboard:

1. Open **Authentication -> URL Configuration**.
2. Under **Redirect URLs**, add:

   `gotransitmy://reset-password`

3. Save the configuration.

The Android deep-link intent filter is already included in `AndroidManifest.xml`.

## Existing Supabase resources required by Profile

The current project already expects:

- Table: `app_users`
- Columns used: `id`, `full_name`, `email`, `phone`, `membership_tier`, `avatar_path`
- Storage bucket: `avatars`

If profile editing/photo upload worked before this branch, no extra database work is needed.

## Run after pulling this branch

```bash
git checkout feature/module1-complete
git pull origin feature/module1-complete
flutter clean
flutter pub get
flutter run
```

## Module 1 smoke test

1. Register a new account.
2. Confirm the email if Supabase email confirmation is enabled.
3. Login.
4. Open Profile and edit name/phone.
5. Upload a profile photo.
6. Add/remove favourite stations and routes.
7. Change notification, language and dark-mode preferences; restart the app and confirm they persist.
8. Logout and login again.
9. Use Forgot Password, open the email recovery link on the Android device, set a new password, then login using the new password.
