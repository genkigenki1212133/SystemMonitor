# SystemMonitor

macOSメニューバーにCPU・メモリ・GPU使用率を表示するシンプルなアプリ。

![SystemMonitor Screenshot](screenshot.png)

## 特徴

- 軽量（メモリ使用量 約10-15MB）
- Dockに表示されない
- 1秒ごとに自動更新
- ネイティブSwift製（追加ランタイム不要）
- Apple Silicon GPU使用率対応（MPS使用時のモニタリングに最適）

## インストール

### ダウンロード

[Releases](../../releases) から最新の `SystemMonitor.zip` をダウンロードして解凍し、`SystemMonitor.app` を `/Applications` フォルダに移動してください。

### 初回起動時

macOSのセキュリティ設定により、初回起動時に警告が表示される場合があります：

1. `SystemMonitor.app` を右クリック
2. 「開く」を選択
3. 確認ダイアログで「開く」をクリック

### ソースからビルド

```bash
git clone https://github.com/genkigenki1212133/SystemMonitor.git
cd SystemMonitor
./build.sh
open build/SystemMonitor.app
```

## 使い方

起動するとメニューバーに `CPU:XX% MEM:XX% GPU:XX%` が表示されます。

GPU使用率はApple Silicon (M1/M2/M3) のDevice Utilizationを表示します。機械学習でMPSを使用する際のGPU負荷監視に便利です。

クリックすると「終了」メニューが表示されます。

## 動作環境

- macOS 12.0 (Monterey) 以降
- Apple Silicon / Intel 両対応

## ライセンス

MIT License

## サポート

このプロジェクトが役に立ったら、ぜひサポートをお願いします！

[![GitHub Sponsors](https://img.shields.io/badge/Sponsor-%E2%9D%A4-ea4aaa?logo=github)](https://github.com/sponsors/genkigenki1212133)
