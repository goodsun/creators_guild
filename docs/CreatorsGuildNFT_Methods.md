# CreatorsGuildNFT メソッド仕様書

## 目次
1. [ミント関連](#ミント関連)
2. [転送関連](#転送関連)
3. [バーン関連](#バーン関連)
4. [管理関連](#管理関連)
5. [照会関連](#照会関連)
6. [パブリック変数・マッピング](#パブリック変数マッピング)
7. [内部関数](#内部関数)
8. [継承関数](#継承関数)
9. [エラーコード一覧](#エラーコード一覧)

---

## ミント関連

### mint
```solidity
function mint(address to, string memory _metaUrl, uint16 _feeRate, bool _sbtFlag) public payable
```

#### 概要
新しいNFTをミントする主要な関数

#### パラメータ
| 名前 | 型 | 説明 |
|------|-----|------|
| to | address | NFTの受取アドレス |
| _metaUrl | string | メタデータのURL（IPFS、HTTPSなど） |
| _feeRate | uint16 | ロイヤリティ率（ベーシスポイント、100 = 1%） |
| _sbtFlag | bool | Soul Bound Token（譲渡不可）フラグ |

#### 必要条件
- msg.value >= mintFee (E1)
- _feeRate <= maxFeeRate (E2)

#### 動作
1. ミント手数料の検証
2. 超過分を寄付として記録
3. トークンIDを自動採番（lastId++）
4. メタデータとSBTフラグを保存
5. NFTをミント
6. ロイヤリティ情報を設定（_feeRate * 100）
7. クリエイター情報を記録

#### イベント
なし（ERC721のTransferイベントは発生）

#### 使用例
```solidity
// 5%のロイヤリティでNFTをミント
contract.mint{value: 0.005 ether}(
    0x123..., 
    "ipfs://QmXxx...", 
    500,  // 5%
    false // 転送可能
);
```

---

### mintImported
```solidity
function mintImported(
    address to,
    string memory _metaUrl,
    uint16 _feeRate,
    bool _sbtFlag,
    address creator,
    string memory originalInfo
) external returns (uint256)
```

#### 概要
他プラットフォームからNFTをインポートするための特権関数

#### パラメータ
| 名前 | 型 | 説明 |
|------|-----|------|
| to | address | NFTの受取アドレス |
| _metaUrl | string | メタデータのURL |
| _feeRate | uint16 | ロイヤリティ率（ベーシスポイント） |
| _sbtFlag | bool | Soul Bound Tokenフラグ |
| creator | address | オリジナルのクリエイターアドレス |
| originalInfo | string | 元のNFT情報（コントラクトアドレス、トークンIDなど） |

#### 必要条件
- msg.sender == owner || importers[msg.sender] == true (E14)

#### 戻り値
- uint256: 新しくミントされたトークンID

#### 動作
1. 権限チェック
2. トークンIDを自動採番
3. メタデータ、SBTフラグ、オリジナル情報を保存
4. NFTをミント
5. ロイヤリティ情報を設定（creatorに対して）
6. クリエイター情報を記録

---

## 転送関連

### transferFromWithDonation
```solidity
function transferFromWithDonation(
    address from,
    address to,
    uint256 tokenId
) external payable nonReentrant
```

#### 概要
NFT転送と同時に受取人への寄付を行う

#### パラメータ
| 名前 | 型 | 説明 |
|------|-----|------|
| from | address | 送信元アドレス |
| to | address | 送信先アドレス |
| tokenId | uint256 | 転送するトークンID |

#### 必要条件
- msg.senderがトークンの所有者または承認済み (E3)

#### 動作
1. 権限チェック
2. NFTを転送
3. msg.value全額を受取人への寄付として記録
4. DonationReceivedイベントを発行

#### イベント
- DonationReceived(address from, address to, uint256 amount)

---

### safeTransferFromWithDonation
```solidity
function safeTransferFromWithDonation(
    address from,
    address to,
    uint256 tokenId,
    bytes memory data
) public payable nonReentrant
```

#### 概要
安全なNFT転送（ERC721Receiver確認付き）と寄付

#### パラメータ
| 名前 | 型 | 説明 |
|------|-----|------|
| from | address | 送信元アドレス |
| to | address | 送信先アドレス |
| tokenId | uint256 | 転送するトークンID |
| data | bytes | 追加データ |

#### 動作
transferFromWithDonationと同様だが、受信者がコントラクトの場合はERC721Receiverを実装していることを確認

---

### transferFromWithCashback
```solidity
function transferFromWithCashback(
    address from,
    address to,
    uint256 tokenId
) external payable nonReentrant
```

#### 概要
NFT転送時に購入者へ10%のキャッシュバックを提供

#### パラメータ
| 名前 | 型 | 説明 |
|------|-----|------|
| from | address | 送信元アドレス |
| to | address | 送信先アドレス（キャッシュバック受取人） |
| tokenId | uint256 | 転送するトークンID |

#### 必要条件
- msg.senderがトークンの所有者または承認済み (E3)
- msg.value > 0 (E4)
- to != address(0) (E5)

#### 動作
1. 権限チェック
2. 寄付額 = msg.value * 90%
3. キャッシュバック額 = msg.value * 10%
4. NFTを転送
5. 寄付額を記録
6. キャッシュバックを送信

#### エラー
- E6: キャッシュバック送信失敗時

---

## バーン関連

### burn
```solidity
function burn(uint256 tokenId) external
```

#### 概要
NFTを焼却（永久に削除）する

#### パラメータ
| 名前 | 型 | 説明 |
|------|-----|------|
| tokenId | uint256 | 焼却するトークンID |

#### 必要条件
- msg.senderがトークンの所有者、承認済み、またはコントラクトオーナー (E15)

#### 動作
1. 権限チェック
2. オリジナル情報とメタデータを削除
3. NFTを焼却（0xdEaDアドレスへ転送後、削除）
4. totalBurnedをインクリメント

---

## 管理関連

### config
```solidity
function config(
    uint16 _maxFeeRate,
    uint96 _mintFee
) external
```

#### 概要
コントラクトの基本設定を変更（オーナー専用）

#### パラメータ
| 名前 | 型 | 説明 |
|------|-----|------|
| _maxFeeRate | uint16 | 最大ロイヤリティ率（ベーシスポイント） |
| _mintFee | uint96 | ミント手数料（wei） |

#### 必要条件
- msg.sender == owner (E7)
- _maxFeeRate <= 1000 (10%) (E8)
- _mintFee <= 1 ether (E9)

#### イベント
- ConfigUpdated(uint16 maxFeeRate, uint96 mintFee, string name, string symbol)

---

### withdraw
```solidity
function withdraw() external nonReentrant
```

#### 概要
コントラクトに蓄積されたETHを引き出す（オーナー専用）

#### 必要条件
- msg.sender == owner (E7)
- address(this).balance > 0 (E10)

#### 動作
1. 残高を取得
2. Withdrawalイベントを発行
3. 全額をオーナーに送信

#### イベント
- Withdrawal(address owner, uint256 amount)

---

### setImporter
```solidity
function setImporter(address importer, bool status) external
```

#### 概要
インポート権限を持つアドレスを設定（オーナー専用）

#### パラメータ
| 名前 | 型 | 説明 |
|------|-----|------|
| importer | address | インポーター候補のアドレス |
| status | bool | 権限の有効/無効 |

#### 必要条件
- msg.sender == owner (E7)
- importer != address(0) (E13)

#### イベント
- ImporterSet(address importer, bool status)

---

## 照会関連

### tokenURI
```solidity
function tokenURI(uint256 tokenId) public view virtual override returns (string memory)
```

#### 概要
トークンのメタデータURIを取得

#### パラメータ
| 名前 | 型 | 説明 |
|------|-----|------|
| tokenId | uint256 | 照会するトークンID |

#### 戻り値
- string: メタデータのURI

#### エラー
- ERC721: invalid token ID: トークンが存在しない場合

---

## パブリック変数・マッピング

以下の変数・マッピングはpublicとして宣言されているため、直接アクセス可能です：

### 変数
| 名前 | 型 | 説明 |
|------|-----|------|
| owner | address | コントラクトのオーナーアドレス |
| mintFee | uint96 | ミント手数料（wei） |
| maxFeeRate | uint16 | 最大ロイヤリティ率（ベーシスポイント） |
| lastId | uint128 | 最後にミントされたトークンID |
| totalBurned | uint128 | 累計焼却トークン数 |

### マッピング
| 名前 | キー型 | 値型 | 説明 |
|------|---------|-------|------|
| metaUrl | uint256 | string | トークンIDからメタデータURLへのマッピング |
| sbtFlag | uint256 | bool | トークンIDからSBTフラグへのマッピング |
| totalDonations | address | uint256 | アドレスから累計寄付額へのマッピング |
| creatorTokens | address | uint256[] | クリエイターアドレスからトークンID配列へのマッピング |
| tokenCreator | uint256 | address | トークンIDからクリエイターアドレスへのマッピング |
| originalTokenInfo | uint256 | string | トークンIDからオリジナル情報へのマッピング |
| importers | address | bool | アドレスからインポート権限へのマッピング |

#### 使用例
```javascript
// 変数の取得
const owner = await contract.owner();
const mintFee = await contract.mintFee();
const maxFeeRate = await contract.maxFeeRate();
const lastId = await contract.lastId();
const totalBurned = await contract.totalBurned();

// マッピングの取得
const metaUrl = await contract.metaUrl(tokenId);
const isSBT = await contract.sbtFlag(tokenId);
const donations = await contract.totalDonations(userAddress);
const creator = await contract.tokenCreator(tokenId);
const isImporter = await contract.importers(address);
const originalInfo = await contract.originalTokenInfo(tokenId);

// creatorTokensの取得（配列要素の取得には特別なメソッドが必要）
const tokenCount = await contract.getCreatorTokenCount(creator);
for (let i = 0; i < tokenCount; i++) {
    const tokenId = await contract.creatorTokens(creator, i);
}
```

---

### getCreators
```solidity
function getCreators() external view returns (address[] memory)
```

#### 概要
全クリエイターのアドレスリストを取得

#### 戻り値
- address[]: クリエイターアドレスの配列

---


### getCreatorCount
```solidity
function getCreatorCount() external view returns (uint256)
```

#### 概要
登録されているクリエイターの総数を取得

#### 戻り値
- uint256: クリエイター数

---

### getCreatorTokenCount
```solidity
function getCreatorTokenCount(address creator) external view returns (uint256)
```

#### 概要
特定クリエイターが作成したトークンの総数を取得

#### パラメータ
| 名前 | 型 | 説明 |
|------|-----|------|
| creator | address | クリエイターのアドレス |

#### 戻り値
- uint256: トークン数

---


## 内部関数

### _beforeTokenTransfer
```solidity
function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
) internal virtual override
```

#### 概要
トークン転送前のフック関数（SBTチェック）

#### 動作
- fromとtoが両方ゼロアドレスでない場合（転送時）
- toが焼却アドレス（0xdEaD）でない場合
- SBTフラグがtrueの場合は転送を拒否

#### エラー
- E12: SBTの転送試行時

---

### _burn
```solidity
function _burn(uint256 tokenId) internal virtual override
```

#### 概要
トークンを焼却する内部関数

#### 動作
1. トークンを0xdEaDアドレスに転送
2. ERC721の_burn関数を呼び出し
3. totalBurnedをインクリメント

---

## 継承関数

### supportsInterface
```solidity
function supportsInterface(bytes4 interfaceId) 
    public view virtual override(ERC721Enumerable, RoyaltyStandard) 
    returns (bool)
```

#### 概要
コントラクトがサポートするインターフェースを確認

#### サポートインターフェース
- ERC721
- ERC721Enumerable
- ERC2981（ロイヤリティ）
- ERC165

---

## エラーコード一覧

| コード | 説明 | 発生箇所 |
|--------|------|----------|
| E1 | ミント手数料が不足 | mint() |
| E2 | ロイヤリティ率が最大値を超過 | mint() |
| E3 | トークンの所有者または承認済みでない | transferFromWithDonation(), safeTransferFromWithDonation(), transferFromWithCashback() |
| E4 | msg.valueが0 | transferFromWithCashback() |
| E5 | 送信先アドレスが0x0 | transferFromWithCashback() |
| E6 | キャッシュバック送信失敗 | transferFromWithCashback() |
| E7 | コントラクトオーナーでない | config(), withdraw(), setImporter() |
| E8 | 最大ロイヤリティ率が1000を超過 | config() |
| E9 | ミント手数料が1 etherを超過 | config() |
| E10 | コントラクト残高が0 | withdraw() |
| E11 | ETH送信失敗 | withdraw() |
| E12 | SBTの転送試行 | _beforeTokenTransfer() |
| E13 | インポーターアドレスが0x0 | setImporter() |
| E14 | インポート権限なし | mintImported() |
| E15 | バーン権限なし | burn() |