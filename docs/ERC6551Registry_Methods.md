# ERC6551Registry メソッド仕様書

## 概要
ERC6551Registryは、Token Bound Account（TBA）を作成・管理するファクトリーコントラクトです。CREATE2を使用して、NFTごとに決定的なアドレスでスマートコントラクトアカウントをデプロイします。

## 継承
- IERC6551Registry: ERC-6551標準インターフェース

## イベント

### AccountCreated
```solidity
event AccountCreated(
    address account,
    address implementation,
    uint256 chainId,
    address tokenContract,
    uint256 tokenId,
    uint256 salt
);
```

#### 説明
新しいToken Bound Accountが作成された際に発行されるイベント

#### パラメータ
- `account`: 作成されたアカウントのアドレス
- `implementation`: 使用された実装コントラクトのアドレス
- `chainId`: 対象のチェーンID
- `tokenContract`: NFTコントラクトのアドレス
- `tokenId`: NFTのトークンID
- `salt`: CREATE2で使用されたソルト値

---

## カスタムエラー

### InitializationFailed
```solidity
error InitializationFailed();
```

#### 説明
アカウントの初期化が失敗した場合にスローされるエラー

---

## パブリック関数

### createAccount
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

#### 概要
新しいToken Bound Accountを作成またはアドレスを返す

#### パラメータ
| 名前 | 型 | 説明 |
|------|-----|------|
| implementation | address | アカウント実装コントラクトのアドレス |
| chainId | uint256 | NFTが存在するチェーンID |
| tokenContract | address | NFTコントラクトのアドレス |
| tokenId | uint256 | NFTのトークンID |
| salt | uint256 | アドレス生成に使用するソルト値 |
| initData | bytes | 初期化時に実行するデータ（オプション） |

#### 戻り値
- address: 作成されたアカウントのアドレス（既存の場合は既存のアドレス）

#### 動作
1. CREATE2用のバイトコードを生成
2. CREATE2でアドレスを計算
3. アドレスにコードが存在しない場合：
   - CREATE2でアカウントをデプロイ
   - AccountCreatedイベントを発行
4. initDataが提供されている場合：
   - アカウントに対してinitDataを実行
   - 失敗した場合はInitializationFailedエラー
5. アカウントアドレスを返す

#### 使用例
```solidity
// 基本的なアカウント作成
address account = registry.createAccount(
    implementationAddress,
    1, // Ethereum mainnet
    nftContractAddress,
    tokenId,
    0, // salt
    "" // 初期化データなし
);

// 初期化データ付きでアカウント作成
bytes memory initData = abi.encodeWithSignature("initialize()");
address account = registry.createAccount(
    implementationAddress,
    1,
    nftContractAddress,
    tokenId,
    0,
    initData
);
```

---

### account
```solidity
function account(
    address implementation,
    uint256 chainId,
    address tokenContract,
    uint256 tokenId,
    uint256 salt
) external view returns (address)
```

#### 概要
指定されたパラメータに対応するアカウントアドレスを計算（デプロイせずに）

#### パラメータ
| 名前 | 型 | 説明 |
|------|-----|------|
| implementation | address | アカウント実装コントラクトのアドレス |
| chainId | uint256 | NFTが存在するチェーンID |
| tokenContract | address | NFTコントラクトのアドレス |
| tokenId | uint256 | NFTのトークンID |
| salt | uint256 | アドレス生成に使用するソルト値 |

#### 戻り値
- address: 計算されたアカウントアドレス

#### 動作
1. _creationCode関数でバイトコードを生成
2. Create2.computeAddressでアドレスを計算
3. アドレスを返す（実際のデプロイは行わない）

#### 使用例
```solidity
// アカウントアドレスを事前に確認
address predictedAccount = registry.account(
    implementationAddress,
    1,
    nftContractAddress,
    tokenId,
    0
);

// 実際にデプロイされているか確認
bool isDeployed = predictedAccount.code.length > 0;
```

---

## 内部関数

### _creationCode
```solidity
function _creationCode(
    address implementation_,
    uint256 chainId_,
    address tokenContract_,
    uint256 tokenId_,
    uint256 salt_
) internal pure returns (bytes memory)
```

#### 概要
CREATE2デプロイ用のバイトコードを生成

