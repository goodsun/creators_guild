# CreatorsGuildNFTReader メソッド仕様書

## 概要
CreatorsGuildNFTReaderは、メインコントラクトのサイズを削減するために作成された読み取り専用のヘルパーコントラクトです。NFTの一覧取得や詳細情報の取得など、ガスを消費しない読み取り操作を提供します。

## コントラクト情報
- **目的**: CreatorsGuildNFTの読み取り機能を提供
- **特徴**: 
  - immutableなNFTコントラクト参照
  - 読み取り専用（stateを変更しない）
  - ガス効率的な一括データ取得

## コンストラクタ

### constructor
```solidity
constructor(address _nftContract)
```

#### 概要
CreatorsGuildNFTコントラクトのアドレスを設定

#### パラメータ
| 名前 | 型 | 説明 |
|------|-----|------|
| _nftContract | address | CreatorsGuildNFTコントラクトのアドレス |

#### 動作
- nftContractをimmutable変数として保存
- 以降、このアドレスのコントラクトから情報を読み取る

---

## パブリック関数

### getOwnedTokens
```solidity
function getOwnedTokens(address tokenOwner) external view returns (uint256[] memory)
```

#### 概要
特定のアドレスが所有する全てのトークンIDを取得

#### パラメータ
| 名前 | 型 | 説明 |
|------|-----|------|
| tokenOwner | address | 所有者のアドレス |

#### 戻り値
- uint256[]: 所有しているトークンIDの配列

#### 動作
1. NFTコントラクトのbalanceOfで所有数を取得
2. tokenOfOwnerByIndexで各トークンIDを取得
3. 配列として返す

#### 使用例
```javascript
const reader = new ethers.Contract(readerAddress, ABI, provider);
const tokenIds = await reader.getOwnedTokens(userAddress);
console.log(tokenIds); // [1, 5, 12, 23]
```

---

### getOwnedTokensDetailed
```solidity
function getOwnedTokensDetailed(address tokenOwner) external view returns (CreatorsGuildNFT.TokenDetail[] memory)
```

#### 概要
特定のアドレスが所有する全てのトークンの詳細情報を取得

#### パラメータ
| 名前 | 型 | 説明 |
|------|-----|------|
| tokenOwner | address | 所有者のアドレス |

#### 戻り値
- TokenDetail[]: トークンの詳細情報の配列

#### TokenDetail構造体
```solidity
struct TokenDetail {
    uint256 tokenId;      // トークンID
    string metaUrl;       // メタデータURL
    address currentOwner; // 現在の所有者
    address creator;      // クリエイター
    bool isSBT;          // SBTフラグ
    string originalInfo;  // インポート元情報
}
```

#### 動作
1. getOwnedTokensでトークンID一覧を取得
2. 各トークンIDについて詳細情報を収集
3. TokenDetail構造体の配列として返す

#### 使用例
```javascript
const details = await reader.getOwnedTokensDetailed(userAddress);
console.log(details);
// [
//   {
//     tokenId: 1,
//     metaUrl: "ipfs://...",
//     currentOwner: "0x123...",
//     creator: "0x456...",
//     isSBT: false,
//     originalInfo: ""
//   },
//   ...
// ]
```

---

### getTokensByCreatorDetailed
```solidity
function getTokensByCreatorDetailed(address creator) external view returns (CreatorsGuildNFT.TokenDetail[] memory)
```

#### 概要
特定のクリエイターが作成した全てのトークンの詳細情報を取得

#### パラメータ
| 名前 | 型 | 説明 |
|------|-----|------|
| creator | address | クリエイターのアドレス |

#### 戻り値
- TokenDetail[]: トークンの詳細情報の配列

#### 動作
1. NFTコントラクトのcreatorTokensマッピングからトークンID一覧を取得
2. 各トークンIDについて詳細情報を収集（現在の所有者も含む）
3. TokenDetail構造体の配列として返す

#### 使用例
```javascript
const createdNFTs = await reader.getTokensByCreatorDetailed(creatorAddress);
// クリエイターが作成した全NFTの詳細（現在の所有者情報も含む）
```

