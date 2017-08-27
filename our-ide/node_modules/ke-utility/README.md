#ke-utility

NODEJS 基本ルール

##これは何

様々な基本となる機能を提供する nodejs です。　Kmrweb Dot Net http://www.kmrweb.net/server/ をご覧下さい。

##動作環境

* ubuntu 14.04
* Node.js v0.10.26

##使い方

_MAIN_ メインルーチンはこの中に記述します。  
  `uty.MAIN(function(){`  
  `  ...`  
  `  ...`  
   `});`  
  
_argv(n)_ n個目の引数を取り出します。

##環境変数
  RUNCONFIG configファイルのパスを指定しておきます。(例 /home/kimura/ha-project.config)
  RUNMODE   [master]本番,[test]結合テストなど、指定されていないときはdebugモードとなります。
「.bashrc」にexportで指定しておく。

実行パラメータの設定
  dbdriver    使用DB [postgre]
  admin       管理者ID
  psw         パスワード
  service     通知サービス[gmail]
  level       メッセージレベル[warn]
  log         ログファイルパス[*.log]
  path        実行フルパス
  pid         プロセスID
  current     実行フォルダ
  apli        実行ファイル名
  groupid     グループ番号
  uid         ユーザー番号
  platform    OS
  user        ユーザーID
  home        ホームパス
  config      実行パラメータフルパス
  groupid     実行グループ
  dictionary  辞書ファイルフルパス
  
  その他共通パラメータを定義しておきます。

  group       groupid
  valid       有効期間(15/01/01:15/02/28)

##関数

  localconf   ローカル実行環境ファイルを読み込みます。[JSON形式]
              ({
                fn:     ファイルフルパス[*.log],
                infoj:  true INFOJに設定する,[RETURNで返します],
                stop:   true(重大エラー処理を実行します)/[false](errorをセットして空を返す)
              })
              RETURN 

  dict        辞書変換をします。
              (
                対象キー,
                国コード
              )
              RETURN 変換後ワード

  argv        起動引数の取り出し
              (
                起動引数の位置1,...
              )

  develop     テンプレートの展開
              (
                テンプレートファイルパス,
                [データ域]（me.REC）,
                [インデックス値](0)
              )

  parm        パラメータを展開する
              #{} INFOJから展開
              %{} RECから展開
              ${} SCREENから展開
              &{} CFGから展開
              (
                展開対象領域,
                [％パラメータソース省略時はREC],
                [インデックス値0]
              )

  parse       URL?querystringをパースします。
              (
                query文字列
              )
              RETURN キーワード配列

  stringify   URK?querystringを作ります
              (
                キーワード配列
              )
              RETURN query文字列

  unstring    文字列をスペースデリミタで分解
              (
                文字列
              )
              RETURN 配列

　lastOf      文字列中の指定文字の最終出現位置
              (
                対象文字列,
                指定文字
              )
              RETURN 最終出現位置（ないときは-1）

  pullDir     フルパスからディレクトリ部分を取り出す
              (
                フルパス
              )
              RETURN ディレクトリ部分

  repby       対象文字列中の指定文字列を置き換え文字列に置き換える
              (
                対象文字列,
                指定文字列,
                置き換え文字列
              )
              RETURN 結果文字列

  separate    対象文字列を指定文字で、前後２つに分離する
              (
                対象文字列,
                指定文字
              )
              RETURN 結果配列[前, 後]

  modifier    ファイル名から接尾拡張子を取り出す
              (
                ファイル名
              )
              RETURN 接尾拡張子

  filepart    ファイル名から本体部分を取り出す
              (
                ファイル名
              )
              RETURN ファイル本体部分

  pathpart    ファイルフルパスからパス部分を取り出す
              (
                ファイル名
              )
              RETURN パス部分

  date        日付編集YyMmDdHhIiSsWw
              Y:年４桁,y:年２桁,M:月２桁,m:月,D:日２桁,d:日,H:時2桁,h:時,I:分２桁,i:分,S:秒２桁,s:秒
              W:曜日（漢字）,w:曜日(英)
              (
                編集文字列,
                対象時間[現在時間]
              )
  
  today       今日の日付をY/M/Dで返す
              ()

  now         今の時間をH/I/Sで返す
              ()

  isExist     ファイルの存在確認
              (
                ファイルフルパス
              )
              RETURN true/false

  dir         ディレクトリリスト
              (
                対象パス,
                ['file'/'dir']省略時は混合
              )
              RETURN 配列

  stat        ファイルの属性情報を返す
              (
                ファイルフルパス
              )
              RETURN キーワード配列/false

  getCsv      ｃｓｖファイルを読み込み、RECインターフェイスに編集
              (
                ファイルフルパス
              )
              RETURN レコード件数/false

  getObject   JSON形式ファイル読み込み、RECインターフェイスに編集
              (
                ファイルフルパス
              )
              RETURN レコード件数/false

  getIp       自分のIpアドレスを返します
              ()
              RETURN IPアドレス

  shell       シェルコマンドを実行します。(完了を待ち合わせます)
              (
                シェルコマンド
              )
              RETURN true/false

  
