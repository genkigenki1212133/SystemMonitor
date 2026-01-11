#!/bin/bash

VERSION="${1:-1.0.0}"

# ビルド
./build.sh

if [ $? -ne 0 ]; then
    echo "ビルドに失敗しました"
    exit 1
fi

# リリース用ZIPを作成
cd build
zip -r "SystemMonitor-${VERSION}.zip" SystemMonitor.app
cd ..

echo ""
echo "リリースファイルを作成しました: build/SystemMonitor-${VERSION}.zip"
echo ""
echo "GitHub Releasesにアップロードする手順:"
echo "1. https://github.com/genkigenki1212133/SystemMonitor/releases/new にアクセス"
echo "2. タグ: v${VERSION}"
echo "3. タイトル: SystemMonitor v${VERSION}"
echo "4. build/SystemMonitor-${VERSION}.zip をアップロード"
echo "5. 'Publish release' をクリック"
