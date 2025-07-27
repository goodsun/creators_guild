# CreatorsGuildNFT エラーコード一覧

## エラーコード定義

| コード | 説明 | 発生箇所 |
|--------|------|----------|
| E1 | Insufficient Mint Fee | mint() - ミント手数料が不足 |
| E2 | Over Max Fee Rate | mint() - ロイヤリティ率が上限超過 |
| E3 | Not approved | 各転送関数 - 承認されていない |
| E4 | No value sent | transferFromWithCashback() - ETHが送信されていない |
| E5 | Invalid recipient | transferFromWithCashback() - 無効な受取人 |
| E6 | Transfer failed | transferFromWithCashback() - キャッシュバック送信失敗 |
| E7 | Owner only | 管理関数 - オーナー専用機能 |
| E8 | Fee too high | config() - 手数料率が高すぎる |
| E9 | Mint fee high | config() - ミント手数料が高すぎる |
| E10 | No balance | withdraw() - 残高なし |
| E11 | Withdrawal failed | withdraw() - 出金失敗 |
| E12 | SBT transfer blocked | _beforeTokenTransfer() - SBTの転送禁止 |
| E13 | Invalid importer | setImporter() - 無効なインポーターアドレス |
| E14 | Not authorized | mintImported() - 権限なし |
| E15 | Not owner nor approved | burn() - 所有者でも承認者でもない |

## 使用例

```javascript
try {
    await contract.mint(to, metaUrl, feeRate, false, { value: mintFee });
} catch (error) {
    if (error.message.includes("E1")) {
        console.error("ミント手数料が不足しています");
    } else if (error.message.includes("E2")) {
        console.error("ロイヤリティ率が高すぎます");
    }
}
```

## フロントエンドでのエラーハンドリング

```typescript
const ERROR_MESSAGES: Record<string, string> = {
    "E1": "ミント手数料が不足しています",
    "E2": "ロイヤリティ率が上限を超えています",
    "E3": "この操作を実行する権限がありません",
    "E4": "ETHを送信してください",
    "E5": "無効な受取人アドレスです",
    "E6": "送金に失敗しました",
    "E7": "オーナーのみ実行可能です",
    "E8": "手数料率が高すぎます（最大10%）",
    "E9": "ミント手数料が高すぎます（最大1 ETH）",
    "E10": "出金可能な残高がありません",
    "E11": "出金に失敗しました",
    "E12": "このトークンは譲渡できません（SBT）",
    "E13": "無効なインポーターアドレスです",
    "E14": "インポート権限がありません",
    "E15": "トークンの所有者または承認者ではありません"
};

function getErrorMessage(error: any): string {
    const errorString = error.toString();
    for (const [code, message] of Object.entries(ERROR_MESSAGES)) {
        if (errorString.includes(code)) {
            return message;
        }
    }
    return "不明なエラーが発生しました";
}
```