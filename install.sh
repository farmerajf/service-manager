#!/bin/bash
APP_NAME="Service Manager"
SOURCE="$HOME/Library/Developer/Xcode/DerivedData/Service_Manager-*/Build/Products/Debug/$APP_NAME.app"
DEST="/Applications/$APP_NAME.app"

# Find the built app
APP_PATH=$(ls -dt $HOME/Library/Developer/Xcode/DerivedData/Service_Manager-*/Build/Products/Debug/Service\ Manager.app 2>/dev/null | head -1)
if [ -z "$APP_PATH" ]; then
    echo "Build not found. Build the project in Xcode first."
    exit 1
fi

# Kill running instance
pkill -x "Service Manager" 2>/dev/null
sleep 1

# Copy to Applications
rm -rf "$DEST"
cp -R "$APP_PATH" "$DEST"
xattr -cr "$DEST"

echo "Installed to /Applications/$APP_NAME.app"
open "$DEST"
