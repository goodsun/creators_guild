# ERC6551Account メソッド仕様書

## 概要
ERC6551Accountは、NFTが所有できるスマートコントラクトアカウント（Token Bound Account）の実装です。各NFTが独自のウォレットを持ち、トランザクションの実行や資産の保有が可能になります。

## 継承
- IERC165: インターフェース検出
- IERC1271: 署名検証標準
- IERC6551Account: Token Bound Account標準
- IERC721Receiver: NFT受信機能

## ストレージ

### nonce
```solidity
uint256 public nonce;
```

#### 説明
実行されたトランザクションの数を追跡。リプレイ攻撃防止とトランザクション順序の管理に使用。

---

## イベント

### TransactionExecuted
```solidity
event TransactionExecuted(address indexed target, uint256 value, bytes data);
```

#### 説明
トランザクションが実行された際に発行されるイベント

#### パラメータ
- `target`: 呼び出し先のアドレス
- `value`: 送信されたETHの量（wei）
- `data`: 実行されたコールデータ

---

## パブリック関数

### receive
```solidity
receive() external payable {}
```

#### 概要
ETHを受け取るためのフォールバック関数

#### 動作
- データなしでETHが送信された場合に呼び出される
- 受信したETHはコントラクトの残高に追加される

---

### executeCall
```solidity
function executeCall(
    address to,
    uint256 value,
    bytes calldata data
) external payable returns (bytes memory result)
```

#### 概要
NFTの所有者がこのアカウントを通じて任意のトランザクションを実行

#### パラメータ
| 名前 | 型 | 説明 |
|------|-----|------|
| to | address | 呼び出し先のアドレス |
| value | uint256 | 送信するETHの量（wei） |
| data | bytes | 実行するコールデータ |

#### 戻り値
- bytes: 呼び出しの結果データ

#### 必要条件
- `msg.sender == owner()`: NFTの現在の所有者のみ実行可能
- `to != address(0)`: "Invalid target address"
- `to != address(this)`: "Cannot call self"

#### セキュリティ制限
危険な操作を防ぐため、以下のセレクタは禁止：
- `0xff000000`: selfdestruct（自己破壊）
- `0xd4d9bdcd`: delegatecall（委任呼び出し）

#### 動作
1. 呼び出し者がNFT所有者であることを確認
2. ターゲットアドレスと操作の安全性を検証
3. nonceをインクリメント
4. TransactionExecutedイベントを発行
5. 外部呼び出しを実行
6. 失敗時は詳細なエラーメッセージでrevert

#### 使用例
```solidity
// ERC20トークンの転送
bytes memory data = abi.encodeWithSignature(
    "transfer(address,uint256)", 
    recipient, 
    amount
);
account.executeCall(tokenAddress, 0, data);

// ETHの送信
account.executeCall{value: 0.1 ether}(recipient, 0.1 ether, "");
```

---

### token
```solidity
function token() external view returns (uint256, address, uint256)
```

#### 概要
このアカウントが紐付けられているNFTの情報を取得

#### 戻り値
| 順序 | 型 | 説明 |
|------|-----|------|
| 1 | uint256 | チェーンID |
| 2 | address | NFTコントラクトのアドレス |
| 3 | uint256 | トークンID |

#### 実装
ERC6551AccountLibライブラリを使用してコントラクトのバイトコードから情報を抽出

---

### owner
```solidity
function owner() public view returns (address)
```

#### 概要
このアカウントを制御するNFTの現在の所有者を取得

#### 戻り値
- address: NFTの所有者アドレス（チェーンIDが異なる場合はaddress(0)）

#### 動作
1. ERC6551AccountLib.token()を呼び出してNFT情報を取得
2. チェーンIDが現在のチェーンと一致するか確認
3. 一致する場合、NFTコントラクトのownerOf()を呼び出して所有者を返す
4. 一致しない場合、address(0)を返す

---

### supportsInterface
```solidity
function supportsInterface(bytes4 interfaceId) public pure returns (bool)
```

#### 概要
このコントラクトがサポートするインターフェースを確認

#### パラメータ
| 名前 | 型 | 説明 |
|------|-----|------|
| interfaceId | bytes4 | 確認するインターフェースID |

