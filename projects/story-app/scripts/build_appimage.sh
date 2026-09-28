#!/bin/bash

# Build AppImage script for Multi-AI Agent Orchestrator

set -e

APP_NAME="story-app"
APP_VERSION="1.0.0"
APP_DIR="/tmp/${APP_NAME}"
BUILD_DIR="/tmp/${APP_NAME}-build"
DESKTOP_FILE="${APP_NAME}.desktop"
ICON_FILE="icon.png"

echo "=========================================="
echo " Building ${APP_NAME} AppImage"
echo "=========================================="

# Clean previous builds
rm -rf "$APP_DIR" "$BUILD_DIR"
mkdir -p "$APP_DIR"/usr/bin
mkdir -p "$APP_DIR"/opt/${APP_NAME}

# Copy backend
echo "Copying backend..."
cp -r backend "$APP_DIR/opt/${APP_NAME}/"
cd "$APP_DIR/opt/${APP_NAME}/backend"
pip install -r requirements.txt --target "$APP_DIR/opt/${APP_NAME}/python_libs"
pip install uvicorn[standard] aiosqlite --target "$APP_DIR/opt/${APP_NAME}/python_libs"

# Copy frontend
echo "Copying frontend..."
cp -r frontend "$APP_DIR/opt/${APP_NAME}/"

# Copy scripts
echo "Copying scripts..."
cp -r scripts "$APP_DIR/opt/${APP_NAME}/"

# Create entry point
cat > "$APP_DIR/usr/bin/${APP_NAME}" << EOF
#!/bin/bash
cd /opt/${APP_NAME}/backend
PYTHONPATH=/opt/${APP_NAME}/python_libs python run.py
EOF
chmod +x "$APP_DIR/usr/bin/${APP_NAME}"

# Create desktop file
cat > "$BUILD_DIR/${DESKTOP_FILE}" << EOF
[Desktop Entry]
Name=${APP_NAME}
Comment=Multi-AI Agent Orchestrator
Exec=${APP_NAME}
Icon=${ICON_FILE}
Type=Application
Categories=Development;
Terminal=true
EOF

# Create AppImage using appimagetool
echo "Creating AppImage..."
if command -v appimagetool &> /dev/null; then
    appimagetool "$APP_DIR" "$BUILD_DIR/${APP_NAME}-${APP_VERSION}.AppImage"
    echo -e "\nAppImage created at: $BUILD_DIR/${APP_NAME}-${APP_VERSION}.AppImage"
else
    echo "appimagetool not found. Install it to create AppImage."
    echo "https://github.com/AppImage/AppImageKit/releases"
fi

echo ""
echo "=========================================="
echo " Build complete!"
echo "=========================================="
