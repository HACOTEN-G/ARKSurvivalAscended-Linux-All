#!/bin/bash

#############################################
# ARK サーバー 自動再起動 cron 設定スクリプト
#############################################

if [ "$EUID" -ne 0 ]; then
  echo "rootで実行してください。"
  echo "例: sudo ./setup-cron-reboot.sh"
  exit 1
fi

echo "==========================================="
echo " ARK サーバー 自動再起動設定"
echo "==========================================="
echo ""

read -p "再起動する時刻（0-23時）を入力してください: " REBOOT_HOUR

if ! [[ "$REBOOT_HOUR" =~ ^([0-9]|1[0-9]|2[0-3])$ ]]; then
  echo "時刻の入力が不正です。0〜23の数字で入力してください。"
  exit 1
fi

echo ""
echo "再起動の頻度を選択してください:"
echo "1) 毎日"
echo "2) 毎週"
read -p "番号を入力 (1 or 2): " SCHEDULE_TYPE

if [ "$SCHEDULE_TYPE" == "1" ]; then
  CRON_ENTRY="0 $REBOOT_HOUR * * * /usr/sbin/shutdown -r now"
  DESCRIPTION="毎日 ${REBOOT_HOUR}:00 に再起動"
elif [ "$SCHEDULE_TYPE" == "2" ]; then
  echo ""
  echo "曜日を選択してください:"
  echo "0=日 1=月 2=火 3=水 4=木 5=金 6=土"
  read -p "曜日番号 (0-6): " WEEKDAY

  if ! [[ "$WEEKDAY" =~ ^[0-6]$ ]]; then
    echo "曜日の入力が不正です。"
    exit 1
  fi

  WEEKNAME=("日" "月" "火" "水" "木" "金" "土")
  CRON_ENTRY="0 $REBOOT_HOUR * * $WEEKDAY /usr/sbin/shutdown -r now"
  DESCRIPTION="毎週 ${WEEKNAME[$WEEKDAY]}曜日 ${REBOOT_HOUR}:00 に再起動"
else
  echo "選択が不正です。"
  exit 1
fi

echo ""
echo "-------------------------------------------"
echo "以下の内容で設定します:"
echo "  $DESCRIPTION"
echo "-------------------------------------------"
read -p "この内容で設定しますか？ (y/n): " CONFIRM

if [ "$CONFIRM" != "y" ]; then
  echo "キャンセルしました。"
  exit 0
fi

# 既存shutdown設定削除
crontab -l 2>/dev/null | grep -v "/usr/sbin/shutdown -r now" > /tmp/cron_backup

echo "$CRON_ENTRY" >> /tmp/cron_backup
crontab /tmp/cron_backup
rm /tmp/cron_backup

echo ""
echo "==========================================="
echo " 設定が完了しました"
echo "==========================================="
echo ""
echo "現在のcrontab設定:"
echo "-------------------------------------------"
crontab -l
echo "-------------------------------------------"
