# NCOM AI iOS signing & distribution

NCOM AI does not bypass Apple's code-signing or provisioning controls.

## Personal device testing

For a personal iPhone, Apple supports installing and testing apps from Xcode using a Personal Team. Apple states that Personal Team App IDs, devices, and provisioning profiles expire after 7 days, so the app must be reprovisioned/reinstalled periodically.

## Developer distribution

For longer-lived device testing, use an Apple Developer Program account with a registered App ID and device, then use development or Ad Hoc provisioning as appropriate.

Bundle identifier selected for NCOM:

`com.ncom.ai`

The identifier must be registered/available in the Apple developer account used to sign the real device build.

## TestFlight

For beta distribution, archive the signed app and upload it to App Store Connect. TestFlight then distributes the beta build to invited testers and handles installation/update delivery.

## App Store

The final seller/developer name shown by App Store distribution is controlled by the Apple developer account type. A personal enrollment uses the individual's legal name; an organization enrollment can show the organization's legal entity name.

## GitHub

GitHub Actions can build and test unsigned Simulator artifacts without Apple signing credentials. A signed device/App Store workflow requires the appropriate Apple credentials and provisioning assets stored as protected CI secrets. Never commit certificates, private keys, API keys, provisioning profiles, or device identifiers to this repository.
