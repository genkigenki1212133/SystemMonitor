#!/bin/bash

# ビルドディレクトリ
BUILD_DIR="build"
APP_NAME="SystemMonitor"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

# クリーンアップ
rm -rf "$BUILD_DIR"

# アプリバンドル構造を作成
mkdir -p "$APP_BUNDLE/Contents/MacOS"

# Swiftをコンパイル
echo "コンパイル中..."
swiftc -O -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME" main.swift

if [ $? -ne 0 ]; then
    echo "コンパイルエラー"
    exit 1
fi

# Info.plistをコピー
cp Info.plist "$APP_BUNDLE/Contents/"

echo "ビルド完了: $APP_BUNDLE"
echo ""
echo "アプリを起動するには:"
echo "  open $APP_BUNDLE"
echo ""
echo "アプリケーションフォルダにインストールするには:"
echo "  cp -r $APP_BUNDLE /Applications/"
