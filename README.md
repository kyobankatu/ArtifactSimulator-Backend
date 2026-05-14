# Artifact Simulator (Backend)

原神の聖遺物強化シミュレーター用バックエンドAPIサーバーです。
聖遺物のスクリーンショットをOCRで読み取り、強化後のスコア分布を計算します。

## 起動方法

### ローカル

```bash
pip install -r requirements.txt
GOOGLE_CLOUD_VISION_API_KEY=<your-api-key> python main.py
```

### Docker

```bash
docker build -t artifact-simulator .
docker run -p 5000:5000 -e GOOGLE_CLOUD_VISION_API_KEY=<your-api-key> artifact-simulator
```

サーバーは `http://localhost:5000` で起動します。

## 環境変数

| 変数名 | 説明 |
|--------|------|
| `GOOGLE_CLOUD_VISION_API_KEY` | Google Cloud Vision API のAPIキー（必須） |

## k3s デプロイ

バックエンドは外部公開せず、k3s 内部の `ClusterIP` Service として動かします。
フロントエンド nginx の `/api/` proxy から `artifact-backend` Service 経由で呼び出します。

```bash
kubectl -n artifact-simulator create secret generic artifact-backend-secret \
  --from-literal=GOOGLE_CLOUD_VISION_API_KEY='<your-api-key>' \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f k8s/artifact-simulator-backend.yaml
```

```bash
docker build -t artifact-simulator-backend:latest .
```

`k8s/artifact-backend-secret.example.yaml` は Secret の形を示すサンプルです。
実際のAPIキーを含む YAML は Git 管理しないでください。

## API

### `POST /scan-img`

聖遺物のスクリーンショットをOCRで解析し、オプション情報とスコアを返します。

**リクエスト（multipart/form-data）**

| フィールド | 型 | 説明 |
|---|---|---|
| `image` | file | 聖遺物のスクリーンショット |
| `score_type` | string | スコア計算方式: `atk` / `hp` / `em` |
| `is_new` | string | `"true"` = Luna 1以降（4枠目オプションが強化前に表示される） |

**レスポンス（JSON）**

```json
{
  "option": 3,
  "position": "時の砂",
  "main_op": "atk%",
  "is_crit_dmg": true,
  "is_crit_rate": true,
  "is_atk": false,
  "is_hp": false,
  "is_em": false,
  "init": 42.5,
  "score_type": "atk",
  "level": 12,
  "active_op": "crit-rate",
  "active_op_value": 3.5
}
```

---

### `POST /get-dist`

強化後のスコア分布グラフ（PNG画像）を返します。

**リクエスト（JSON）**

| フィールド | 型 | 説明 |
|---|---|---|
| `option` | int | 現在のサブオプション数（3 or 4） |
| `main_op` | string | メインオプション |
| `crit_dmg` | bool | 会心ダメージあり |
| `crit_rate` | bool | 会心率あり |
| `atk` | bool | 攻撃力%あり |
| `hp` | bool | HP%あり |
| `em` | bool | 元素熟知あり |
| `init` | float | 現在のスコア |
| `score` | float | 目標スコア |
| `count` | int | 残り強化回数 |
| `start_count` | int | 強化開始時のカウント（エリクシル計算用） |
| `score_type` | string | `atk` / `hp` / `em` |
| `elixir` | bool | エリクシルを使用するか |
| `elixir_option` | array | エリクシルで指定するオプション名の配列 |
| `is_new` | bool | Luna 1以降か |
| `active_op` | string | 4枠目のオプション名（`is_new=true` のとき） |
| `active_op_value` | float | 4枠目の現在値（`is_new=true` のとき） |
| `bold` | bool | スコアを区間ごとにまとめて表示するか |
| `bold_space` | float | まとめる区間幅（`bold=true` のとき） |

**レスポンス**: PNG画像

---

### `POST /get-data`

強化後のスコア統計情報を返します。リクエスト形式は `/get-dist` と同じ（`bold`/`bold_space` を除く）。

**レスポンス（JSON）**

```json
{
  "percentile": [
    [達成確率%, 目標スコア],
    [0, 最小スコア],
    [25, 25パーセンタイル],
    [50, 中央値],
    [75, 75パーセンタイル],
    [100, 最大スコア]
  ],
  "average": 55.2,
  "variance": 12.3,
  "skewness": 0.4,
  "kurtosis": -0.2
}
```

## スコア計算方式

| スコアタイプ | 計算式 |
|---|---|
| `atk` | 会心ダメージ + 会心率×2 + 攻撃力% |
| `hp`  | 会心ダメージ + 会心率×2 + HP% |
| `em`  | 会心ダメージ + 会心率×2 + 元素熟知÷4 |

## ゲームシステム対応

- **Luna 1以前**: 4枠目オプションが強化するまで不明 → 可能性のある全オプションを確率的に計算
- **Luna 1以降**: 強化前から4枠目オプションが確定表示される → `is_new=true` + `active_op` で指定
- **エリクシルシステム**: 2ターンサイクルで指定オプションへの最低保証が発動 → `elixir=true` + `elixir_option` で指定