#### パラメータ
- `implementation_`: 実装コントラクトのアドレス
- `chainId_`: チェーンID
- `tokenContract_`: NFTコントラクトのアドレス
- `tokenId_`: トークンID
- `salt_`: ソルト値

#### 戻り値
- bytes: EIP-1167プロキシバイトコード + パラメータ

#### 動作
1. ERC6551BytecodeFetcher.getCreationCodeを呼び出し
2. EIP-1167最小プロキシ + エンコードされたパラメータを含むバイトコードを生成

---

## 使用パターン

### 基本的なTBA作成
```solidity
// NFT ID 123のアカウントを作成
address tba = registry.createAccount(
    0x1234..., // 実装アドレス
    1,         // Ethereum mainnet
    nftContract,
    123,       // トークンID
    0,         // salt
    ""         // 初期化データなし
);
```

### 複数のアカウント作成（異なるsalt）
```solidity
// 同じNFTに対して複数のアカウントを作成
address account1 = registry.createAccount(implementation, 1, nft, 123, 0, "");
address account2 = registry.createAccount(implementation, 1, nft, 123, 1, "");
address account3 = registry.createAccount(implementation, 1, nft, 123, 2, "");
```

### クロスチェーンNFTのアカウント
```solidity
// Polygon上のNFTのアカウントをEthereumに作成
address account = registry.createAccount(
    implementation,
    137,  // Polygon chainId
    polygonNFT,
    tokenId,
    0,
    ""
);
```

### 初期化付きアカウント作成
```solidity
// 初期設定を含むアカウント作成
bytes memory initData = abi.encodeWithSignature(
    "initialize(address,uint256)",
    owner,
    initialValue
);

address account = registry.createAccount(
    implementation,
    1,
    nftContract,
    tokenId,
    0,
    initData
);
```

---

## CREATE2の仕組み

### アドレス計算式
```
address = keccak256(
    0xff,
    deployer_address,
    salt,
    keccak256(bytecode)
)
```

### 決定的アドレスの利点
1. **予測可能性**: デプロイ前にアドレスが分かる
2. **再現性**: 同じパラメータで常に同じアドレス
3. **カウンターファクチュアル**: デプロイ前から資産を受け取れる

---

## セキュリティ考慮事項

### 1. 実装コントラクトの検証
- 悪意のある実装アドレスを使用しないよう注意
- 信頼できる実装のみを使用

### 2. 初期化データの検証
- initDataは任意のコードを実行可能
- 不正なデータによる攻撃に注意

### 3. チェーンIDの重要性
- 異なるチェーンのNFTに対してアカウントを作成可能
- チェーンIDの検証が重要

---

## ベストプラクティス

### 1. Salt値の管理
```solidity
// 用途別にsaltを分ける
uint256 TRADING_ACCOUNT_SALT = 0;
uint256 STAKING_ACCOUNT_SALT = 1;
uint256 GAMING_ACCOUNT_SALT = 2;
```

### 2. アカウント存在確認
```solidity
function getOrCreateAccount(...) returns (address) {
    address predicted = registry.account(...);
    
    if (predicted.code.length == 0) {
        // アカウントが存在しない場合のみ作成
        return registry.createAccount(...);
    }
    
    return predicted;
}
```

### 3. バッチ作成
```solidity
function createMultipleAccounts(
    uint256[] calldata tokenIds
) external {
    for (uint i = 0; i < tokenIds.length; i++) {
        registry.createAccount(
            implementation,
            chainId,
            tokenContract,
            tokenIds[i],
            0,
            ""
        );
    }
}
```

---

## ERC-6551標準について

### 目的
- NFTに関連付けられたスマートコントラクトアカウントの標準化
- NFTがトランザクションを実行し、資産を保有可能に
- NFTの機能性とユーティリティの拡張

### 特徴
- **決定的アドレス**: CREATE2による予測可能なアドレス
- **チェーン間互換性**: 異なるチェーンのNFTをサポート
- **柔軟な実装**: 任意の実装コントラクトを使用可能

### ユースケース
1. **NFTウォレット**: NFTが他のトークンを保有
2. **自律的NFT**: NFTが独自にトランザクションを実行
3. **ゲーミング**: キャラクターNFTがアイテムを装備
4. **DeFi統合**: NFTがDeFiプロトコルと直接やり取り