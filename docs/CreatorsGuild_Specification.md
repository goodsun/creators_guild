# Creators Guild Smart Contract Specification

## 概要

Creators Guild は、クリエイターのための NFT プラットフォームを実現するスマートコントラクト群です。クリエイターが自由に NFT を発行し、ロイヤリティを設定し、支援を受けることができる分散型システムを提供します。

## システム構成

### 1. NFT コントラクト

- **CreatorsGuildNFT.sol**: メインの NFT コントラクト
- **RoyaltyStandard.sol**: ERC-2981 ロイヤリティ標準の実装

### 2. Token Bound Account (TBA)

- **ERC6551Registry.sol**: TBA のファクトリーコントラクト
- **ERC6551Account.sol**: NFT が所有するスマートコントラクトアカウント
- **各種ライブラリとインターフェース**: TBA 実装のサポート

## CreatorsGuildNFT Contract

### 基本情報

- **標準**: ERC-721（Enumerable 拡張付き）、ERC-2981（ロイヤリティ）
- **継承**: ERC721Enumerable, RoyaltyStandard, ReentrancyGuard
- **言語**: Solidity ^0.8.0

### 主要機能

#### 1. NFT ミント機能

```solidity
function mint(address to, string memory _metaUrl, uint16 _feeRate, bool _sbtFlag) public payable
```

- **概要**: 新しい NFT をミントする
- **パラメータ**:
  - `to`: NFT の受取アドレス
  - `_metaUrl`: メタデータの URL（Arweave 等）
  - `_feeRate`: ロイヤリティ率（ベーシスポイント、最大値は maxFeeRate）
  - `_sbtFlag`: SBT（譲渡不可トークン）フラグ
- **必要 ETH**: mintFee 以上
- **特徴**:
  - ミント手数料を超える支払いは寄付として記録
  - クリエイター（msg.sender）を自動追跡
  - トークン ID は自動採番

#### 2. 寄付機能付き転送

```solidity
function transferFromWithDonation(address from, address to, uint256 tokenId) external payable
function safeTransferFromWithDonation(address from, address to, uint256 tokenId, bytes memory data) public payable
```

- **概要**: NFT 転送時に受取人への寄付を同時に行う
- **特徴**: 送信 ETH は全額が受取人への寄付として記録

#### 3. キャッシュバック付き転送

```solidity
function transferFromWithCashback(address from, address to, uint256 tokenId) external payable
```

- **概要**: NFT 転送時に購入者へ 10%のキャッシュバックを提供
- **分配**: 90%が寄付、10%がキャッシュバック

#### 4. Soul Bound Token (SBT) サポート

- **概要**: 譲渡不可能な NFT の発行が可能
- **実装**: `_beforeTokenTransfer`フックで SBT フラグをチェック
- **例外**: ミント時とバーン時は転送可能

#### 5. インポート機能

```solidity
function mintImported(address to, string memory _metaUrl, uint16 _feeRate, bool _sbtFlag, address creator, string memory originalInfo) external returns (uint256)
```

- **概要**: 他プラットフォームから NFT をインポート
- **権限**: オーナーまたは承認されたインポーターのみ
- **特徴**: オリジナル情報を保持

### ストレージ設計（最適化済み）

#### スロット 1（32 バイト）

- `owner`: address（20 バイト）
- `mintFee`: uint96（12 バイト）

#### スロット 2

- `maxFeeRate`: uint16（2 バイト）
- `lastId`: uint128（16 バイト）
- `totalBurned`: uint128（16 バイト）

#### マッピング

- `metaUrl`: トークン ID からメタデータ URL へ
- `sbtFlag`: トークン ID から SBT フラグへ
- `totalDonations`: アドレスから累計寄付額へ
- `creatorTokens`: クリエイターから作成トークンリストへ
- `tokenCreator`: トークン ID からクリエイターへ
- `originalTokenInfo`: インポート元情報
- `importers`: インポート権限

### イベント

- `ConfigUpdated`: 設定変更時
- `Withdrawal`: 出金時
- `DonationReceived`: 寄付受領時
- `ImporterSet`: インポーター設定時
- `TransactionExecuted`: （ERC6551 から継承）

### セキュリティ機能

