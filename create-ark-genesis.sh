#!/bin/bash

#############################################
# ARK Genesis Service Creator
# ark-island.service をベースに
# ark-Genesis.service を新規作成するスクリプト
#############################################

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo ./create-ark-genesis.sh)"
  exit 1
fi

SERVICE_DIR="/etc/systemd/system"
SOURCE_SERVICE="${SERVICE_DIR}/ark-island.service"
NEW_MAP_KEY="Genesis"
NEW_MAP_ID="Genesis_WP"
NEW_SERVICE="${SERVICE_DIR}/ark-${NEW_MAP_KEY}.service"

echo "==========================================="
echo " ARK Genesis Service Creator"
echo "==========================================="

#############################################
# ソースサービスの存在確認
#############################################

if [ ! -f "$SOURCE_SERVICE" ]; then
  echo "[ERROR] $SOURCE_SERVICE が見つかりません。"
  echo "  ark-island.service が正しく配置されているか確認してください。"
  exit 1
fi

echo ""
echo "ベースサービス: $SOURCE_SERVICE"

#############################################
# 既存の ExecStart 行を解析
#############################################

SOURCE_LINE=$(grep "^ExecStart=" "$SOURCE_SERVICE")

# Proton run ArkAscendedServer.exe までのプレフィックスを抽出
EXEC_PREFIX=$(echo "$SOURCE_LINE" | sed -E 's/^ExecStart=([^ ]+ run ArkAscendedServer\.exe).*/\1/')

# 各パラメータを抽出
CURRENT_SESSION=$(echo "$SOURCE_LINE" | sed -E 's/.*SessionName=([^?]+).*/\1/')
CURRENT_PASS=$(echo "$SOURCE_LINE"   | grep -oP 'ServerPassword=\K[^ ]+' || echo "")
CURRENT_PLATFORM=$(echo "$SOURCE_LINE" | grep -oP 'ServerPlatform=\K[^ ]+' || echo "PC")
CURRENT_MODS=$(echo "$SOURCE_LINE"   | grep -oP 'mods=\K[^ ]+'           || echo "")

# Platform が空なら PC に強制
[ -z "$CURRENT_PLATFORM" ] && CURRENT_PLATFORM="PC"

echo ""
echo "-------------------------------------------"
echo "island.service から読み取った設定:"
echo "  セッション名 : $CURRENT_SESSION"
echo "  パスワード   : $CURRENT_PASS"
echo "  プラットフォーム: $CURRENT_PLATFORM"
echo "  MODs         : ${CURRENT_MODS:-なし}"
echo "  新マップID   : $NEW_MAP_ID"
echo "-------------------------------------------"

#############################################
# 上書き確認
#############################################

if [ -f "$NEW_SERVICE" ]; then
  echo ""
  echo "[WARNING] $NEW_SERVICE はすでに存在します。"
  read -p "上書きしますか？ (y/n): " OVERWRITE
  [ "$OVERWRITE" != "y" ] && echo "中断しました。" && exit 0
fi

#############################################
# 新 ExecStart を組み立て
#############################################

BASE_FLAGS="-ServerPlatform=${CURRENT_PLATFORM}"
[ -n "$CURRENT_MODS" ] && BASE_FLAGS="$BASE_FLAGS -mods=${CURRENT_MODS}"

NEW_EXEC="ExecStart=${EXEC_PREFIX} ${NEW_MAP_ID}?listen?SessionName=${CURRENT_SESSION}?ServerPassword=${CURRENT_PASS} ${BASE_FLAGS}"

#############################################
# island.service をコピーして Genesis 用に書き換え
#############################################

cp "$SOURCE_SERVICE" "$NEW_SERVICE"

# ExecStart 行を新しいものに差し替え
sed -i "s|^ExecStart=.*|${NEW_EXEC}|g" "$NEW_SERVICE"

# Description があれば Genesis 用に書き換え
sed -i "s|^Description=.*|Description=ARK Ascended - Genesis Server|g" "$NEW_SERVICE"

echo ""
echo "サービスファイルを作成しました: $NEW_SERVICE"

#############################################
# systemd に反映
#############################################

systemctl daemon-reload

echo ""
echo "==========================================="
echo " 完了！"
echo "==========================================="
echo ""
echo "サーバーを起動するには:"
echo "  1) 起動済みのサービスを停止する（例）"
echo "     sudo systemctl stop ark-island.service"
echo "  2) Genesis サーバーを起動する"
echo "     sudo systemctl start ark-${NEW_MAP_KEY}.service"
echo ""
echo "起動ログの確認:"
echo "  tail -F /home/steam/island-ShooterGame.log"
