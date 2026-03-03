#!/bin/bash

#############################################
# ARK サービス一括オプション変更＋アップデート
#############################################

if [ "$EUID" -ne 0 ]; then
  echo "rootで実行してください（sudo ./update-ark-services.sh）"
  exit 1
fi

SERVICE_DIR="/etc/systemd/system"
APP_ID=2430930

declare -A MAPS=(
  ["ScorchedEarth"]="ScorchedEarth_WP"
  ["Center"]="Center_WP"
  ["Aberration"]="Aberration_WP"
  ["Extinction"]="Extinction_WP"
  ["Astraeos"]="Astraeos_WP"
  ["Ragnarok"]="Ragnarok_WP"
  ["Valguero"]="Valguero_WP"
  ["LostColony"]="LostColony_WP"
)

echo "==========================================="
echo " ARK サービス設定変更ツール"
echo "==========================================="

#############################################
# ① 対象選択
#############################################

echo ""
echo "① 変更対象を選択してください"
echo "1) 全MAP"
echo "2) 単一MAP"
read -p "番号を入力: " TARGET_TYPE

TARGET_SERVICES=()

if [ "$TARGET_TYPE" == "1" ]; then
  for MAP in "${!MAPS[@]}"; do
    TARGET_SERVICES+=("ark-${MAP}.service")
  done
elif [ "$TARGET_TYPE" == "2" ]; then
  echo ""
  MAP_KEYS=("${!MAPS[@]}")
  i=1
  for MAP in "${MAP_KEYS[@]}"; do
    echo "$i) $MAP"
    ((i++))
  done
  read -p "番号を選択: " MAP_INDEX
  SELECTED_MAP="${MAP_KEYS[$((MAP_INDEX-1))]}"
  TARGET_SERVICES+=("ark-${SELECTED_MAP}.service")
else
  echo "入力エラー"
  exit 1
fi

#############################################
# サービス停止
#############################################

echo ""
echo "対象サービスを停止します..."
for SVC in "${TARGET_SERVICES[@]}"; do
  systemctl stop "$SVC" 2>/dev/null
done

#############################################
# 現在のExecStart取得（最初の1つから取得）
#############################################

FIRST_SERVICE="${SERVICE_DIR}/${TARGET_SERVICES[0]}"
CURRENT_LINE=$(grep "^ExecStart=" "$FIRST_SERVICE")

CURRENT_MAP=$(echo "$CURRENT_LINE" | sed -E 's/.*ArkAscendedServer.exe ([^?]+).*/\1/')
CURRENT_SESSION=$(echo "$CURRENT_LINE" | sed -E 's/.*SessionName=([^?]+).*/\1/')
CURRENT_PASS=$(echo "$CURRENT_LINE" | sed -E 's/.*ServerPassword=([^ ]+).*/\1/')
CURRENT_PLATFORM=$(echo "$CURRENT_LINE" | grep -o "ServerPlatform=[^ ]*" | cut -d= -f2)
CURRENT_MODS=$(echo "$CURRENT_LINE" | grep -o "mods=[^ ]*" | cut -d= -f2)

#############################################
# ② サーバー名
#############################################

SESSION_NAME="$CURRENT_SESSION"
read -p "② サーバー名を変更しますか？ (現在: $CURRENT_SESSION) (y/n): " CHANGE
if [ "$CHANGE" == "y" ]; then
  read -p "新しいサーバー名: " SESSION_NAME
fi

#############################################
# ③ パスワード
#############################################

SERVER_PASS="$CURRENT_PASS"
read -p "③ パスワードを変更しますか？ (現在: $CURRENT_PASS) (y/n): " CHANGE
if [ "$CHANGE" == "y" ]; then
  read -p "新しいパスワード: " SERVER_PASS
fi

#############################################
# ④ プラットフォーム
#############################################

PLATFORM="$CURRENT_PLATFORM"
read -p "④ プラットフォームを変更しますか？ (現在: $CURRENT_PLATFORM) (y/n): " CHANGE
if [ "$CHANGE" == "y" ]; then
  echo "1) PC  2) XSX  3) PS5"
  read -p "番号を入力: " PLATFORM_TYPE
  case $PLATFORM_TYPE in
    1) PLATFORM="PC" ;;
    2) PLATFORM="XSX" ;;
    3) PLATFORM="PS5" ;;
    *) echo "入力エラー"; exit 1 ;;
  esac
fi

#############################################
# ⑤ MOD
#############################################

MOD_IDS="$CURRENT_MODS"
read -p "⑤ MODを変更しますか？ (現在: ${CURRENT_MODS:-なし}) (y/n): " CHANGE
if [ "$CHANGE" == "y" ]; then
  read -p "MOD ID（カンマ区切り・空で無し）: " MOD_IDS
fi

#############################################
# 最終確認
#############################################

echo ""
echo "-------------------------------------------"
echo "最終設定:"
echo " サーバー名: $SESSION_NAME"
echo " パスワード: $SERVER_PASS"
echo " プラットフォーム: $PLATFORM"
echo " MOD: ${MOD_IDS:-なし}"
echo "-------------------------------------------"
read -p "この内容で更新しますか？ (y/n): " CONFIRM
[ "$CONFIRM" != "y" ] && exit 0

#############################################
# ExecStart更新
#############################################

BASE_FLAGS="-NoBattlEye -lowmemory -nomemorybias -ServerPlatform=${PLATFORM}"
[ -n "$MOD_IDS" ] && BASE_FLAGS="$BASE_FLAGS -mods=${MOD_IDS}"

for SVC in "${TARGET_SERVICES[@]}"; do

  SERVICE_FILE="${SERVICE_DIR}/${SVC}"
  [ ! -f "$SERVICE_FILE" ] && continue

  MAP_NAME=$(grep "ArkAscendedServer.exe" "$SERVICE_FILE" | sed -E 's/.*ArkAscendedServer.exe ([^?]+).*/\1/')

  NEW_EXEC="ExecStart=/home/steam/.steam/compatibilitytools.d/GE-Proton8-21/proton run ArkAscendedServer.exe ${MAP_NAME}?listen?SessionName=${SESSION_NAME}?ServerPassword=${SERVER_PASS} ${BASE_FLAGS}"

  sed -i "s|^ExecStart=.*|${NEW_EXEC}|g" "$SERVICE_FILE"

  echo "更新完了: $SVC"

done

systemctl daemon-reload

#############################################
# サーバーアップデート実行
#############################################

echo ""
echo "サーバーアップデートを実行します..."
sudo -u steam /usr/games/steamcmd +login anonymous +app_update ${APP_ID} validate +quit

echo ""
echo "==========================================="
echo " 設定変更とアップデートが完了しました"
echo "==========================================="
echo ""
echo "起動する場合:"
echo " sudo systemctl start サービス名"
