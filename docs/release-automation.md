# Aevium release automation

This repo is set up for a Sparkle-based update flow:

1. The app launches and starts Sparkle.
2. Sparkle performs a background check on launch.
3. A GitHub Actions release workflow builds an unsigned standalone app, creates GitHub Release artifacts, and publishes `appcast.xml` to GitHub Pages.

## One-time setup

### 1. Generate a Sparkle keypair

Download the official Sparkle distribution tools and generate a keypair on your Mac:

```bash
TOOLS_DIR="$(./scripts/download_sparkle_tools.sh 2.9.2 /tmp/aevium-sparkle)"
"$TOOLS_DIR/generate_keys"
```

`generate_keys` stores the private key in your login Keychain and prints a public key.

Copy the printed public key into `Aevium/Config/AppConfig.xcconfig`:

```xcconfig
AEVIUM_SPARKLE_PUBLIC_ED_KEY = your-public-key-here
```

Export the private key for GitHub Actions:

```bash
"$TOOLS_DIR/generate_keys" -x /tmp/aevium-sparkle-private-key
base64 < /tmp/aevium-sparkle-private-key | pbcopy
```

Save that base64 value as the `SPARKLE_PRIVATE_KEY_BASE64` repository secret.

In this workspace, I also export it to:

```text
~/.config/aevium/secrets/SPARKLE_PRIVATE_KEY_BASE64.txt
```

### 2. Configure GitHub Pages

In GitHub repository settings:

- Enable **Pages**
- Set the source to **GitHub Actions**

The default feed URL in `Aevium/Config/AppConfig.xcconfig` expects the Pages site to be:

```text
https://connorcolyer.github.io/Aevium/appcast.xml
```

If the repository owner or name changes, update `AEVIUM_SPARKLE_FEED_URL`.

### 3. Add release secrets

Add one repository secret for the release workflow:

- `SPARKLE_PRIVATE_KEY_BASE64`

If `gh` is installed and authenticated, upload it with:

```bash
./scripts/set_github_secrets.sh
```

## Releasing

Create a release with:

```bash
./scripts/release.sh 0.0.11
```

That script:

1. Updates `MARKETING_VERSION`
2. Derives `CURRENT_PROJECT_VERSION` as `major * 10000 + minor * 100 + patch`
3. Commits the version bump
4. Pushes `main`
5. Tags `vX.Y.Z`

The GitHub Actions workflow then:

1. Builds the release app
2. Creates `Aevium.dmg` for first-time installs
3. Creates `Aevium.zip` for Sparkle updates
4. Creates a GitHub Release
5. Generates `appcast.xml`
6. Deploys the appcast and release notes to GitHub Pages

## First install experience

Because this workflow does not use an Apple Developer account, the app is unsigned and not notarized.

That means your mate may need to:

1. Download `Aevium.dmg` from GitHub Releases
2. Drag `Aevium.app` into `Applications`
3. On first launch, use `Open` or `Open Anyway` in macOS if Gatekeeper blocks it

After that first trust step, Sparkle can handle future updates from inside the app.

## Local verification

You can verify the app still builds with:

```bash
xcodebuild -project Aevium.xcodeproj -scheme Aevium -configuration Debug build
```
