# DSVM(AAD認証) の分析環境を構成する terraform

## 概要

Azure に

* DSVM-Ubuntuベース
* AzureAAD認証構成済
* JupyterLabに変更済
* IPA日本語フォントインストール済
* 指定IPアドレスからのSSH(22)/HTTPS(8443)のみ許可
* 毎日19:30シャットダウン(注・なぜか効かない)

な仮想マシンを作成します。

## 事前準備

* terraform を入れる
* [ここ](https://docs.microsoft.com/ja-jp/azure/virtual-machines/linux/terraform-install-configure) を参考にAzureに接続する為の変数を取得しておく
* SSH鍵ペアを作成しておく

## 使用方法

### 変数設定

[お好きな方法](https://learn.hashicorp.com/terraform/getting-started/variables.html#assigning-variables) で変数を設定する。

|変数名|デフォルト値|説明|
|:--|:--|:--|
|prefix|dsvm|全リソースのプレフィクス|
|azure_subscription_id||サブスクリプションID|
|azure_client_id||クライアントID|
|azure_client_secret||クライアントシークレット|
|azure_tenant_id||テナントID|
|location|japaneast|作成先リージョン|
|vm_size|Standard_DS1_v2|VMのサイズ|
|pubkey_path|~/.ssh/id_rsa.pub|公開鍵のパス|
|privkey_path|~/.ssh/id_rsa|秘密鍵のパス|
|access_source_address|*|アクセス許可元アドレス|
|dsvm_version|19.08.23|DSVM Imageのバージョン|
|shutdown_time|1930|毎日の自動シャットダウン時刻|

* azure_subscription_id ~ azure_tenant_id


### 実行

```
$ terraform apply
...


Apply complete! Resources: 16 added, 0 changed, 0 destroyed.

Outputs:

dsvm-host = aridsvm-dsvm.japaneast.cloudapp.azure.com
dsvm-url = https://aridsvm-dsvm.japaneast.cloudapp.azure.com:8443/

# AAD認証でSSHログイン
$ ssh xxxx@xxxx.onmicrosoft.com@aridsvm-dsvm.japaneast.cloudapp.azure.com
This preview capability is not for production use. When you sign in, verify the name of the app on the sign-in screen is "Azure Linux VM Sign-in" and the IP address of the target VM is correct.

To sign in, use a web browser to open the page https://microsoft.com/devicelogin and enter the code GB7U3WL22 to authenticate. Press ENTER when ready.


# ブラウザでJupyterHubに接続(AAD認証)
# (注) 先にSSHで一度ログインしておく必要があります
$ xdg-open https://aridsvm-dsvm.japaneast.cloudapp.azure.com:8443/
```
