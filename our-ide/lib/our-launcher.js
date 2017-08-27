const Cp=require('child-process');
const Fs=require('fs');
module.exports=class ourLauncher {
/**
 * コンストラクタ
 * @param  {String} user ユーザーID
 * @param  {String} home ホームパス
 * @return {Object}      Configオブジェクト
 * @constructor
 */
  constructor(user, home) {
    this.User=user; this.Home=home;
    this.Config=this.getJson(home+'/.atom/our-ide.json');
    return this.Config;
  }
/**
 * localexec
 * ローカル実行編集
 * @param  {String} module 編集中モジュールのパス
 * @return {String}        実行コマンド
 * @method
 */
  localexec(module) {
    let me=this, pa=module, a, i, x;
    let part=pa.split('/');
    let spec=me.Config;
//    let path=me.userPath(part);
    let file=me.filepart(pa);

    for(i in spec.path) {
      x=spec.path[i];
      a=x.filter.split('/');
      for(i in a){if(a[i]!='*' && a[i]!=part[i]) {
        return me.expand(x.command);
      }}
    }

    for(i in spec.modifier) {
      x=spec.modifier[i];
      if(me.modifier(file)==x.filter) {return me.expand(x.command);}
    }

    if(me.modifiler(file)=='tsh'){return me.templauncher(pa);}
  }
/**
 * templauncher
 * テンポラリーコマンドファイル(*.tsh)からの実行
 * @param  {String} path ファイルのパス
 * @param  {Object} pos  カーソル位置{row, col}
 * @return {String}      OKかエラーメッセージ
 * @method
 */
  templauncher(path, pos) {
    let me=this, out='', c='', i, x, y;
    let a=this.loadFile(path);
    let f=false;
    for(i in a) {
      x=a[i], y=me.spacedelimit(x);
      if(i==pos.row+1){
        if(y[0]=='do'){f=true;}
        else{return '指定した行がdoではありません';}
      }else{
        if(y[0]=='end'){f=false; out+=c+'read -p "確認" x'; break;}
        if(f){out+=c+x; c=' && ';}
      }
    }
    me.error='';
    try{
      if(f){return 'endマークがありません';}
      else{Cp.commands(out);}
      return true;
    }catch(e){
      me.error=e; return false;
    }
  }
/**
 * userenv
 * ユーザー環境変数の設定
 * @return {Boolean} true/false OK/NG
 * @method
 */
  userenv() {
    let me=this, dt, ba, bt={}, f, t, x, a, rc;
    me.error='';
    try{
      let user=process.env.USER;
      let home=process.env.HOME;
      dt=Cp.execSync('./xaProcom automation userenv '+user);
      dt=JSON.parse(dt);
      ba=Fs.readFileSync(home+'/.userenv');
      ba=JSON.parse(ba);
      f=0;
      while(f<ba.length) {
        t=ba.indexOf('\n', f); if(t<0){t=ba.length;}
        x=ba.substring(f, t); a=x.split('=');
        if(a[0]){bt[a[0]]=a[1];}
        f=t+1;
      }
      let out='', i;
      for(i in dt) {out+=i+'='+dt[i]+'\n';}
      for(i in ba) {if(!dt[i]) {out+=i+'='+ba[i]+'\n';}}
      Fs.writeFileSync(home+'/.userenv', out);
      Cp.execSync('source xsSetenv .userenv');
      rc=true;
    }catch(e) {
      me.error=e; rc=false;
    }
    return rc;
  }
/**
 * autoexec
 * 自動実行の実施
 * @return {Boolean} true/false OK/NG
 * @method
 */
  autoexec() {
    let me=this, dt, x, out='';
    let user=process.env.USER;
    let home=process.env.HOME;
    me.error='';
    try{
      dt=Cp.execSync('./xaProcom automation xsAuto '+user);
      dt=JSON.parse(dt);
      for(x in dt){out+=x+'\n';}
      Fs.writeFileSync(home+'/bin/xsAuto', out);
      Cp.execSync('chmod +x '+home+'/bin/xsAuto');
      Cp.exec('xsAuto');
      return true;
    }catch(e) {
      me.error=e; return false;
    }
  }
/**
 * lastOf
 * テキストを後ろから調べ、指定された文字が発見された位置を返す
 * @param  {String} txt 対象のテキスト
 * @param  {String} x   検索文字
 * @return {Integer}    位置
 * @method
 */
  lastOf(txt, x) {
    let i=txt.length-1;
    while(i > -1) {
      if(txt[i]==x){return i;}
      i--;
    }
    return -1;
  }
/**
 * pullDir
 * テキストからディレクトリ部分を抽出する
 * @param  {String} txt 対象テキスト
 * @return {String}     ディレクトリ部分
 * @method
 */
  pullDir(txt) {
    let i=this.lastOf(txt, '/');
    return txt.substr(0, i+1);
  }
/**
 * repby
 * 対象テキストの文字を置換する
 * @param  {String} txt 対象テキスト
 * @param  {String} x   被置換対象テキスト
 * @param  {String} y   置換テキスト
 * @return {String}     置換結果
 * @method
 */
  repby(txt, x, y) {
    let out='', i;
    for(i in txt){if(txt[i]==x){out+=y;}else{out+=txt[i];}}
    return out;
  }
  /**
   * separate
   * 分離符で二分する
   * @param  {String} txt 対象テキスト
   * @param  {String} x   分離符
   * @return {Array}      分離結果[左辺, 右辺]
   * @method
   */
  separate(txt, x) {
    let out=['', ''], i;
    let f=true;
    for(i in txt) {
      if(f && txt[i]==x) {f=false;}
      else{if(f){out[0]+=txt[i];}else{out[1]+=txt[i];}}
    }
    return out;
  }
/**
 * modifier
 * 修飾子を取り出す
 * @param  {String} x 対象テキスト
 * @return {String}   修飾子
 * @method
 */
  modifier(x) {
    let p=this.lastOf(x, '.');
    if(p<0){return '';}
    p++; return x.substr(p);
  }
/**
 * filepart
 * パスからファイル部分を取り出す
 * @param  {String} x パステキスト
 * @return {String}   ファイル部分
 * @method
 */
  filepart(x) {
    let p=this.lastOf(x, '/');
    if(p < 0) {return x;}
    p++; return x.substr(p);
  }
/**
 * pathpart
 * パスからフォルダ部分を取り出す
 * @param  {String} x パステキスト
 * @return {String}   フォルダ部分
 * @method
 */
  pathpart(x) {
    let p=this.lastOf(x, '/');
    if(p<0){return '';}
    return x.substr(0, p+1);
  }
/**
 * getJson
 * JSONファイルをオブジェクトに変換
 * @param  {String} fn ファイルパス
 * @return {Object}    JSONオブジェクト
 * @method
 */
  getJson(fn) {
    let rc;
    this.error='';
    try{
      rc=this.getFs(fn);
      if(rc){return JSON.parse(rc);}
      else{return false;}
    }catch(e) {
      this.error=e;
      return false;
    }
  }
/**
 * getFs
 * ファイルを読み込みテキストとして取り出す
 * @param  {String} fn ファイルパス
 * @return {String}    ファイル内容
 * @method
 */
  getFs(fn) {
    this.error='';
    if(this.isExist(fn)){
      return Fs.readFileSync(fn).toString();
    }else{
      this.error='file not found file='+fn;
      return false;
    }
  }
/**
 * isExist
 * ファイル存在チェック
 * @param  {String} fn ファイルパス
 * @return {Boolean}   true/false あり/なし
 * @method
 */
  isExist(fn) {
    this.error='';
    try{
      return Fs.existsSync(fn);
    }catch(e) {
      this.error=e;
      return false;
    }
  }
/**
 * userPath
 * ホームホルダ以降を取り出す
 * @param  {String} a パス文字列
 * @return {String}   結果パス
 * @method
 */
  userPath(a) {
    let rc='', i;
    for(i in a) {if(i > 2){rc+='/'+a[i];}}
    return rc;
  }
/**
 * loadFile
 * ファイルを配列として取り出す
 * @param  {String} path 対象ファイルのパス
 * @return {Array}       結果配列
 * @method
 */
  loadFile(path) {
    let d, t, e, x, f=0, out=[];
    this.error='';
    try{
      d=Fs.readFileSync(path);
      while(f<d.length-1){
        t=x.indexOf('\n', f);
        if(t<0){t=x.length-1;}
        e=x.substring(f, t);
        out.push(e);
        f=t+1;
      }
    }catch(e) {
      this.error=e; out=[];
    }
    return out;
  }
}
