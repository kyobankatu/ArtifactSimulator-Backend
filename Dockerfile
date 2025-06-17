# ベースイメージ
FROM python:3.9-slim

# ポート指定
EXPOSE 5000

# 必要なLinuxパッケージをインストール（不要なTesseract関連を削除）
RUN apt-get update && apt-get install -y \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && apt-get clean

# 作業ディレクトリを設定
WORKDIR /app

# 必要なファイルをコンテナにコピー
COPY requirements.txt /app/requirements.txt
COPY main.py /app/main.py

# Pythonライブラリをインストール
RUN pip install --no-cache-dir -r requirements.txt \
    && pip install opencv-python-headless \
    && pip install google-cloud-vision requests

# アプリケーションのエントリーポイント
CMD ["python", "main.py"]
