#!/bin/sh
# https://docs.travis-ci.com/user/common-build-problems/#Mac%3A-macOS-Sierra-(10.12)-Code-Signing-Errors
# https://github.com/travis-ci/travis-ci/issues/3047

# Create the keychain with a password
security create-keychain -p travis ios-build.keychain

# Make the custom keychain default, so xcodebuild will use it for signing
security default-keychain -s ios-build.keychain

# Unlock the keychain
security unlock-keychain -p travis ios-build.keychain

# Add certificates to keychain and allow codesign to access them
# security import ./Provisioning/certs/apple.cer -k ~/Library/Keychains/ios-build.keychain -T /usr/bin/codesign
# security import ./Provisioning/certs/distribution.cer -k ~/Library/Keychains/ios-build.keychain -T /usr/bin/codesign
# security import ./Provisioning/certs/distribution.p12 -k ~/Library/Keychains/ios-build.keychain -P $KEY_PASSWORD -T /usr/bin/codesign

# security set-key-partition-list -S apple-tool:,apple: -s -k travis ios-build.keychain
