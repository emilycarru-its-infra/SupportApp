# ECUAD Custom SupportApp Build

This repository is a fork of [root3nl/SupportApp](https://github.com/root3nl/SupportApp) maintained by Emily Carr University IT for custom builds.

## Overview

We maintain this fork to:
- Use custom bundle identifier: `ca.ecuad.macadmin.SupportApp`
- Deploy to custom location: `/Library/Application Support/SupportApp/`
- Build packages using munkipkg workflow
- Maintain ECUAD branding and configuration

## Upstream Tracking

This repository tracks the official SupportApp as a Git submodule in our main Munki repository. To sync with upstream:

```bash
git remote add upstream https://github.com/root3nl/SupportApp.git
git fetch upstream
git merge upstream/main  # or specific tag like v3.0.0
```

## ECUAD Customizations

### Bundle Identifiers
- **App**: `ca.ecuad.macadmin.SupportApp` (instead of `nl.root3.support`)
- **Helper**: `ca.ecuad.macadmin.SupportApp.helper` (instead of `nl.root3.support.helper`)

### Deployment Structure
```
/Library/
├── Application Support/SupportApp/
│   ├── MacAdmins.icns          # Custom ECUAD icon
│   └── Support.app              # Built with custom bundle ID
└── LaunchAgents/
    └── ca.ecuad.macadmin.SupportApp.plist
```

### Configuration Profiles
Located in the main Munki repo at `profiles/`:
- `Staff/StaffSupportAppPrefs.mobileconfig` - Staff computers
- `Curriculum/CurriculumSupportAppPrefs.mobileconfig` - Lab computers
- `Faculty/FacultySupportAppPrefs.mobileconfig` - Faculty computers

Each profile configures:
- Title: "Emily Carr University - Support"
- Custom color: #EE803A (ECUAD orange)
- Custom logo path
- Catalog-specific shortcuts and info items

## Build Process

### Requirements
- macOS with Xcode installed
- munkipkg: `brew install munki/munki/munkipkg`
- Code signing certificates:
  - Developer ID Application: Emily Carr University of Art and Design (7TF6CSP83S)
  - Developer ID Installer: Emily Carr University of Art and Design (7TF6CSP83S)
- Notarization credentials stored as: `notarization_credentials`

### Quick Build

```bash
./build_ecuad.sh 3.0.0
```

This single command:
1. Updates bundle identifiers in source files
2. Builds the app using Xcode with custom signing
3. Copies to munkipkg payload directory
4. Updates version in build-info.yaml
5. Builds signed and notarized .pkg installer

### Manual Steps (if needed)

#### 1. Modify Source Files
The build script automatically updates these, but you can manually edit:
- `src/Support/Info.plist` - Main app bundle ID
- `src/SupportHelper/Info.plist` - Helper bundle ID
- `src/SupportHelper/launchd.plist` - Helper LaunchDaemon label

#### 2. Build App
```bash
xcodebuild clean build \
    -project src/Support.xcodeproj \
    -scheme Support \
    -configuration Release \
    -derivedDataPath DerivedData \
    CODE_SIGN_IDENTITY="Developer ID Application: Emily Carr University of Art and Design (7TF6CSP83S)" \
    PRODUCT_BUNDLE_IDENTIFIER="ca.ecuad.macadmin.SupportApp"
```

#### 3. Copy to Payload
```bash
ditto DerivedData/Build/Products/Release/Support.app \
    "payload/Application Support/SupportApp/Support.app"
```

#### 4. Build Package
```bash
munkipkg .
```

## Files Added for ECUAD

These files are ECUAD-specific and not in upstream:

```
build-info.yaml                     # munkipkg configuration
build_ecuad.sh                      # ECUAD build script
ECUAD_README.md                     # This file
payload/                            # munkipkg payload structure
├── Application Support/SupportApp/
│   └── MacAdmins.icns             # Custom icon
└── LaunchAgents/
    └── ca.ecuad.macadmin.SupportApp.plist
scripts/
├── preinstall                      # Cleanup old installation
└── postinstall                     # Set permissions, load LaunchAgent
```

## Updating from Upstream

When a new version is released:

```bash
# Fetch upstream changes
git fetch upstream
git fetch upstream --tags

# Merge specific version
git merge v3.0.0  # or git merge upstream/main

# Resolve any conflicts, then build
./build_ecuad.sh 3.0.0

# Test package
# ... test on staging machine ...

# Commit and push to fork
git add .
git commit -m "Update to SupportApp v3.0.0 with ECUAD customizations"
git push origin main

# In main Munki repo, update submodule
cd /path/to/Munki
git submodule update --remote packages/SupportApp
git add packages/SupportApp
git commit -m "Update SupportApp submodule to v3.0.0"
```

## Configuration

### App Settings (via Configuration Profile)

Example keys used in our profiles:

```xml
<key>Title</key>
<string>Emily Carr University - Support</string>

<key>Logo</key>
<string>/Library/Application Support/SupportApp/MacAdmins.icns</string>

<key>StatusBarIconSFSymbol</key>
<string>macpro.gen3</string>

<key>CustomColor</key>
<string>#EE803A</string>

<key>FirstRowTitleLeft</key>
<string>Software Centre</string>
<key>FirstRowLinkLeft</key>
<string>com.googlecode.munki.ManagedSoftwareCenter</string>
<key>FirstRowTypeLeft</key>
<string>App</string>
```

See [official documentation](https://github.com/root3nl/SupportApp#configuration) for all available keys.

## Differences from Official Build

| Aspect | Official | ECUAD Custom |
|--------|----------|--------------|
| Bundle ID | `nl.root3.support` | `ca.ecuad.macadmin.SupportApp` |
| Helper ID | `nl.root3.support.helper` | `ca.ecuad.macadmin.SupportApp.helper` |
| Install Location | `/Applications/Support.app` | `/Library/Application Support/SupportApp/Support.app` |
| LaunchAgent | `nl.root3.support.plist` | `ca.ecuad.macadmin.SupportApp.plist` |
| Build Method | pkgbuild + productsign | munkipkg |
| Signing Identity | Root3 B.V. | Emily Carr University |

## Troubleshooting

### Build fails with signing errors
```bash
# Unlock signing keychain
security unlock-keychain signing.keychain

# Verify certificate
security find-identity -v -p codesigning
```

### Bundle ID not updating
The build script modifies source files before building. If bundle ID is wrong:
1. Check that script has write permissions
2. Verify Xcode isn't overriding settings
3. Clean build: `rm -rf DerivedData && ./build_ecuad.sh <version>`

### Package not notarizing
```bash
# Check notarization profile exists
xcrun notarytool store-credentials --list

# Should show: notarization_credentials
```

### App won't launch
1. Check LaunchAgent is loaded: `launchctl list | grep ecuad`
2. Check app permissions: `ls -la "/Library/Application Support/SupportApp/Support.app"`
3. Check quarantine attribute: `xattr -l "/Library/Application Support/SupportApp/Support.app"`

## Support & Documentation

- **Upstream Issues**: https://github.com/root3nl/SupportApp/issues
- **Upstream Documentation**: https://github.com/root3nl/SupportApp#readme
- **ECUAD Issues**: Contact Mac Admins team

## License

This fork maintains the same license as the upstream project. See [LICENSE](LICENSE) file.

The ECUAD customizations and build scripts are © 2025 Emily Carr University of Art and Design.