---

### getTokenDetailsBatch
```solidity
function getTokenDetailsBatch(uint256[] calldata tokenIds) external view returns (CreatorsGuildNFT.TokenDetail[] memory)
```

#### 概要
指定されたトークンIDのバッチで詳細情報を取得

#### パラメータ
| 名前 | 型 | 説明 |
|------|-----|------|
| tokenIds | uint256[] | 取得したいトークンIDの配列 |

#### 戻り値
- TokenDetail[]: トークンの詳細情報の配列

#### 動作
1. 提供されたトークンIDごとに詳細情報を収集
2. 存在しないトークンIDの場合はrevert
3. TokenDetail構造体の配列として返す

#### 使用例
```javascript
// 特定のトークンIDの詳細を一括取得
const tokenIds = [1, 5, 10, 15];
const details = await reader.getTokenDetailsBatch(tokenIds);
```

---

## ガス効率性

### RPC呼び出し回数の比較

#### 従来の方法（直接コントラクト呼び出し）
```javascript
// 10個のNFTを持つユーザーの場合
// 必要なRPC呼び出し: 1 + 10 + (10 * 5) = 61回
const balance = await nft.balanceOf(user);
for (let i = 0; i < balance; i++) {
    const tokenId = await nft.tokenOfOwnerByIndex(user, i);
    const metaUrl = await nft.tokenURI(tokenId);
    const creator = await nft.tokenCreator(tokenId);
    const isSBT = await nft.sbtFlag(tokenId);
    const originalInfo = await nft.originalTokenInfo(tokenId);
}
```

#### Readerコントラクトを使用
```javascript
// 必要なRPC呼び出し: 1回
const details = await reader.getOwnedTokensDetailed(user);
```

---

## デプロイと使用方法

### デプロイ
```javascript
const NFT = await ethers.getContractFactory("CreatorsGuildNFT");
const nft = await NFT.deploy("CreatorsGuild", "CG");
await nft.deployed();

const Reader = await ethers.getContractFactory("CreatorsGuildNFTReader");
const reader = await Reader.deploy(nft.address);
await reader.deployed();
```

### フロントエンドでの使用
```javascript
// コントラクトインスタンス
const nft = new ethers.Contract(nftAddress, nftABI, provider);
const reader = new ethers.Contract(readerAddress, readerABI, provider);

// 書き込み操作はメインコントラクトで
await nft.mint(to, metaUrl, feeRate, false, { value: mintFee });

// 読み取り操作はReaderコントラクトで
const ownedNFTs = await reader.getOwnedTokensDetailed(userAddress);
const createdNFTs = await reader.getTokensByCreatorDetailed(creatorAddress);
```

---

## セキュリティ考慮事項

1. **読み取り専用**: stateを変更する機能はないため、セキュリティリスクは最小限
2. **DoS対策**: 大量のNFTを持つアドレスに対してはガスリミットに注意
3. **データ整合性**: メインコントラクトの状態を直接読み取るため、常に最新データ

---

## ベストプラクティス

1. **キャッシュの活用**
```javascript
// 結果をキャッシュして再利用
const cache = new Map();
async function getCachedTokenDetails(owner) {
    const key = owner.toLowerCase();
    if (!cache.has(key)) {
        cache.set(key, await reader.getOwnedTokensDetailed(owner));
    }
    return cache.get(key);
}
```

2. **ページネーション**
```javascript
// 大量のNFTを扱う場合は、別途ページネーション機能を実装
async function getTokensPaginated(owner, offset, limit) {
    const allTokens = await reader.getOwnedTokens(owner);
    const page = allTokens.slice(offset, offset + limit);
    return reader.getTokenDetailsBatch(page);
}
```

3. **エラーハンドリング**
```javascript
try {
    const details = await reader.getOwnedTokensDetailed(address);
} catch (error) {
    if (error.message.includes("invalid address")) {
        console.error("無効なアドレス");
    }
}
```