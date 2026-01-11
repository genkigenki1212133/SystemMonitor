# SystemMonitor

macOSメニューバーにCPU・メモリ・GPU使用率・消費電力を表示するシンプルなアプリ。

![SystemMonitor Screenshot](screenshot.png)

## なぜ作ったか

既存のシステムモニターアプリは、モニタリングのためにCPUやメモリを大量に消費している。本末転倒だと感じたので、できるだけシンプルで軽量なモニターを作成した。

| アプリ | メモリ使用量 |
|-------|------------|
| **SystemMonitor** | **17MB** |
| iStat Menus | 50-100MB |
| Stats | 30-50MB |
| Activity Monitor | 80-150MB |

## 特徴

- 超軽量（メモリ使用量 約17MB、CPU使用率 0%）
- Dockに表示されない
- 1秒ごとに自動更新
- ネイティブSwift製（追加ランタイム不要）
- 表示項目を選択可能（CPU / Memory / GPU / Power）
- ログイン時に自動起動（macOS 13+）
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
cp -r build/SystemMonitor.app /Applications/
```

## 使い方

起動するとメニューバーに `CPU:XX% MEM:XX% GPU:XX% XXW` が表示されます。

クリックするとメニューが開き、以下の操作ができます：

- **CPU / Memory / GPU / Power (W)**: 表示項目のオン・オフ
- **ログイン時に起動**: システム起動時に自動起動（macOS 13+）
- **Donate**: 開発者をサポート
- **終了**: アプリを終了

### 表示項目

| 項目 | 説明 |
|-----|------|
| CPU | CPU使用率（リアルタイム） |
| MEM | メモリ使用率 |
| GPU | GPU使用率（Apple Silicon） |
| W | 現在の消費電力（数秒間隔で更新） |

## 動作環境

- macOS 12.0 (Monterey) 以降
- Apple Silicon / Intel 両対応
- ログイン時起動機能は macOS 13.0 (Ventura) 以降

## ライセンス

MIT License

## サポート

このプロジェクトが役に立ったら、ぜひサポートをお願いします！

[![GitHub Sponsors](https://img.shields.io/badge/Sponsor-%E2%9D%A4-ea4aaa?logo=github)](https://github.com/sponsors/genkigenki1212133)
