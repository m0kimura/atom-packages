const Cp=require('child_process');
const Fs=require('fs');
module.exports=class ourLauncher {
/**
 * コンストラクタ
 * @param  {String} user ユーザーID
 * @param  {String} home ホームパス
 * @return {Void}        none
 * @constructor
 */
  constructor(user, home) {
    /**
     * ユーザーID
     * @type {String}
     */
    this.User=user;
    /**
   * ホームパス
   * @type {String}
   */
    this.Home=home;
    /**
   * 設定情報
   * @type {Object}
   */
    this.Config=this.getJson(home+'/.atom/our-ide.json');
    /**
   * エラー情報
   * @type {String}
   */
    this.error='';
  }
  /**
 * 設定情報の取得
 * @return {Object} 設定情報
 * @method
 */
  getMenus() {
    return this.Config;
  }
  /**
 * localexec
 * ローカル実行編集
 * @param  {String} module 編集中モジュールのパス
 * @return {String}        実行コマンド
 * @method
 */
  localexec(fpath) {
    let me=this, pa=fpath, a, i, x, dt, f, p;
    let part=pa.split('/');
    let spec=me.Config;
    let file=me.filepart(pa);
    f='';
    if(part[3]==spec.websource){
      console.log(part);
      if(me.modifier(file)=='page'){
        p=''; for(i=4; i<part.length-1; i++){p+='/'+part[i];}
        return {'mode': 'atom', 'cmd': 'http://localhost'+p+'/'+me.upper(file)+'.html'};
      }
    }
    for(i in spec.path) {
      x=spec.path[i];
      a=x.filter.split('/'); dt={};
      f=x.command;
      for(i in a){if(a[i]!='*' && a[i]!=part[i]) {f=''; break;}}
      if(f){
        for(i in part){dt['part'+i]=part[i];}
        console.log('#68', me.modifier(file), x.filter, dt);
        return {'mode': 'cmd', 'cmd': me.expand(x.command, dt)};
      }
    }
    for(i in spec.modifier) {
      x=spec.modifier[i];
      if(me.modifier(file)==x.filter) {
        dt={'file': file, 'path': me.pathpart(pa), 'fullpath': pa};
        console.log('#64', me.modifier(file), x.filter);
        return {'mode': 'cmd', 'cmd': me.expand(x.command, dt)};
      }
    }
    return {'mode': '', 'cmd': ''};
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
    let cmd='';
    for(i in a) {
      x=a[i], y=me.spacedelimit(x); if(!y){y[0]='';}
      console.log(i, pos.row, y[0]);
      if(i==pos.row){
        switch(y[0]){
        case 'atom': return {'mode': 'atom', 'cmd': y[1]};
        case 'do': f=true; cmd=y[0]; break;
        case 'terminal': f=true; cmd=y[0]; break;
        default: me.error='指定した行がdo,terminalではありません'; return {'mode': 'NG', 'cmd': ''};
        }
      }else{
        if(f && y[0]=='end'){f=false; break;}
        if(f){out+=c+x; c=' && ';}
      }
    }
    if(f){me.error='endマークがありません'; return {'mode': 'NG', 'cmd': ''};}
    if(!out){me.error='コマンドがありません'; return {'mode': 'NG', 'cmd': ''};}
    if(cmd=='do') {return {'mode': 'cmd', 'cmd': out};}
    if(cmd=='terminal') {return {'mode': 'cmd', 'cmd': 'gnome-terminal -e "sh -c \'' + out + '\'"'};}
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
      let user=me.User;
      let home=me.Home;
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
    let user=me.User;
    let home=me.Home;
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
 * 状況依存メニューの編集
 * @param  {String} path ファイルのパス
 * @return {Array}       メニューオブジェクトの配列
 * @method
 */
  solveDepend(path) {
    let i, j, f, x, a, out=[];
    let part=path.split('/');
    for(i in this.Config.menu) {
      x=this.Config.menu[i];
      f='';
      if(x.path){
        a=x.path.split('/');
        f=x.menu;
        for(j in a){if(a[j]!='*' && a[j]!=part[j]){f=''; break;}}
        if(f){break;}
      }
      if(f=='' && x.modifier){
        if(x.modifier==this.pathpart(path)){f=x.menu; break;}
      }
    }
    if(f){for(i in this.Config[f]) {out.push(this.Config[f][i]);}}
    for(i in this.Config.main) {out.push(this.Config.main[i]);}
    return out;
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
  upper(x) {
    let t=this.lastOf(x, '.'); if(t<0){t=x.length-1;}
    let f=this.lastOf(x, '/'); if(f<0){f=0;}else{f=f+1;}
    return x.substr(f, t);
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
    let d, t, e, f=0, out=[];
    this.error='';
    try{
      d=Fs.readFileSync(path); d=d.toString('utf8');
      while(f<d.length-1){
        t=d.indexOf('\n', f);
        if(t<0){t=d.length-1;}
        e=d.substring(f, t);
        out.push(e);
        f=t+1;
      }
    }catch(e) {
      this.error=e; out=[];
    }
    return out;
  }
  /**
 * パラメータを展開
 * @param  {String} ln パラメタを含む文字列
 * @param  {String} dt パラメタデータ
 * @return {String}    展開後データ
 * @method
 */
  expand(ln, dt) {
    let i, c, sw=0, out='', cc, key='';
    if(!ln){return '';}
    for(i=0; i<ln.length; i++){
      c=ln.substr(i, 1); cc=ln.substr(i, 2);
      switch(sw){
      case 0:
        switch(cc){
        case '%{': sw=1; i++; key=''; break;
        default: if(cc>'%0' && cc<'%9'){sw=9;}else{out+=c;} break;
        } break;
      case 1:
        if(c=='}'){
          if(dt[key]!==undefined){out+=dt[key];}
          sw=0;
        }else{
          key+=c;
        } break;
      }
    }
    return out;
  }
  /**
 * スペースによる分解
 * @param  {String} x 対象文字列
 * @return {Array}    分解後要素配列
 * @method
 */
  spacedelimit(x) {
    let i, out=[], e='';
    for(i=0; i<x.length; i++){
      if(x[i]!=' '){e+=x[i];}
      else{if(e){out.push(e); e='';}}
    }
    if(e){out.push(e);}
    return out;
  }
}
