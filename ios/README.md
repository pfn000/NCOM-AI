# NCOM AI for iOS

This source is a SwiftUI client for an NCOM runtime running on the device or on the same LAN.

## Build

Open `NCOMApp` in Xcode, add `NCOMApp.swift` to a new iOS App target, and run on an iOS 17+ simulator/device.

The client expects an HTTP endpoint such as `http://192.168.1.20:8765` and uses `/health` and `/v1/chat`.

The client is intentionally a native client, not a web wrapper.
