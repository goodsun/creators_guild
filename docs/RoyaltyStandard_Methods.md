# RoyaltyStandard メソッド仕様書

## 概要
RoyaltyStandardは、ERC-2981 NFTロイヤリティ標準を実装する抽象コントラクトです。NFTの二次流通時にクリエイターへのロイヤリティ支払いを標準化します。

## 定数

### INVERSE_BASIS_POINT
```solidity
uint16 public constant INVERSE_BASIS_POINT = 10000;
```

#### 説明
ロイヤリティ計算の基準値。10000 = 100%を表す。

#### 使用例
- 1000 = 10%
- 500 = 5%
- 250 = 2.5%
- 100 = 1%

---

## ストレージ

### royalties
```solidity
mapping(uint256 => RoyaltyInfo) public royalties;
```

#### 説明
トークンIDごとのロイヤリティ情報を格納するマッピング

#### RoyaltyInfo構造体
```solidity
struct RoyaltyInfo {
    address recipient;  // ロイヤリティ受取人
    uint16 feeRate;    // ロイヤリティ率（ベーシスポイント）
}
```

---

## パブリック関数

### supportsInterface
```solidity
function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(ERC165, IERC165)
    returns (bool)
```

#### 概要
コントラクトがサポートするインターフェースを確認

#### パラメータ
| 名前 | 型 | 説明 |
|------|-----|------|
| interfaceId | bytes4 | 確認するインターフェースID |

#### 戻り値
- bool: サポートしている場合true

#### サポートインターフェース
- `0x2a55205a`: ERC-2981（IERC2981）
- その他ERC165でサポートされるインターフェース

#### 実装
```solidity
return
    interfaceId == type(IERC2981).interfaceId || // 0x2a55205a
    super.supportsInterface(interfaceId);
```

---

### royaltyInfo
```solidity
function royaltyInfo(uint256 tokenId, uint256 salePrice)
    external
    view
    override
    returns (address receiver, uint256 royaltyAmount)
```

#### 概要
特定のトークンIDと販売価格に基づくロイヤリティ情報を取得（ERC-2981標準）

#### パラメータ
| 名前 | 型 | 説明 |
|------|-----|------|
| tokenId | uint256 | 照会するトークンID |
| salePrice | uint256 | 販売価格（wei） |

#### 戻り値
| 名前 | 型 | 説明 |
|------|-----|------|
| receiver | address | ロイヤリティ受取人のアドレス |
| royaltyAmount | uint256 | ロイヤリティ金額（wei） |

#### 計算式
```
royaltyAmount = (salePrice * feeRate) / INVERSE_BASIS_POINT
```

#### 使用例
```solidity
// トークンID 1が1 ETHで売却された場合のロイヤリティを取得
(address receiver, uint256 amount) = contract.royaltyInfo(1, 1 ether);
// feeRateが500（5%）の場合、amount = 0.05 ether
```

#### 注意事項
- トークンが存在しない場合でも、ゼロアドレスと0を返す（revertしない）
- ロイヤリティが設定されていないトークンは、ゼロアドレスと0を返す

---

## 内部関数

### _setTokenRoyalty
```solidity
function _setTokenRoyalty(
    uint256 tokenId,
    address recipient,
    uint256 value
) internal
```

#### 概要
特定のトークンにロイヤリティ情報を設定する内部関数

#### パラメータ
| 名前 | 型 | 説明 |
|------|-----|------|
| tokenId | uint256 | 設定するトークンID |
| recipient | address | ロイヤリティ受取人のアドレス |
| value | uint256 | ロイヤリティ率（ベーシスポイント） |

#### 必要条件
- `recipient != address(0)`: "RoyaltyStandard: Invalid recipient"
- `value <= INVERSE_BASIS_POINT`: "RoyaltyStandard: Royalty fee too high"

#### 動作
1. 受取人アドレスの検証（ゼロアドレス不可）
2. ロイヤリティ率の検証（100%以下）
3. RoyaltyInfo構造体を作成して保存
4. valueはuint16にキャストされて保存

#### 使用例（継承コントラクト内）
```solidity
// 5%のロイヤリティを設定
_setTokenRoyalty(tokenId, creatorAddress, 500);

// 2.5%のロイヤリティを設定
_setTokenRoyalty(tokenId, creatorAddress, 250);
```

#### セキュリティ
- オーバーフロー防止: valueが65535を超える場合でも、検証により10000以下であることが保証される

---

## 実装パターン

### 典型的な使用方法

```solidity
contract MyNFT is ERC721, RoyaltyStandard {
    function mint(address to, uint256 tokenId, uint16 royaltyRate) public {
        _mint(to, tokenId);
        
        // ミント時にロイヤリティを設定（例: 5%）
        _setTokenRoyalty(tokenId, msg.sender, royaltyRate);
    }
    
    function supportsInterface(bytes4 interfaceId) 
        public view override(ERC721, RoyaltyStandard) 
        returns (bool) 
    {
        return super.supportsInterface(interfaceId);
    }
}
```

### マーケットプレイスでの利用

```solidity
// マーケットプレイスコントラクト内
function executeSale(uint256 tokenId, uint256 salePrice) external payable {
    // ロイヤリティ情報を取得
    (address royaltyReceiver, uint256 royaltyAmount) = 
        nftContract.royaltyInfo(tokenId, salePrice);
    
    // ロイヤリティを支払う
    if (royaltyAmount > 0) {
        payable(royaltyReceiver).transfer(royaltyAmount);
    }
    
    // 残額を売り手に支払う
    payable(seller).transfer(salePrice - royaltyAmount);
}
```

---

## ERC-2981標準について

### 目的
- NFTの二次流通時のロイヤリティ支払いを標準化
- マーケットプレイス間での互換性を確保
- クリエイターの収益機会を保護

### 特徴
- トークンごとに異なるロイヤリティ設定が可能
- ロイヤリティ受取人の変更が可能
- 販売価格に応じた動的な計算

### 制限事項
- ロイヤリティの支払いは強制ではない（マーケットプレイスの実装次第）
- オンチェーンでの自動執行はない
- マーケットプレイスがERC-2981をサポートしている必要がある

---

## ベストプラクティス

1. **ロイヤリティ率の設定**
   - 一般的には2.5%～10%が推奨
   - 高すぎるロイヤリティは流動性を阻害する可能性

2. **受取人の管理**
   - マルチシグウォレットの使用を検討
   - 受取人変更機能の実装を検討

3. **ゼロアドレスチェック**
   - 必ず受取人がゼロアドレスでないことを確認

4. **ガス効率**
   - RoyaltyInfo構造体は1つのストレージスロットに収まる（20 + 2 = 22バイト）