#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p .build
xcrun swiftc -swift-version 5 -module-cache-path .build/ModuleCache Sources/Models.swift Tests/CoreTests.swift -o .build/check-core
.build/check-core
plutil -lint Resources/Info.plist
xcrun swiftc -swift-version 5 -module-cache-path .build/ModuleCache Sources/Models.swift Sources/YouTubeClient.swift Sources/PlayerStore.swift Tests/StoreTests.swift -o .build/check-store
.build/check-store
