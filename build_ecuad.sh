#!/bin/zsh

# ECUAD Custom Build Script for SupportApp
# This script builds SupportApp with Emily Carr University customizations
#
# Usage: ./build_ecuad.sh [version]
# Example: ./build_ecuad.sh 3.0.0

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="${0:A:h}"
cd "${SCRIPT_DIR}"

# ECUAD Configuration
CUSTOM_BUNDLE_ID="ca.ecuad.macadmin.SupportApp"
CUSTOM_HELPER_BUNDLE_ID="ca.ecuad.macadmin.SupportApp.helper"
ORIGINAL_BUNDLE_ID="nl.root3.support"
ORIGINAL_HELPER_BUNDLE_ID="nl.root3.support.helper"
APP_NAME="Support"
SIGNING_IDENTITY_APP="Developer ID Application: Emily Carr University of Art and Design (7TF6CSP83S)"
SIGNING_IDENTITY_INSTALLER="Developer ID Installer: Emily Carr University of Art and Design (7TF6CSP83S)"
SIGNING_KEYCHAIN="${HOME}/Library/Keychains/signing.keychain"
NOTARIZATION_PROFILE="notarization_credentials"
TEAM_ID="7TF6CSP83S"

# Version
VERSION="${1:-}"
if [[ -z "${VERSION}" ]]; then
    echo -e "${RED}Error: No version specified${NC}"
    echo "Usage: $0 <version>"
    echo "Example: $0 3.0.0"
    exit 1
fi

echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         ECUAD Custom Build - SupportApp v${VERSION}            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Update bundle identifiers in source
echo -e "${BLUE}[1/6]${NC} ${YELLOW}Updating bundle identifiers in source files...${NC}"

