# CreatorsGuildNFT メソッド仕様書

## 目次
1. [ミント関連](#ミント関連)
2. [転送関連](#転送関連)
3. [バーン関連](#バーン関連)
4. [管理関連](#管理関連)
5. [照会関連](#照会関連)
6. [内部関数](#内部関数)

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
- msg.value >= mintFee
- _feeRate <= maxFeeRate

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
- msg.sender == owner || importers[msg.sender] == true

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
- msg.senderがトークンの所有者または承認済み

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
- msg.senderがトークンの所有者または承認済み
- msg.value > 0
- to != address(0)

#### 動作
1. 権限チェック
2. 寄付額 = msg.value * 90%
3. キャッシュバック額 = msg.value * 10%
4. NFTを転送
5. 寄付額を記録
6. キャッシュバックを送信

#### エラー
- "Cashback transfer failed": キャッシュバック送信失敗時

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
- msg.senderがトークンの所有者、承認済み、またはコントラクトオーナー

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
    uint256 _maxFeeRate,
    uint256 _mintFee,
    string memory newName,
    string memory newSymbol
) external
```

#### 概要
コントラクトの基本設定を変更（オーナー専用）

#### パラメータ
| 名前 | 型 | 説明 |
|------|-----|------|
| _maxFeeRate | uint256 | 最大ロイヤリティ率（ベーシスポイント） |
| _mintFee | uint256 | ミント手数料（wei） |
| newName | string | 新しいトークン名（現在は未使用） |
| newSymbol | string | 新しいシンボル（現在は未使用） |

#### 必要条件
- msg.sender == owner
- _maxFeeRate <= 1000 (10%)
- _mintFee <= 1 ether

#### イベント
- ConfigUpdated(uint256 maxFeeRate, uint256 mintFee, string name, string symbol)

---

### withdraw
```solidity
function withdraw() external nonReentrant
```

#### 概要
コントラクトに蓄積されたETHを引き出す（オーナー専用）

#### 必要条件
- msg.sender == owner
- address(this).balance > 0

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
- msg.sender == owner
- importer != address(0)

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
- "ERC721: invalid token ID": トークンが存在しない場合

---

### getOwner
```solidity
function getOwner() external view returns (address)
```

#### 概要
コントラクトのオーナーアドレスを取得

#### 戻り値
- address: オーナーのアドレス

---

### getMintFee
```solidity
function getMintFee() external view returns (uint256)
```

#### 概要
現在のミント手数料を取得

#### 戻り値
- uint256: ミント手数料（wei）

---

### getMaxFeeRate
```solidity
function getMaxFeeRate() external view returns (uint256)
```

#### 概要
最大ロイヤリティ率を取得

#### 戻り値
- uint256: 最大ロイヤリティ率（ベーシスポイント）

---

### getLastId
```solidity
function getLastId() external view returns (uint256)
```

#### 概要
最後にミントされたトークンIDを取得

#### 戻り値
- uint256: 最新のトークンID

---

### getTotalDonations
```solidity
function getTotalDonations(address donor) external view returns (uint256)
```

#### 概要
特定アドレスの累計寄付額を取得

#### パラメータ
| 名前 | 型 | 説明 |
|------|-----|------|
| donor | address | 照会するアドレス |

#### 戻り値
- uint256: 累計寄付額（wei）

---

### isSBT
```solidity
function isSBT(uint256 tokenId) external view returns (bool)
```

#### 概要
トークンがSoul Bound Token（譲渡不可）かを確認

#### パラメータ
| 名前 | 型 | 説明 |
|------|-----|------|
| tokenId | uint256 | 照会するトークンID |

#### 戻り値
- bool: SBTの場合true

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

### getCreatorTokens
```solidity
function getCreatorTokens(address creator) external view returns (uint256[] memory)
```

#### 概要
特定クリエイターが作成した全トークンIDを取得

#### パラメータ
| 名前 | 型 | 説明 |
|------|-----|------|
| creator | address | クリエイターのアドレス |

#### 戻り値
- uint256[]: トークンIDの配列

---

### getTokenCreator
```solidity
function getTokenCreator(uint256 tokenId) external view returns (address)
```

#### 概要
特定トークンのクリエイターアドレスを取得

#### パラメータ
| 名前 | 型 | 説明 |
|------|-----|------|
| tokenId | uint256 | 照会するトークンID |

#### 戻り値
- address: クリエイターのアドレス

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

### getTotalBurned
```solidity
function getTotalBurned() external view returns (uint256)
```

#### 概要
これまでに焼却されたトークンの総数を取得

#### 戻り値
- uint256: 焼却されたトークン数

---

### getOriginalTokenInfo
```solidity
function getOriginalTokenInfo(uint256 tokenId) external view returns (string memory)
```

#### 概要
インポートされたトークンのオリジナル情報を取得

#### パラメータ
| 名前 | 型 | 説明 |
|------|-----|------|
| tokenId | uint256 | 照会するトークンID |

#### 戻り値
- string: オリジナルNFTの情報

---

### isImporter
```solidity
function isImporter(address account) external view returns (bool)
```

#### 概要
特定アドレスがインポート権限を持つか確認

#### パラメータ
| 名前 | 型 | 説明 |
|------|-----|------|
| account | address | 確認するアドレス |

#### 戻り値
- bool: インポート権限がある場合true

---

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

#### 使用例
```javascript
// アドレスが所有する全NFTを取得
const ownedTokenIds = await contract.getOwnedTokens("0x123...");
console.log(ownedTokenIds); // [1, 5, 12, 23]

// 詳細情報も含めて取得
const detailedNFTs = await Promise.all(
    ownedTokenIds.map(async (tokenId) => ({
        tokenId: tokenId.toString(),
        uri: await contract.tokenURI(tokenId),
        creator: await contract.getTokenCreator(tokenId),
        isSBT: await contract.isSBT(tokenId)
    }))
);
```

---

### getTokensByCreator
```solidity
function getTokensByCreator(address creator) external view returns (uint256[] memory)
```

#### 概要
特定のクリエイターが作成した全てのトークンIDを取得（getCreatorTokensのエイリアス）

#### パラメータ
| 名前 | 型 | 説明 |
|------|-----|------|
| creator | address | クリエイターのアドレス |

#### 戻り値
- uint256[]: クリエイターが作成したトークンIDの配列

#### 使用例
```javascript
// クリエイターが作成した全NFTを取得
const createdTokenIds = await contract.getTokensByCreator("0x456...");
console.log(createdTokenIds); // [2, 7, 15, 28]

// getCreatorTokensと同じ結果
const sameResult = await contract.getCreatorTokens("0x456...");
console.log(createdTokenIds.toString() === sameResult.toString()); // true
```

#### 関連メソッド
- `getCreatorTokens`: 同じ機能（こちらも利用可能）
- `getCreatorTokenCount`: トークン数のみを取得

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
- "SBT: Token transfer not allowed": SBTの転送試行時

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