
#!/usr/bin/env bash
set -e

echo "Installing Flutter SDK..."

curl -fL \
  "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.44.6-stable.tar.xz" \
  -o /tmp/flutter.tar.xz

tar -xf /tmp/flutter.tar.xz -C /tmp

export PATH="/tmp/flutter/bin:$PATH"

echo "Flutter version:"
flutter --version

echo "Getting dependencies..."
flutter pub get

echo "Building Flutter Web..."
flutter build web --release

echo "Flutter Web build completed!"