#### 戻り値
- bool: サポートしている場合true

#### サポートインターフェース
- `0x01ffc9a7`: IERC165
- `0x6faff5f1`: IERC6551Account
- `0x150b7a02`: IERC721Receiver

---

### isValidSignature
```solidity
function isValidSignature(
    bytes32 hash,
    bytes memory signature
) external view returns (bytes4 magicValue)
```

#### 概要
ERC-1271標準に従った署名検証（スマートコントラクトによる署名）

#### パラメータ
| 名前 | 型 | 説明 |
|------|-----|------|
| hash | bytes32 | 署名されたメッセージのハッシュ |
| signature | bytes | 署名データ |

#### 戻り値
- bytes4: 有効な場合は`0x1626ba7e`、無効な場合は`0x00000000`

#### 動作
1. SignatureCheckerを使用してNFT所有者の署名を検証
2. 有効な場合、ERC1271のマジックバリュー（0x1626ba7e）を返す
3. 無効な場合、空のbytes4を返す

#### 使用例
```solidity
// オフチェーンで署名を作成
bytes32 messageHash = keccak256("Hello World");
bytes memory signature = // NFT所有者の署名

// オンチェーンで検証
bytes4 result = account.isValidSignature(messageHash, signature);
bool isValid = (result == 0x1626ba7e);
```

---

### onERC721Received
```solidity
function onERC721Received(
    address, /*operator*/
    address, /*from*/
    uint256, /*tokenId*/
    bytes calldata /*data*/
) external pure override returns (bytes4)
```

#### 概要
NFTを安全に受信するためのERC721Receiverインターフェース実装

#### パラメータ
- すべてのパラメータは使用されない（インターフェース準拠のため存在）

#### 戻り値
- bytes4: 常に`0x150b7a02`（this.onERC721Received.selector）

#### 動作
このアカウントがNFTを受信できることを示すマジックバリューを返す

---

## セキュリティ考慮事項

### 1. 所有権の検証
- すべての重要な操作でNFT所有者の確認が必須
- チェーンIDの検証により、クロスチェーン攻撃を防止

### 2. 危険な操作の防止
- selfdestruct: アカウントの永久的な破壊を防止
- delegatecall: アカウントのストレージ破壊を防止
- 自己呼び出し: 無限ループやストレージ破壊を防止

### 3. リエントランシー
- nonceのインクリメントにより状態を更新
- 外部呼び出し前にイベントを発行

### 4. エラーハンドリング
- 外部呼び出しの失敗時は、元のエラーメッセージを保持してrevert

---

## 使用パターン

### 基本的なETH送信
```solidity
// 0.1 ETHを送信
account.executeCall{value: 0.1 ether}(
    recipientAddress,
    0.1 ether,
    ""
);
```

### ERC20トークンの操作
```solidity
// approve呼び出し
bytes memory approveData = abi.encodeWithSignature(
    "approve(address,uint256)",
    spender,
    amount
);
account.executeCall(tokenAddress, 0, approveData);

// transfer呼び出し
bytes memory transferData = abi.encodeWithSignature(
    "transfer(address,uint256)",
    recipient,
    amount
);
account.executeCall(tokenAddress, 0, transferData);
```

### NFTの操作
```solidity
// NFTの転送
bytes memory transferData = abi.encodeWithSignature(
    "safeTransferFrom(address,address,uint256)",
    address(account),
    recipient,
    tokenId
);
account.executeCall(nftAddress, 0, transferData);
```

### DeFiプロトコルとの連携
```solidity
// Uniswapでのスワップ
bytes memory swapData = abi.encodeWithSignature(
    "swapExactETHForTokens(uint256,address[],address,uint256)",
    amountOutMin,
    path,
    address(account),
    deadline
);
account.executeCall{value: 0.1 ether}(uniswapRouter, 0.1 ether, swapData);
```

---

## 制限事項

1. **NFT所有者のみ操作可能**: セキュリティのため、マルチシグや追加の権限管理は実装されていない

2. **チェーンID依存**: 異なるチェーンのNFTは制御できない

3. **アップグレード不可**: アカウントの実装は固定（プロキシパターンを使用しない限り）

4. **ガス制限**: 複雑な操作はガスリミットに注意が必要