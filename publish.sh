#!/bin/bash

# Jimjam Haxelib Publishing Script
# This script creates a clean zip file and submits it to haxelib

set -e  # Exit on any error

echo "🚀 Publishing Jimjam to Haxelib..."

# Get version from haxelib.json
VERSION=$(grep '"version":' haxelib.json | sed 's/.*"version": *"\([^"]*\)".*/\1/')
echo "📦 Version: $VERSION"

# Create temporary directory for clean packaging
TEMP_DIR="jimjam-$VERSION"
ZIP_FILE="jimjam-$VERSION.zip"

echo "🧹 Cleaning up any existing build artifacts..."
rm -rf "$TEMP_DIR" "$ZIP_FILE"

echo "📋 Creating package directory..."
mkdir -p "$TEMP_DIR"

echo "📂 Copying files to package..."
# Copy only the files we want to include
cp haxelib.json "$TEMP_DIR/"
cp README.md "$TEMP_DIR/"
cp LICENSE "$TEMP_DIR/"

# Copy all .hxml files
for hxml in *.hxml; do
    if [ -f "$hxml" ]; then
        cp "$hxml" "$TEMP_DIR/"
        echo "   ✓ $hxml"
    fi
done

# Copy src directory
if [ -d "src" ]; then
    cp -r src "$TEMP_DIR/"
    echo "   ✓ src/"
else
    echo "❌ Error: src/ directory not found!"
    exit 1
fi

echo "📦 Creating zip file..."
# Create zip from inside temp directory so files are at root level
cd "$TEMP_DIR"
zip -r "../$ZIP_FILE" *
cd ..

echo "🗑️  Cleaning up temporary directory..."
rm -rf "$TEMP_DIR"

echo "📊 Package contents:"
unzip -l "$ZIP_FILE"

echo ""
echo "✅ Package created: $ZIP_FILE"
echo ""
echo "🚀 Submitting to haxelib..."

# Submit to haxelib
haxelib submit "$ZIP_FILE"

echo ""
echo "🎉 Successfully published Jimjam v$VERSION to haxelib!"
echo "📋 To install: haxelib install jimjam"
echo ""