1. **ReentrancyGuard**: リエントランシー攻撃防止
2. **アクセス制御**: オーナー機能の制限
3. **パラメータ検証**:
   - maxFeeRate 上限（10%）
   - mintFee 上限（1 ETH）
   - ゼロアドレスチェック
4. **CEI パターン**: 状態変更後に外部呼び出し

## RoyaltyStandard Contract

### 基本情報

- **標準**: ERC-2981（NFT ロイヤリティ標準）
- **継承**: ERC165, IERC2981
- **用途**: トークンごとのロイヤリティ情報管理

### 主要機能

#### ロイヤリティ設定

```solidity
function _setTokenRoyalty(uint256 tokenId, address recipient, uint256 value) internal
```

- **パラメータ検証**:
  - recipient != address(0)
  - value <= 10000（100%）

#### ロイヤリティ情報取得

```solidity
function royaltyInfo(uint256 tokenId, uint256 salePrice) external view returns (address receiver, uint256 royaltyAmount)
```

- **計算**: royaltyAmount = (salePrice \* feeRate) / 10000

## Token Bound Account (TBA) System

### ERC6551Registry

#### 基本情報

- **標準**: ERC-6551（Token Bound Accounts）
- **用途**: NFT ごとのスマートコントラクトアカウント作成

#### 主要機能

```solidity
function createAccount(
    address implementation,
    uint256 chainId,
    address tokenContract,
    uint256 tokenId,
    uint256 salt,
    bytes calldata initData
) external returns (address)
```

- **動作**: CREATE2 を使用してアカウントを決定的にデプロイ
- **特徴**: 同じパラメータで常に同じアドレスを生成

### ERC6551Account

#### 基本情報

- **用途**: NFT が所有するスマートコントラクトウォレット
- **機能**: トランザクション実行、署名検証、資産保有

#### 主要機能

1. **トランザクション実行**

```solidity
function executeCall(address to, uint256 value, bytes calldata data) external payable returns (bytes memory result)
```

- **権限**: NFT の現在の所有者のみ
- **制限**:
  - self-destruct 禁止
  - delegatecall 禁止
  - 自己呼び出し禁止

2. **所有権確認**

```solidity
function owner() public view returns (address)
```

- **動作**: NFT の現在の所有者を返す

3. **署名検証**（ERC-1271）

```solidity
function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4 magicValue)
```

## 利用シナリオ

### 1. クリエイターが NFT を発行

1. クリエイターが作品を Arweave にアップロード
2. `mint`関数を呼び出し（mintFee 支払い）
3. NFT が発行され、クリエイターとして記録
4. ロイヤリティが自動設定

### 2. NFT の売買と寄付

1. 購入者が`transferFromWithDonation`で購入
2. 追加 ETH が売り手への寄付として記録
3. 将来の二次流通でロイヤリティが発生

### 3. TBA の活用

1. NFT ごとに`createAccount`でウォレット作成
2. NFT がトークンや ETH を保有可能
3. NFT 所有者が TBA 経由でトランザクション実行

### 4. SBT の発行

1. 実績や証明書として譲渡不可 NFT を発行
2. `_sbtFlag`を true に設定してミント
3. 転送が制限され、証明書として機能

## ガス最適化

1. **ストレージパッキング**: 関連変数を同一スロットに配置
2. **型の最適化**: uint256→uint96/uint16/uint128 へ
3. **削除演算子**: `delete`使用でガス還元
4. **内部呼び出し**: 外部呼び出しを避ける

## セキュリティ考慮事項

1. **リエントランシー**: NonReentrant モディファイア使用
2. **整数オーバーフロー**: Solidity 0.8.0 の自動チェック
3. **アクセス制御**: オーナー権限の適切な制限
4. **入力検証**: 全パラメータの妥当性確認

## 今後の拡張可能性

1. **マルチシグ対応**: オーナー機能の分散化
2. **ガバナンストークン**: コミュニティによる運営
3. **クロスチェーン対応**: 他チェーンとの相互運用
4. **メタバース連携**: 3D NFT やアバター対応

---

_本仕様書は 2025 年 7 月時点のものです。最新の実装は GitHub リポジトリを参照してください。_
