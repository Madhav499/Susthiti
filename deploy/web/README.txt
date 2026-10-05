SUSTHITI public download site (Render Static Site)

Deploy settings:
  Root Directory: deploy/web
  Build Command: (empty)
  Publish Directory: .

Tracked files:
  index.html       — landing / download page
  SUSTHITI.apk     — Android release (served at ./SUSTHITI.apk)
  favicon.png, splash/ — branding assets

Flutter web build output (main.dart.js, canvaskit/, etc.) is generated locally and
gitignored; this folder is intentionally a lightweight download page, not the full web app.

To refresh the APK after a release build, copy the release APK here as SUSTHITI.apk and commit.
