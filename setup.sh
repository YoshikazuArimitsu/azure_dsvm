#!/bin/bash
. ~/.terraform_env

# タイムゾーン変更
sudo timedatectl set-timezone Asia/Tokyo

# IPAフォントインストール
sudo apt install -y fonts-ipaexfont

# Jupyterlabに対応させるExtensionの追加
BIN_PATH='/data/anaconda/envs/py35/bin'
sudo ${BIN_PATH}/jupyter labextension install @jupyterlab/hub-extension

# JupyterHub AAD認証に必要なパッケージの追加
sudo ${BIN_PATH}/pip install oauthenticator PyJWT

# nameではなくunique_nameを使うようにパッチ
# https://github.com/jupyterhub/oauthenticator/pull/224
sudo sed -e "104s:'name':'unique_name':" -i /data/anaconda/envs/py35/lib/python3.5/site-packages/oauthenticator/azuread.py

# JupyterHubの設定を書き換え
# ポート変更/JupyterLab使用/追加したADAppと接続
sudo -E sh -c 'cat <<EOF >> /etc/jupyterhub/jupyterhub_config.py
c.Spawner.default_url = "/lab"
c.JupyterHub.port = 8443

import os
import requests

os.environ["AAD_TENANT_ID"] = "${AAD_TENANT_ID}"

from oauthenticator.azuread import AzureAdOAuthenticator

c.JupyterHub.authenticator_class = AzureAdOAuthenticator
c.Application.log_level = "DEBUG"
c.AzureAdOAuthenticator.tenant_id = os.environ.get("AAD_TENANT_ID")
c.AzureAdOAuthenticator.oauth_callback_url = "https://${VM_FQDN}:8443/hub/oauth_callback"
c.AzureAdOAuthenticator.client_id = "${OAUTHAPP_APPLICATION_ID}"
c.AzureAdOAuthenticator.client_secret = "${OAUTHAPP_CLIENT_SECRET}"
EOF
'

# 再起動
sudo service jupyterhub restart

# ゴミ・鍵を消去(もう鍵認証で入ってこれないようにする)
rm -f ~/.terraform_env
rm -f ~/.ssh/authorized_keys

