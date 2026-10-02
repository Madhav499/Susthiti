# Putting SUSTHITI on the internet

After this, any phone can use SUSTHITI on any Wi-Fi or mobile data — no cable, and your PC can be
off. The backend, the diabetes model and the web app run on a small Linux server with HTTPS:

```
Android app (SUSTHITI.apk) ─┐
iPhone / computer (browser) ─┼─ https://YOUR-DOMAIN ─► Caddy (HTTPS) ─► backend ─► diabetes model
                             │                           └─► web app      └─► database + reports (volume)
```

Only Caddy is reachable from the internet. The backend and the model service are private to the
server. Everything below is done once; updating later is step 8.

---

## 1. Get a server

Any Linux server with a public IP address, Ubuntu 22.04 or 24.04, **2 GB RAM** recommended. For example:

- **Oracle Cloud "Always Free"** — an Ampere (ARM) VM costs nothing (sign-up asks for a card to verify you).
- **DigitalOcean, Hetzner, AWS Lightsail**, or any VPS — about $4–6 a month.

In the provider's firewall (Oracle: *Security List* of the VCN; others: *Firewall*), allow incoming
**TCP 80 and TCP 443**. Keep SSH (22) open for yourself.

> **Oracle Ubuntu images** also block ports inside the VM. On the server, run:
> `sudo iptables -I INPUT 6 -p tcp -m multiport --dports 80,443 -j ACCEPT && sudo netfilter-persistent save`

## 2. Give it a name

HTTPS needs a name, not a bare IP address. Either:

- **Your own domain:** add an `A` record pointing to the server's IP, e.g. `susthiti.example.com`.
- **Free, no sign-up:** use the IP with dashes plus `.sslip.io`. For IP `203.0.113.10` the name is
  `203-0-113-10.sslip.io`. It already points at your server.

Below, `YOUR-DOMAIN` means this name.

## 3. Install Docker on the server

Connect from Windows (PowerShell): `ssh ubuntu@SERVER-IP` (Oracle's user is `ubuntu`; others often `root`). Then:

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
exit
```

Connect again so the Docker permission applies.

## 4. On your PC: build the app for your server

In `D:\susthiti`:

```bat
scripts\build-release.bat https://YOUR-DOMAIN
scripts\package-server.bat
```

This makes:

- `release\SUSTHITI.apk` — the Android app for almost all phones (`SUSTHITI-older-phones.apk` only for very old 32-bit phones).
- `deploy\web` — the web app for iPhones and computers.
- `release\susthiti-server.tar.gz` — everything the server needs. No local database, reports, passwords or `.env` files are included.

The app only talks HTTPS; the build refuses an `http://` address.

## 5. Upload and start

From your PC:

```bat
scp release\susthiti-server.tar.gz ubuntu@SERVER-IP:~
```

On the server:

```bash
tar -xzf susthiti-server.tar.gz
cd susthiti/deploy
cp .env.example .env
openssl rand -base64 48        # copy the output for JWT_SECRET
nano .env                      # set DOMAIN=YOUR-DOMAIN and JWT_SECRET=...; GEMINI_API_KEY is optional
docker compose up -d --build   # first build takes a few minutes
docker compose ps              # all three should be "running" / "healthy"
curl https://YOUR-DOMAIN/health
```

`/health` should answer `{"status":"ok", ..., "model_service":"ok"}`. Caddy gets the HTTPS
certificate automatically the first time (needs step 1's ports and step 2's name to be right).

## 6. Create the first admin

```bash
docker compose exec backend python -m app.cli create-admin --email you@example.com --name "Your Name"
```

It asks for a password (at least 8 characters with a letter and a number). Sign in with it in the
app; the admin creates doctor accounts. Patients register themselves in the app.

Demo accounts and demo data are **refused** on the server — it holds real people's data only.

## 7. Put SUSTHITI on phones

- **Android:** send `release\SUSTHITI.apk` (WhatsApp, Google Drive, email or USB). On the phone,
  open it and allow *Install unknown apps* for the app you opened it from. Play Protect may say the
  developer is unknown — choose *Install anyway*. Then *Create a patient account*.
- **iPhone, tablet or computer:** open `https://YOUR-DOMAIN` in Safari/Chrome. On iPhone, *Share → Add to Home Screen*.
- **Smartwatch data** works as before in the Android app (Lifestyle → Connect, via Health Connect).

## 8. Updating

1. On your PC: if the app changed, run `scripts\build-release.bat https://YOUR-DOMAIN` again; then `scripts\package-server.bat`.
2. Upload as in step 5, then on the server:

```bash
tar -xzf susthiti-server.tar.gz      # replaces the code; your .env and data are kept
cd susthiti/deploy && docker compose up -d --build
```

3. Send the new `SUSTHITI.apk`; installing it over the old one keeps each person's sign-in.

The APK is signed with a key stored on **this PC** (Android's debug key). Build updates on the same
PC, or phones will refuse the update until the old app is uninstalled. Publishing on Google Play
needs a proper release key first.

## 9. Backups — do this regularly

The database and uploaded reports are in the Docker volume `susthiti_susthiti-data`. On the server:

```bash
cd ~/susthiti/deploy
docker compose stop backend
docker run --rm -v susthiti_susthiti-data:/data -v "$PWD":/backup alpine tar czf /backup/susthiti-data-$(date +%F).tar.gz -C /data .
docker compose start backend
```

Copy the file to your PC (`scp ubuntu@SERVER-IP:~/susthiti/deploy/susthiti-data-*.tar.gz .`).
To restore: stop the backend, extract the backup into the volume the same way (`tar xzf` instead of
`czf`), start it again.

## 10. When something is wrong

| Symptom | Check |
|---|---|
| App says *Can't reach SUSTHITI's server* | Open `https://YOUR-DOMAIN/health` in the phone's browser. |
| No HTTPS / certificate error | `docker compose logs caddy` — usually the name doesn't point at the server yet, or ports 80/443 are closed (step 1). |
| *Assessment service unavailable* | `docker compose ps` — is `model` healthy? `docker compose logs model`. |
| Anything else | `docker compose logs -f backend` |

---

## Security — what is in place, and what is yours

Already done:

- HTTPS only; release apps refuse plain HTTP.
- The server refuses to start with a weak `JWT_SECRET`, demo accounts, demo data or development password-reset tokens.
- Sign-in, registration and password reset are limited per visitor (20 sign-ins per 5 minutes, 20 registrations per hour, 10 password resets per hour).
- API documentation pages are hidden; the backend and model service can't be reached directly.
- Containers run as non-root users.

Your part:

- Keep the server updated (`sudo apt update && sudo apt upgrade`; `docker compose pull caddy && docker compose up -d`).
- Back up (step 9) and keep `deploy/.env` private — anyone with `JWT_SECRET` could forge sign-ins.
- This is real health data: get patients' consent and follow the law that applies to you (in India, the DPDP Act 2023).

Not included yet:

- **Password-reset emails.** No email service is connected, so *Forgot password* can't deliver a
  reset link on the server. Adding an email provider (for example SMTP or a service like Brevo) is
  the next step if people will need it.
- **Large scale.** One server with SQLite suits a pilot or class project (hundreds of users). Many
  thousands of users would need PostgreSQL and file storage outside the server.

Local development (`start-susthiti.bat`, the emulator, USB phones) is unchanged.
