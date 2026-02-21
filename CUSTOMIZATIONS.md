# ECUAD Custom SupportApp Build

Fork of [root3nl/SupportApp](https://github.com/root3nl/SupportApp) maintained by Emily Carr University IT.

## Quick Start

```bash
./build.sh 3.0.1
```

This builds Support.app with ECUAD customizations and creates a signed `.pkg` installer.

---

## What We Keep (ECUAD Files)

These files are **ECUAD-specific** and should **never be overwritten** from upstream:

```
build.sh                            # Single-command build script
build-info.yaml                     # munkipkg configuration
CUSTOMIZATIONS.md                   # This file
.gitignore                          # Ignore build artifacts
payload/                            # munkipkg payload
├── Application Support/SupportApp/
│   └── MacAdmins.icns             # ECUAD icon
└── LaunchAgents/
    └── ca.ecuad.macadmin.SupportApp.plist
scripts/
├── preinstall                      # Cleanup old install
└── postinstall                     # Set permissions, load LaunchAgent
```

## What We Update (From Upstream)

Pull and merge these from Root3:

```
src/                                # Swift source code (app + helper)
README.md                           # Official documentation
LICENSE                             # License file
```

## What We Ignore (Upstream-Only)

These upstream files are **not used** by ECUAD and can be deleted:

```
pkgbuild/                           # Root3 build scripts (we use munkipkg)
SupportHelper/                      # Standalone helper (we build from src/)
Configuration Profile Samples/      # We have our own profiles
Extension Sample Scripts/           # Not used
Jamf Pro Custom Schema/             # Don't use Jamf
LaunchAgent Sample/                 # We use custom LaunchAgent
Screenshots/                        # Documentation only
build_pkg_automated.zsh             # GitHub Actions script
.github/                            # Workflows (optional to keep)
```

---

## Syncing With Upstream

### One-Time Setup

```bash
cd packages/SupportApp
git remote add upstream https://github.com/root3nl/SupportApp.git
git fetch upstream --tags
```

### Update to New Version

```bash
# 1. Fetch latest upstream tags and commits
cd packages/SupportApp
git fetch upstream --tags

# 2. Check what's new (optional)
git tag | tail -5                          # latest upstream tags
git log HEAD..upstream/master --oneline   # commits since last merge

# 3. Start the merge (no-commit so conflicts can be resolved manually)
git merge upstream/master --no-commit --no-ff

# 4. Check what conflicted
git status --short
```

Likely conflict is `src/SupportHelper/Info.plist` — upstream uses `nl.root3.support.helper`,
we use `ca.ecuad.macadmin.SupportApp.helper`. Resolution: keep our bundle ID, take their version numbers.

```bash
# Keep our bundle ID in the conflicted file
git checkout --ours src/SupportHelper/Info.plist

# Then manually update CFBundleShortVersionString and CFBundleVersion
# to match what upstream/master has:
git show upstream/master:src/SupportHelper/Info.plist | grep -A1 "CFBundleShortVersion\|CFBundleVersion"

# Edit src/SupportHelper/Info.plist to update the version numbers, then stage
git add src/SupportHelper/Info.plist
```

If there are conflicts in any ECUAD-owned files (`build.sh`, `build-info.yaml`,
`CUSTOMIZATIONS.md`, `payload/`, `scripts/`, `.gitignore`), keep ours:

```bash
git checkout --ours build.sh build-info.yaml CUSTOMIZATIONS.md .gitignore
git checkout --ours -- payload/ scripts/
git add build.sh build-info.yaml CUSTOMIZATIONS.md .gitignore payload/ scripts/
```

```bash
# 5. Complete the merge
git commit -m "Merge upstream vX.Y.Z with ECUAD customizations"

# 6. Push submodule to origin
git push origin main

# 7. Update submodule pointer in main Munki repo
cd ../..
git add packages/SupportApp
git commit -m "Update SupportApp to vX.Y.Z"
```

---

## ECUAD Customizations

### Bundle Identifiers

| Component | Upstream | ECUAD |
|-----------|----------|-------|
| Main App | `nl.root3.support` | `ca.ecuad.macadmin.SupportApp` |
| Helper | `nl.root3.support.helper` | `ca.ecuad.macadmin.SupportApp.helper` |
| LaunchAgent | `nl.root3.support.plist` | `ca.ecuad.macadmin.SupportApp.plist` |

### Deployment

**Upstream**: `/Applications/Support.app`  
**ECUAD**: `/Library/Application Support/SupportApp/Support.app`

Structure:
```
/Library/
├── Application Support/SupportApp/
│   ├── MacAdmins.icns              # Custom icon
│   └── Support.app                  # App with custom bundle ID
└── LaunchAgents/
    └── ca.ecuad.macadmin.SupportApp.plist
```

### Configuration Profiles

Located in main Munki repo at `profiles/`:

- **Staff**: `Staff/StaffSupportAppPrefs.mobileconfig`
- **Curriculum**: `Curriculum/CurriculumSupportAppPrefs.mobileconfig`
- **Faculty**: `Faculty/FacultySupportAppPrefs.mobileconfig`

Settings:
- Title: "Emily Carr University - Support"
- Color: `#EE803A` (ECUAD orange)
- Logo: `/Library/Application Support/SupportApp/MacAdmins.icns`
- Info items: Computer Name, macOS Version, Network, Storage
- Shortcuts: Software Centre, ITS Portal (Staff/Faculty), Device Report (Curriculum)

---

## Build Process

### What build.sh Does

1. **Updates bundle IDs** in `src/Support/Info.plist` and `src/SupportHelper/`
2. **Builds with Xcode**:
   - Configuration: Release
   - Signing: Developer ID Application (ECUAD)
   - Custom bundle identifier
3. **Copies to payload**: `payload/Application Support/SupportApp/Support.app`
4. **Packages with munkipkg**: Creates signed & notarized `.pkg`

### Requirements

- macOS with Xcode installed
- munkipkg: `brew install munki/munki/munkipkg`
- Code Signing Certificates:
  - Developer ID Application: Emily Carr University (7TF6CSP83S)
  - Developer ID Installer: Emily Carr University (7TF6CSP83S)
- Notarization credentials: `notarization_credentials` keychain profile

### Build Command

```bash
./build.sh 3.0.1
```

Output: `build/SupportApp-3.0.1.pkg`

> **Note**: The script always cleans, signs, and notarizes. Flags like `--clean --sign --notarize`
> are accepted but not required.

### Rebuild and Reimport Into Munki

After updating from upstream (or any change that requires a new package):

```bash
# 1. Build, sign, and notarize
cd packages/SupportApp
./build.sh 3.0.1

# 2. Import into Munki repo
#    munkiimport will prompt to use the existing pkgsinfo as a template — answer y
munkiimport build/SupportApp-3.0.1.pkg

# 3. Commit the new pkgsinfo and updated submodule pointer
cd ../..
git add packages/SupportApp deployment/pkgsinfo/apps/utilities/SupportApp-3.0.1.yaml
git commit -m "Add SupportApp 3.0.1 to Munki"
```

The `munkiimport` template prompt copies: name, catalogs (`Development, Testing, Staging, Production`),
`unattended_install: true`, category, and developer from the previous version. Just confirm the version
number and description look right before accepting.

### Deploy to Munki

```bash
munkiimport build/SupportApp-3.0.0.pkg
```

---

## Troubleshooting

### Build fails with signing error

```bash
security unlock-keychain signing.keychain
security find-identity -v -p codesigning
```

### Bundle ID not updating

Clean build:
```bash
rm -rf DerivedData payload/Application\ Support/SupportApp/Support.app
./build.sh 3.0.0
```

### App won't launch

Check LaunchAgent:
```bash
launchctl list | grep ecuad
ls -la "/Library/Application Support/SupportApp/Support.app"
xattr -l "/Library/Application Support/SupportApp/Support.app"
```

---

## Differences From Upstream

| Aspect | Upstream | ECUAD |
|--------|----------|-------|
| Bundle ID | `nl.root3.support` | `ca.ecuad.macadmin.SupportApp` |
| Location | `/Applications/` | `/Library/Application Support/SupportApp/` |
| Build Tool | pkgbuild | munkipkg |
| Signing | Root3 B.V. | Emily Carr University |

---

## Resources

- **Upstream**: https://github.com/root3nl/SupportApp
- **Upstream Docs**: https://github.com/root3nl/SupportApp#readme
- **ECUAD Issues**: Contact Mac Admins team

## License

Same as upstream. See [LICENSE](LICENSE).

ECUAD customizations © 2025 Emily Carr University of Art and Design.
