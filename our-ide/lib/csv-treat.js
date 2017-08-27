const Cs=require('csv-parse/lib/sync');
const Cp=require('child_process');
const Fs=require('fs');
module.exports=class csvTreat {
/**
 * constructor
 * コンストラクター・初期設定
 * @return {Void} none
 * @constructor
 */
  constructor() {
    this.Week={
      'Mon': '月', 'Tue': '火', 'Wed': '水', 'Thu': '木',
      'Fri': '金', 'Sat': '土', 'Sun': '日'
    };
    this.Month=[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    this.Home=process.env.HOME;
    this.Line=0; this.Log=[];
  }
/**
 * hours
 * 勤怠データ作成。勤怠csvファイルを編集出力
 * @return {String} 作成ファイルパス
 * @method
 */
  hours() {
    let me=this;
    let i, a;
    let d=new Date();
    let month=d.getMonth();
    let save=me.Month[month];
    let fname=me.Home+'/hours_'+d.getFullYear()+'_'+save+'.csv';
    let table=me.getCsv(fname);
    if(!table){table=me.getFrame(d.getMonth());}
    let dt=me.getHours(save);
    for(i in table){
      me.Line=i+1; me.LineError='';
      table[i].エラー='';
      if(dt[i]){
        table[i].曜日 = me.Week[dt[i].week];
        if(!table[i].開始){table[i].開始=me.timeAdjust(dt[i].from, true);}
        if(!table[i].終了){table[i].終了=me.timeAdjust(dt[i].to);}
        table[i].始 = dt[i].from;
        table[i].終 = dt[i].to;
      }
      if(me.checkForm(table[i])){
        a=me.timeCalculate(table[i].開始, table[i].終了);
        if(a){
          table[i].時間 = a;
          table[i].休憩 = '1:00';
        }
      }
      if(table[i].曜日 && me.LineError){table[i].エラー=me.LineError;}
    }
    me.putCsv(fname, table);
    return fname;
  }
/**
 * checkForm
 * フォーマットチェック
 * @param  {Object} rec CSVファイルの１レコードのオブジェクト形式
 * @return {boolean}    true/false OK/NG
 * @method
 */
  checkForm(rec) {
    let me=this;
    if(rec.曜日){
      if(!rec.開始){
        me.LineError='開始時刻がありません。';
        me.Log.push({line: me.Line, message: me.LineError, pos: 'frm1'});
        return false;
      }
      if(!rec.終了){
        me.LineError='終了時刻がありません。';
        me.Log.push({line: me.Line, message: me.LineError, pos: 'frm1'});
        return false;
      }
    }else{
      me.LineError='';
    }
    return true;
  }
/**
 * timeAdjust
 * 時刻のまるめ(15分単位に)
 * @param  {String} x      「:」で分離された時刻
 * @param  {Boolean} after true:後合わせ、false:前合わせ
 * @return {Array}         [時, 分]
 * @method
 */
  timeAdjust(x, after) {
    let me=this;
    let t=me.timeCheck(x);
    if(after){
      if(t){
        if(t[1]=='00'){t[1]='00';}
        else if(t[1]<'15'){t[1]='15';}
        else if(t[1]<'30'){t[1]='30';}
        else if(t[1]<'45'){t[1]='45';}
        else{t[1]='00'; t[0]++;}
        return t[0]+':'+t[1];
      }
    }else{
      if(t){
        if(t[1]<'15'){t[1]='00';}
        else if(t[1]<'30'){t[1]='15';}
        else if(t[1]<'45'){t[1]='30';}
        else{t[1]='45';}
        return t[0]+':'+t[1];
      }
    }
    return x;
  }
/**
 * timeCheck
 * 時刻の一般的範囲とフォームのチェック
 * @param  {String} x 時:分
 * @return {Boolean}  true/false OK/NG
 * @method
 */
  timeCheck(x) {
    let me=this, out=[], err=false;
    if(x){out=x.split(':');}
    else{
      me.LineError='時刻がありません:'+x;
      me.Log.push({line: me.Line, message: me.LineError, pos: 'chk1'});
      return false;
    }
    if(out[0]<0 || out[0]>23){
      me.LineError='時刻が範囲外です:'+out[0];
      me.Log.push({line: me.Line, message: me.LineError, pos: 'chk2'});
      err=true;
    }
    if(out[1]<0 || out[1]>59){
      me.LineError='時刻が範囲外です:'+out[1];
      me.Log.push({line: me.Line, message: me.LineError, pos: 'chk3'});
      err=true;
    }
    if(err){return false;}
    if(out[0].length==1){out[0]='0'+out[0];}
    if(out[1].length==1){out[1]='0'+out[1];}
    return out;
  }
/**
 * timeCalculate
 * 時間計算（fromとtoの間の時間）
 * @param  {String} f 開始時刻(hh:mm)
 * @param  {String} t 終了時刻(hh:mm)
 * @return {Boolean}  true/false OK/NG
 * @method
 */
  timeCalculate(f, t) {
    let me=this, out={};
    if(f>t){
      me.LineError='時刻が矛盾しています。'+f+'と'+t;
      me.Log.push({line: me.Line, message: me.LineError, pos: 'cal1'});
      return false;
    }
    let fa=me.timeCheck(f);
    let ta=me.timeCheck(t);
    if(fa && ta){
      ta[0]=ta[0]-0; ta[1]=ta[1]-0;
      fa[0]=fa[0]-0; fa[1]=fa[1]-0;
      let m=ta[0]*60+ta[1]-fa[0]*60-fa[1];
      out.h=Math.floor(m/60);
      out.m=m-out.h*60;
      return out.h+':'+out.m;
    }
    return false;
  }
/**
 * timeSubtract
 * 時間計算(時間ー時間)
 * @param  {String} time 時間(hh:mm)
 * @param  {String} sub  時間(hh:mm)
 * @return {String}      結果(hh:mm)
 * @method
 */
  timeSubtract(time, sub) {
    let me=this, at, as, m, err=false, o, p;
    at=time.split(':');
    if(isNaN(at[0]) || isNaN(at[1])){
      err=true;
      me.LineError='時刻が不正です。:'+time;
      me.Log.push({line: me.Line, message: me.LineError, pos: 'sub1'});
    }
    as=sub.split(':');
    if(isNaN(as[0]) || isNaN(as[1])){
      err=true;
      me.LineError='時刻が不正です。:'+time;
      me.Log.push({'line': me.Line, 'message': me.LineError, pos: 'sub2'});
    }
    m=0;
    if(!err){
      m=at[0]*60+at[1]-as[0]*60-as[1]+1;
      o=Math.floor(m/60); p=m-(o*60);
      o='00'+o; p='00'+p;
      return o.substr(o.length-2, 2)+':'+p.substr(p.length-2, 2);
    }
    return false;
  }
/**
 * getHours
 * システム稼働時間ログから日付別の開始終了 オブジェクトを作成
 * @param  {Integer} month 月を指定します。
 * @return {Object}        稼働時間テーブル
 * @method
 */
  getHours(month) {
    let me=this, out={}, x, a, k;
    let w=Cp.execSync('last').toString('utf8');
    let f=0;
    let t=w.indexOf('\n', f);
    if(t < 0){t=w.length-1;}
    while(f<w.length){
      x=w.substring(f, t);
      a=me.unspace(x);
      if(a[0]=='reboot' && a[5]==month){
        k=a[6];
        if(!out[k]){out[k]={}; out[k].to='';}
        if(!out[k].from){
          out[k].from = a[7];
        }else if(out[k].from >a[7]){
          out[k].from = a[7];
        }
        if(a[8] == '-' && a[10].indexOf('+')<0){
          if(!out[k].to){
            out[k].to=a[9];
          }else if(out[k].to < a[9]){
            out[k].to = a[9];
          }
        }
        out[k].week = a[4];
      }
      f = t + 1;
      t = w.indexOf('\n', f);
      if(t<0){t=w.length-1;}
    }
    return out;
  }
/**
 * getFrame
 * 月の勤怠テーブル枠を作成
 * @param  {Integer} month 作成月
 * @return {Array}         勤怠オブジェクト（レコード形式配列）
 * @method
 */
  getFrame(month) {
    let d = new Date();
    d.setMonth(month+1);
    d.setDate(1);
    d.setDate(d.getDate()-1);
    let out = [];
    let i;
    for(i=1; i <= d.getDate(); i++){
      out.push({
        日: i, 曜日: '', 開始: '', 終了: '', 時間: '', 休憩: '',
        始: '', 終: '', エラー: ''
      });
    }
    return out;
  }
/**
 * getCsv
 * Csvファイルの取得
 * @param  {String} path ファイルのパス
 * @return {Array}       レコード形式オブジェクトの配列
 * @method
 */
  getCsv(path) {
    let me=this, out;
    try{
      let w=Fs.readFileSync(path);
      out=Cs.csvParse(w, {
        escape: '\\', skip_empty_line: false, trim: false
      });
      me.error='';
    }catch(e){
      out=false;
      me.error=e;
    }
    return out;
  }
/**
 * putCsv
 * CSVファイルの出力
 * @param  {String} path  ファイルのパス
 * @param  {Array}  table データ（レコード形式オブジェクトの配列）
 * @return {Boolean}      true/false OK/NG
 * @method
 */
  putCsv(path, table) {
    let me=this, buf='', i, j, c, t=[];
    c=''; for(j in table[0]){buf+=c+'"'+j+'"'; c=','; t.push(j);}
    buf+='\n';
    for(i in table){
      c=''; for(j in t){buf+=c+'"'+table[i][t[j]]+'"'; c=',';}
      buf+='\n';
    }
    try{
      Fs.writeFileSync(path, buf);
      me.error='';
      return true;
    }catch(e){
      me.error=e;
      return false;
    }
  }
/**
 * upload
 * CSVのアップロード(procomサーバーへcli経由)
 * @param  {String} path ファイルパス
 * @return {Boolean}     true/false OK/NG
 * @method
 */
  upload(path) {
    let me=this;
    let user=process.env.USER;
    try{
      let tb=me.getCsv(path);
      if(tb){
        Cp.execSync(
          './xaProcom upload '+user+path+' '+JSON.stringify(tb)
        ).toString('utf8');
      }
      return true;
    }catch(e){
      return false;
    }
  }
/**
 * unspace
 * スペースデリミテッドセパレーション
 * @param  {String} x 空白により分離されているテキスト
 * @return {Array}    結果配列
 * @method
 */
  unspace(x) {
    let out=[], i=0, e='';
    x+= ' ';
    while(i<x.length){
      if(x[i]==' '){if(e!=''){out.push(e); e='';}}else{e+=x[i];}
      i++;
    }
    return out;
  }
};
