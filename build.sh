#!/bin/zsh

# ECUAD SupportApp Build Script
# Single-command build: Compile from source + package with munkipkg
#
# Usage: ./build.sh [version]
# Example: ./build.sh 3.0.0

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="${0:A:h}"
cd "${SCRIPT_DIR}"

# ECUAD Configuration
CUSTOM_BUNDLE_ID="ca.ecuad.macadmin.SupportApp"
CUSTOM_HELPER_ID="ca.ecuad.macadmin.SupportApp.helper"
SIGNING_IDENTITY_APP="Developer ID Application: Emily Carr University of Art and Design (7TF6CSP83S)"
SIGNING_KEYCHAIN="${HOME}/Library/Keychains/signing.keychain"
TEAM_ID="7TF6CSP83S"

VERSION="${1:-}"
if [[ -z "${VERSION}" ]]; then
    echo -e "${RED}Error: No version specified${NC}"
    echo "Usage: $0 <version>"
    echo "Example: $0 3.0.0"
    exit 1
fi

echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ECUAD SupportApp Build v${VERSION}                ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Update bundle identifiers
echo -e "${BLUE}[1/5]${NC} ${YELLOW}Updating bundle identifiers...${NC}"

# Main app Info.plist
if [[ -f "src/Support/Info.plist" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${CUSTOM_BUNDLE_ID}" src/Support/Info.plist 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string ${CUSTOM_BUNDLE_ID}" src/Support/Info.plist
    
    # Update SMPrivilegedExecutables for helper
    /usr/libexec/PlistBuddy -c "Delete :SMPrivilegedExecutables" src/Support/Info.plist 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :SMPrivilegedExecutables dict" src/Support/Info.plist
    /usr/libexec/PlistBuddy -c "Add :SMPrivilegedExecutables:${CUSTOM_HELPER_ID} string 'anchor apple generic and identifier \"${CUSTOM_HELPER_ID}\" and (certificate leaf[field.1.2.840.113635.100.6.1.9] /* exists */ or certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = \"${TEAM_ID}\")'" src/Support/Info.plist
    echo "  ✓ Main app"
fi

# Helper Info.plist
if [[ -f "src/SupportHelper/Info.plist" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${CUSTOM_HELPER_ID}" src/SupportHelper/Info.plist 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string ${CUSTOM_HELPER_ID}" src/SupportHelper/Info.plist
    echo "  ✓ Helper"
fi

# Helper launchd.plist
if [[ -f "src/SupportHelper/launchd.plist" ]]; then
    /usr/libexec/PlistBuddy -c "Set :Label ${CUSTOM_HELPER_ID}" src/SupportHelper/launchd.plist 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :Label string ${CUSTOM_HELPER_ID}" src/SupportHelper/launchd.plist
    
    /usr/libexec/PlistBuddy -c "Set :MachServices:${CUSTOM_HELPER_ID} bool true" src/SupportHelper/launchd.plist 2>/dev/null || {
        /usr/libexec/PlistBuddy -c "Delete :MachServices" src/SupportHelper/launchd.plist 2>/dev/null || true
        /usr/libexec/PlistBuddy -c "Add :MachServices dict" src/SupportHelper/launchd.plist
        /usr/libexec/PlistBuddy -c "Add :MachServices:${CUSTOM_HELPER_ID} bool true" src/SupportHelper/launchd.plist
    }
    echo "  ✓ LaunchDaemon"
fi

# Step 2: Clean
echo ""
echo -e "${BLUE}[2/5]${NC} ${YELLOW}Cleaning previous builds...${NC}"
rm -rf "payload/Application Support/SupportApp/Support.app"
rm -rf DerivedData
echo "  ✓ Clean"

# Step 3: Build with Xcode
echo ""
echo -e "${BLUE}[3/5]${NC} ${YELLOW}Building Support.app from source...${NC}"

xcodebuild clean build \
    -project "src/Support.xcodeproj" \
    -scheme "Support" \
    -configuration Release \
    -derivedDataPath "DerivedData" \
    CODE_SIGN_IDENTITY="${SIGNING_IDENTITY_APP}" \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM="${TEAM_ID}" \
    PRODUCT_BUNDLE_IDENTIFIER="${CUSTOM_BUNDLE_ID}" \
    OTHER_CODE_SIGN_FLAGS="--keychain ${SIGNING_KEYCHAIN}" \
    2>&1 | grep -E '(^Build |^\*\*|error:|warning:)' || true

BUILT_APP=$(find "DerivedData" -name "Support.app" -type d | head -n 1)

if [[ ! -d "${BUILT_APP}" ]]; then
    echo -e "${RED}Error: Built app not found${NC}"
    exit 1
fi

echo "  ✓ Built"

# Step 4: Copy to payload
echo ""
echo -e "${BLUE}[4/5]${NC} ${YELLOW}Copying to munkipkg payload...${NC}"
mkdir -p "payload/Application Support/SupportApp"
ditto "${BUILT_APP}" "payload/Application Support/SupportApp/Support.app"

# Verify bundle ID
ACTUAL_ID=$(defaults read "${SCRIPT_DIR}/payload/Application Support/SupportApp/Support.app/Contents/Info.plist" CFBundleIdentifier)
if [[ "${ACTUAL_ID}" != "${CUSTOM_BUNDLE_ID}" ]]; then
    echo -e "${RED}Error: Bundle ID mismatch${NC}"
    echo "Expected: ${CUSTOM_BUNDLE_ID}"
    echo "Got: ${ACTUAL_ID}"
    exit 1
fi
echo "  ✓ Verified: ${ACTUAL_ID}"

# Update version in build-info.yaml
sed -i '' "s/^version: .*/version: ${VERSION}/" build-info.yaml

# Step 5: Build package
echo ""
echo -e "${BLUE}[5/5]${NC} ${YELLOW}Building package with munkipkg...${NC}"
munkipkg "${SCRIPT_DIR}"

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              BUILD SUCCESSFUL ✓                   ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Package:${NC} build/SupportApp-${VERSION}.pkg"
echo -e "${GREEN}Bundle ID:${NC} ${CUSTOM_BUNDLE_ID}"
echo ""
echo -e "${YELLOW}Next:${NC}"
echo "  Test package, then: munkiimport build/SupportApp-${VERSION}.pkg"
echo ""