# Update Info.plist in source (will be used by Xcode)
if [[ -f "src/Support/Info.plist" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${CUSTOM_BUNDLE_ID}" src/Support/Info.plist 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string ${CUSTOM_BUNDLE_ID}" src/Support/Info.plist
    echo "  ✓ Updated src/Support/Info.plist"
fi

# Update helper bundle ID in Info.plist for SMPrivilegedExecutables
if [[ -f "src/Support/Info.plist" ]]; then
    /usr/libexec/PlistBuddy -c "Delete :SMPrivilegedExecutables" src/Support/Info.plist 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :SMPrivilegedExecutables dict" src/Support/Info.plist
    /usr/libexec/PlistBuddy -c "Add :SMPrivilegedExecutables:${CUSTOM_HELPER_BUNDLE_ID} string 'anchor apple generic and identifier \"${CUSTOM_HELPER_BUNDLE_ID}\" and (certificate leaf[field.1.2.840.113635.100.6.1.9] /* exists */ or certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = \"${TEAM_ID}\")'" src/Support/Info.plist
    echo "  ✓ Updated SMPrivilegedExecutables"
fi

# Update helper Info.plist
if [[ -f "src/SupportHelper/Info.plist" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${CUSTOM_HELPER_BUNDLE_ID}" src/SupportHelper/Info.plist 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string ${CUSTOM_HELPER_BUNDLE_ID}" src/SupportHelper/Info.plist
    echo "  ✓ Updated src/SupportHelper/Info.plist"
fi

# Update helper launchd plist
if [[ -f "src/SupportHelper/launchd.plist" ]]; then
    /usr/libexec/PlistBuddy -c "Set :Label ${CUSTOM_HELPER_BUNDLE_ID}" src/SupportHelper/launchd.plist 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :Label string ${CUSTOM_HELPER_BUNDLE_ID}" src/SupportHelper/launchd.plist
    
    /usr/libexec/PlistBuddy -c "Set :MachServices:${CUSTOM_HELPER_BUNDLE_ID} bool true" src/SupportHelper/launchd.plist 2>/dev/null || {
        /usr/libexec/PlistBuddy -c "Delete :MachServices" src/SupportHelper/launchd.plist 2>/dev/null || true
        /usr/libexec/PlistBuddy -c "Add :MachServices dict" src/SupportHelper/launchd.plist
        /usr/libexec/PlistBuddy -c "Add :MachServices:${CUSTOM_HELPER_BUNDLE_ID} bool true" src/SupportHelper/launchd.plist
    }
    echo "  ✓ Updated src/SupportHelper/launchd.plist"
fi

# Step 2: Clean previous builds
echo ""
echo -e "${BLUE}[2/6]${NC} ${YELLOW}Cleaning previous builds...${NC}"
rm -rf "payload/Application Support/SupportApp/${APP_NAME}.app"
rm -rf DerivedData
echo "  ✓ Cleaned"

# Step 3: Build the app
echo ""
echo -e "${BLUE}[3/6]${NC} ${YELLOW}Building ${APP_NAME}.app from source...${NC}"

xcodebuild clean build \
    -project "src/${APP_NAME}.xcodeproj" \
    -scheme "${APP_NAME}" \
    -configuration Release \
    -derivedDataPath "DerivedData" \
    CODE_SIGN_IDENTITY="${SIGNING_IDENTITY_APP}" \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM="${TEAM_ID}" \
    PRODUCT_BUNDLE_IDENTIFIER="${CUSTOM_BUNDLE_ID}" \
    OTHER_CODE_SIGN_FLAGS="--keychain ${SIGNING_KEYCHAIN}" \
    | grep -E '(^Build |^\*\*|error:|warning:)' || true

# Find built app
BUILT_APP=$(find "DerivedData" -name "${APP_NAME}.app" -type d | head -n 1)

if [[ ! -d "${BUILT_APP}" ]]; then
    echo -e "${RED}Error: Built app not found${NC}"
    exit 1
fi

echo "  ✓ Built at: ${BUILT_APP}"

# Step 4: Copy to payload
echo ""
echo -e "${BLUE}[4/6]${NC} ${YELLOW}Copying app to munkipkg payload...${NC}"
mkdir -p "payload/Application Support/SupportApp"
ditto "${BUILT_APP}" "payload/Application Support/SupportApp/${APP_NAME}.app"
echo "  ✓ Copied"

# Verify bundle identifier
ACTUAL_BUNDLE_ID=$(defaults read "${SCRIPT_DIR}/payload/Application Support/SupportApp/${APP_NAME}.app/Contents/Info.plist" CFBundleIdentifier)
if [[ "${ACTUAL_BUNDLE_ID}" != "${CUSTOM_BUNDLE_ID}" ]]; then
    echo -e "${RED}Error: Bundle ID mismatch${NC}"
    echo "Expected: ${CUSTOM_BUNDLE_ID}"
    echo "Got: ${ACTUAL_BUNDLE_ID}"
    exit 1
fi
echo "  ✓ Verified bundle ID: ${ACTUAL_BUNDLE_ID}"

# Step 5: Update build-info.yaml version
echo ""
echo -e "${BLUE}[5/6]${NC} ${YELLOW}Updating build-info.yaml version...${NC}"
if [[ -f "build-info.yaml" ]]; then
    sed -i '' "s/^version: .*/version: ${VERSION}/" build-info.yaml
    echo "  ✓ Updated to v${VERSION}"
fi

# Step 6: Build package with munkipkg
echo ""
echo -e "${BLUE}[6/6]${NC} ${YELLOW}Building package with munkipkg...${NC}"
munkipkg "${SCRIPT_DIR}"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    BUILD SUCCESSFUL! ✓                         ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Package:${NC} build/SupportApp-${VERSION}.pkg"
echo -e "${GREEN}Bundle ID:${NC} ${CUSTOM_BUNDLE_ID}"
echo -e "${GREEN}Helper ID:${NC} ${CUSTOM_HELPER_BUNDLE_ID}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Test the package on a test machine"
echo "  2. Import to Munki: munkiimport build/SupportApp-${VERSION}.pkg"
echo "  3. Deploy configuration profiles from profiles/ directory"
echo ""
