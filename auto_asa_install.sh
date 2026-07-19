#!/bin/bash

set -e

echo "=== ARKSurvivalAscended-Linux-All をダウンロードします ==="

git clone https://github.com/HACOTEN-G/ARKSurvivalAscended-Linux-All.git

cd ARKSurvivalAscended-Linux-All

echo "=== server-install-ubuntu20.sh を実行します ==="

bash server-install-ubuntu20.sh

echo "=== インストールが完了しました ==="
