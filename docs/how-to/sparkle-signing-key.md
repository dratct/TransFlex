# Set Up The Sparkle Update Key

TransFlex updates itself with [Sparkle](https://sparkle-project.org). Every
update is signed with a private key, and the app only installs an update whose
signature matches the public key it ships with. This page makes that key pair
once and puts each half where it belongs. It takes about ten minutes.

## What The Two Keys Are

| | Private key | Public key |
| --- | --- | --- |
| What it does | Signs each release's zip; CI writes the signature into `appcast.xml`. | Checks that signature on the user's Mac. |
| Secret? | **Yes.** Treat it like the Developer ID certificate. | No. It ships inside the app. |
| Where it lives | Your Mac's login keychain, the `SPARKLE_ED_PRIVATE_KEY` repository secret, and a password-manager backup. | `SUPublicEDKey` in `project.yml`. |

The keys are Ed25519 (EdDSA), a different kind of key from the Developer ID
certificate, so the certificate cannot stand in for them.

Sparkle accepts an update when **either** the EdDSA signature is valid **or**
the new app is signed by the same Developer ID team as the installed one
(`SUUpdateValidator.m` in Sparkle 2.10.1). Having both lets you replace one if
the other is lost. It also means that someone who has the private key and can
get a fake appcast in front of users can ship them any app, even one that is
not signed with your Developer ID. Keep the private key secret.

## Before You Start

- Do this on your own Mac, in a Terminal window on its screen.
  - Not over SSH: `generate_keys` stores the key in the keychain, and macOS
    blocks that from an SSH session.
  - Not on a shared or AI-agent build machine: anything that can unlock that
    keychain can read the key.
- Check where you are: `hostname` should print your own Mac's name.
- Have a password manager open (the owner uses Proton Pass).
- You need write access to `dratct/TransFlex` to set a secret.

## 1. Download Sparkle's Tools

Use the same Sparkle version the project locks (see `project.yml`).

```bash
mkdir -p ~/sparkle-tools && \
cd ~/sparkle-tools && \
curl -LO https://github.com/sparkle-project/Sparkle/releases/download/2.10.1/Sparkle-2.10.1.tar.xz && \
tar -xf Sparkle-2.10.1.tar.xz && \
ls bin
```

The list must include `generate_keys`.

## 2. Make The Key Pair

```bash
cd ~/sparkle-tools && \
./bin/generate_keys --account transflex
```

- `--account transflex` names the keychain item, so this key stays apart from
  other apps' Sparkle keys.
- If macOS asks for keychain access, click **Allow**.
- The tool prints something like:

  ```xml
  <key>SUPublicEDKey</key>
  <string>AbCd...xyz=</string>
  ```

  The text inside `<string>` is the **public key**: 44 characters, ending in
  `=`. Copy it; you need it in step 6.

To print the public key again later:

```bash
./bin/generate_keys --account transflex -p
```

## 3. Export The Private Key To A Temporary File

```bash
cd ~/sparkle-tools && \
./bin/generate_keys --account transflex -x ~/sparkle_private.key
```

This file **is** the private key: one line of base64. Do not paste it into a
chat, an issue or a commit.

## 4. Store It As A Repository Secret

With the GitHub CLI:

```bash
gh secret set SPARKLE_ED_PRIVATE_KEY \
  -R dratct/TransFlex < ~/sparkle_private.key
```

Or on the web: **Settings → Secrets and variables → Actions → New repository
secret**, name `SPARKLE_ED_PRIVATE_KEY`, value the single line from
`cat ~/sparkle_private.key`.

Check that it is there (this shows names only, never values):

```bash
gh secret list -R dratct/TransFlex
```

## 5. Back It Up, Then Delete The File

1. In the password manager, create an item named
   **TransFlex – Sparkle EdDSA private key**.
2. Paste the private key into it, and the public key next to it for reference.
3. Delete the exported file:

   ```bash
   rm ~/sparkle_private.key
   ```

The key now lives in three places: your login keychain, the repository
secret, and the backup. That is enough.

## 6. Put The Public Key In The App

Set `SUPublicEDKey` in `project.yml` to the public key, regenerate the
project, and commit:

```bash
xcodegen generate
```

`scripts/verify-release-app.sh` fails a release build whose key is missing or
is not 44 characters of base64, and `scripts/make-appcast.sh` fails when the
private key does not match the app's public key.

## Troubleshooting

| Message | Fix |
| --- | --- |
| `The operating system has blocked access to the Keychain … over SSH` | Run it in a Terminal window on the Mac itself. |
| `Access denied` / `errSecAuthFailed` | In Keychain Access, lock the `login` keychain, unlock it again, rerun. |
| Item already exists | A key was made before with this account. Print it with `-p`. If it is a key you no longer use, delete "Private key for signing Sparkle updates" (account `transflex`) in Keychain Access and start over. |
| A release fails at "Create appcast" with a key mismatch | The secret does not belong to the public key in `project.yml`. Set the secret again from the backup. |

## If The Key Is Lost Or Leaked

Make a new key pair (steps 2–5), put the new public key in `project.yml`, and
release. Installed apps cannot check the new signature with the old key. They
accept the update because it carries the same Developer ID team signature, then
trust the new key from then on. This rests on the "either" rule above and has
not been rehearsed for TransFlex. A prerelease cannot rehearse it, because the
`latest` feed never serves one; build an old and a new version against a local
feed instead (`TRANSFLEX_UPDATE_FEED_URL`, see `scripts/build.sh`).

If both the key and the Developer ID team are lost, installed apps refuse
every later update, and users must download a new build by hand.
