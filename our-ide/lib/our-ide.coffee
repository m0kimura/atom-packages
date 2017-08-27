{ConfigObserver} = require 'atom'

cp = require('child_process')
spawn = cp.spawn
fs = require('fs')
url = require('url')
p = require('path')
cs = require('./csv-treat.js')

OurIdeView = require './our-ide-view'
OurRunnerView = require './our-runner-view'

class OurIde
  config:
    showOutputWindow:
      title: '実行結果のペインへの表示'
      description: 'コマンド実行時に結果をペインに表示するかどうかtrue/false'
      type: 'boolean'
      default: true
      order: 1
    ##
    paneSplitDirection:
      title: 'ペインの追加方向'
      description: 'ペインを追加する場合の方向(選択)'
      type: 'string'
      default: 'Down'
      enum: ['Right', 'Down', 'Up', 'Left']
    ##
  ##

  cfg:
    ext: 'runner.extensions'
    scope: 'runner.scopes'
  ##

  defaultExtensionMap:
    'spec.coffee': 'mocha'
    'ps1': 'powershell -file'
    '_test.go': 'go test'
  ##

  defaultScopeMap:
    coffee: 'coffee'
    js: 'node'
    ruby: 'ruby'
    python: 'python'
    go: 'go run'
    shell: 'bash'
    powershell: 'powershell -noninteractive -noprofile -c -'
  ##

  timer: null
  extensionMap: null
  scopeMap: null
  splitFuncDefault: 'splitRight'
  splitFuncs:
    Right: 'splitRight'
    Left: 'splitLeft'
    Up: 'splitUp'
    Down: 'splitDown'
  ##

  debug: (args...) ->
    console.debug('[our-ide]', args...)
  ##

  consumeTablrModelsServiceV1: (api) ->
    @CSVEditor = new api.CSVEditor()

  initEnv: ->
    if process.platform == 'darwin'
      [shell, out] = [process.env.SHELL || 'bash', '']
      @debug('Importing ENV from', shell)
      pid = spawn(shell, ['--login', '-c', 'env'])
      pid.stdout.on 'data', (chunk) -> out += chunk
      pid.on 'error', =>
        @debug('Failed to import ENV from', shell)
      ##
      pid.on 'close', ->
        for line in out.split('\n')
          match = line.match(/^(\S+?)=(.+)/)
          process.env[match[1]] = match[2] if match
        ##
      ##
      pid.stdin.end()
    ##
  ##

  destroy: ->
    atom.config.unobserve @cfg.ext
    atom.config.unobserve @cfg.scope
  ##

  activate: ->
    @initEnv()
    atom.config.setDefaults @cfg.ext, @defaultExtensionMap
    atom.config.setDefaults @cfg.scope, @defaultScopeMap
    atom.config.observe @cfg.ext, =>
      @extensionMap = atom.config.get(@cfg.ext)
    atom.config.observe @cfg.scope, =>
      @scopeMap = atom.config.get(@cfg.scope)
    atom.commands.add 'atom-workspace', 'our-ide:menu', => @show()
    atom.commands.add 'atom-workspace', 'our-ide:file', => @run(false)
    atom.commands.add 'atom-workspace', 'our-ide:ticket', => @ticket()
    atom.commands.add 'atom-workspace', 'our-ide:hours', => @hours()
    atom.commands.add 'atom-workspace', 'our-ide:selection', => @run(true)
    atom.commands.add 'atom-workspace', 'our-ide:stop', => @stop()
    atom.commands.add 'atom-workspace', 'our-ide:close', => @stopAndClose()
    atom.commands.add '.our-ide', 'run:copy', ->
      atom.clipboard.write(window.getSelection().toString())
    ##
    home = process.env.HOME
    @menus = @getJson(home + '/.atom/our-ide.json')
    if @menus.automation
      @automation()
    ##
  ##

  automation: () ->
    try
      user = process.env.USER
      home = process.env.HOME
      dt = cp.execSync('./xaProcom automation userenv '+user)
      dt = JSON.parse(dt)
      ba = fs.readFileSync(home+'/.userenv')
      ba = JSON.parse(ba)
      bt = {}
      f= 0; t = ba.indexOf('\n'); if t < 0 then t = ba.length
      while f < ba.length
        x = ba.substring(f, t); a=x.split('=')
        if a[0]
          bt[a[0]]=a[1]
          f=t+1
          t=ba.indexOf('\n', f); if t<0 then t=ba.length
        ##
      ##
      out=''
      for key, value in dt
        out+=key+'='+value+'\n'
      ##
      for key, value in ba
        if !dt[key]
          out+=key+'='+value+'\n'
        ##
      ##
      fs.writeFileSync(home+'/.userenv')
      cp.execSync('source xsSetenv .userenv')
      atom.notifications.addInfo('自動初期設定しました。')
      dt = cp.execSync('./xaProcom automation xsAuto '+user)
      out=''
      dt = JSON.parse(dt)
      for x in dt
        out+=x+'\n'
      ##
      fs.writeFileSync(home+'/bin/xsAuto')
      cp.execSync('chmod +x '+home+'/bin/xsAuto')
      cp.exec('xsAuto')
    catch e
      atom.notifications.addError('自動初期処理ができませんでした。\n'+e)
    ##
  ##

  show: () ->
    editor = atom.workspace.getActiveTextEditor()
    home = process.env.HOME
    menu = @solveDepend(editor)
    view = new OurIdeView(@menus[menu])
  ##

  run: (selection) ->
    editor = atom.workspace.getActiveTextEditor()
    return unless editor?
    if selection
      cmd = @commandFor(editor, selection)
    else
      cmd = @localexec(editor)
      console.log('xx120', cmd)
      if cmd == 'exit'
        return
      else if cmd == ''
        cmd = @commandFor(editor, selection)
      ##
    ##
    unless cmd?
      console.warn("適切な実行が設定されていません '#{path}'")
      return

    if atom.config.get('our-ide.showOutputWindow')
      {pane, view} = @runnerView()
      if not view?
        view = new OurRunnerView(editor.getTitle())
        panes = atom.workspace.getPanes()
        dir = atom.config.get('our-ide.paneSplitDirection')
        dirfunc = @splitFuncs[dir] || @splitFuncDefault
        pane = panes[panes.length - 1][dirfunc](view)
    else
      view =
        mocked: true
        append: (text, type) ->
          if type == 'stderr'
            console.error(text)
          else
            console.log(text)
        scrollToBottom: ->
        clear: ->
        footer: ->

    unless view.mocked
      view.setTitle(editor.getTitle())
      pane.activateItem(view)

    @execute(cmd, editor, view, selection)
  ##

  ticket: () ->
    editor = atom.workspace.getActiveTextEditor()
    pa = editor.getPath()
    file = @filepart(pa)
    url = cp.execSync('~/.atom/packages/our-ide/lib/xaProcom ticket '+file)
    #atom.workspace.open(url.toString('utf8'))
    cp.exec('xdg-open '+url)
    return "exit"
  ##

  hours: () ->
    hd = new cs()
    path=hd.hours()
    atom.workspace.open(path)
  ##

  localexec: (editor) ->
    pa = editor.getPath()
    part = pa.split('/')
    path = @userPath(part)
    file = @filepart(pa)
#
# ~/docker
    if part[3] == 'docker'
      if part[4] == 'include'
        return 'dex build ' + part[5]
      else
        atom.notifications.addError('ビルドできません。')
        return 'exit'
      ##
    #
    # cordova
    else if part[4] == 'cordova'
      return 'exe cordovaide ' + part[5] + ' ' + part[3] + ' build'
    else if part[5] == 'cordova'
      return 'exe cordovaide ' + part[6] + ' ' + part[3] +
       '/' + part[4] + ' build'
    ##
    #
    # platformio
    else if part[4] == 'platformio'
      return 'exe platformio ' + part[5] + ' ' + part[3] + ' build'
    else if part[5] == 'platformio'
      return 'exe platformio ' + part[6] + ' ' + part[3] +
       '/' + part[4] + ' build'
    ##
    #
    # electron
    else if part[4] == 'electron'
      return 'exe electron ' + part[5] + ' ' + part[3]
    else if part[5] == 'electron'
      return 'exe electron ' + part[6] + ' ' + part[3] + '/' + part[4]
    ##
    #
    # ino
    else if part[4] == 'esp32'
      return 'exe espidf ' + part[5] + ' ' + part[3]
    else if part[5] == 'esp32'
      return 'exe espidf ' + part[6] + ' ' + part[3] + '/' + part[4]
    ##


    switch @modifier(file)
      # page
      when 'page'
        if part[3] == @menus.websource
          if part.length == 5
            b = part[4].split('.')
            atom.workspace.open('http://localhost/' + b[0] + '.html')
            return 'exit'
          ##
          if part.length == 6
            b = part[5].split('.')
            atom.workspace.open(
              'http://localhost/' + part[4] + '/' + b[0] + '.html'
            )
            return 'exit'
          ##
          atom.notifications.addError('実行できません。')
          return 'exit'
        ##
      # js
      when 'js'
        console.log('js')
        return 'exe node ' + file + ' ' + path
      # sh
      when 'sh'
        console.log('sh')
        return pa
      # jse
      when 'jse'
        console.log('jse')
        return pa
      # py
      when 'py'
        console.log('py')
        return 'exe python ' + file + ' ' + path
      # coffee
      when 'coffee'
        console.log('coffee')
        return 'exe coffee ' + file + ' ' + path
      # aws
      when 'aws'
        console.log('aws')
        return 'exe aws ' + file + ' ' + path
      when 'tsh'
        a=@loadFile(pa)
        p=editor.getCursorScreenPosition()
        out=''; c=''
        f=false
        l=0
        for x in a
          console.log x
        for x in a
          l++
          console.log('#329', l, x)
          if l == p.row + 1
            console.log('#330', l, p.row+1, x)
            if x == 'do'
              f=true
              console.log('#334')
            else
              atom.notifications.addInfo('指定した行がdoではありません')
            　return 'exit'
            ##
          else
            console.log('#338', x, out)
            if x == 'end'
              f = false
            ##
            console.log('#342'+f)
            if f
              out=c+x; c=' && '
              console.log('#342')
            ##
          ##
        ##
        console.log('#344')
        if f
          atom.notifications.addInfo('endマークがありません')
        else
          console.log '#342', out
        console.log '#343'
        return 'exit'
      # error
      else
        atom.notifications.addError('拡張子が対象外です。')
        return 'exit'
    ####
    return 'exit'
  ##

  solveDepend: (editor) ->
    pa = editor.getPath()
    part = pa.split('/')
    path = @userPath(part)
    file = @filepart(pa)
#
# ~/docker
    if part[3] == 'docker'
      return 'main'
    ##
#
# cordova
    else if part[4] == 'cordova'
      return 'main'
    else if part[5] == 'cordova'
      return 'main'
    ##
#
# platformio
    else if part[4] == 'platformio'
      return 'platformio'
    else if part[5] == 'platformio'
      return 'platformio'
    else
      return 'main'
    ##
    return false
  ##

  stop: (view) ->
    if @child
      view ?= @runnerView().view
      if view and view.isOnDom()?
        view.append('^C', 'stdin')
      else
        @debug('Killed child', @child.pid)
      @child.kill('SIGINT')
      if @child.killed
        @child = null
    clearInterval(@timer) if @timer
    @timer = null

  stopAndClose: ->
    {pane, view} = @runnerView()
    pane?.removeItem(view)
    @stop(view)

  execute: (cmd, editor, view, selection) ->
    @stop()
    view.clear()

    args = []
    if editor.getPath()
      editor.save()
#      args.push(editor.getPath()) if !selection
    console.log("#{cmd}", cmd)
    splitCmd = cmd.split(/\s+/)
    if splitCmd.length > 1
      cmd = splitCmd[0]
      args = splitCmd.slice(1).concat(args)
    try
      dir = atom.project.getPaths()[0] || '.'
      try
        if not fs.statSync(dir).isDirectory()
          throw new Error("Bad dir")
      catch
        dir = '.'
      @child = spawn(cmd, args, cwd: dir)
      console.log('#spawn')
      console.log(cmd)
      console.log(args)
      @timer = setInterval((-> view.appendFooter('.')), 750)
      currentPid = @child.pid
      @child.on 'error', (err) =>
        if err.message.match(/\bENOENT$/)
          view.append('エラーコマンド: ' + cmd + '\n', 'stderr')
          view.append('パスは正しいですか?\n\n', 'stderr')
          view.append('ENV PATH: ' + process.env.PATH + '\n\n', 'stderr')
        view.append(err.stack, 'stderr')
        view.scrollToBottom()
        @child = null
        clearInterval(@timer) if @timer
      @child.stderr.on 'data', (data) ->
        view.append(data, 'stderr')
        view.scrollToBottom()
      @child.stdout.on 'data', (data) ->
        view.append(data, 'stdout')
        view.scrollToBottom()
      @child.on 'close', (code, signal) =>
        if @child && @child.pid == currentPid
          time = ((new Date - startTime) / 1000)
          view.appendFooter(" Exited with code=#{code} in #{time} seconds.")
          view.scrollToBottom()
          clearInterval(@timer) if @timer
    catch err
      view.append(err.stack, 'stderr')
      view.scrollToBottom()
      @stop()

    startTime = new Date
    try
      if selection
        @child.stdin.write(editor.getLastSelection().getText())
      else if !editor.getPath()
        @child.stdin.write(editor.getText())
      @child.stdin.end()
    view.footer("Running: #{cmd} (cwd=#{editor.getPath()} pid=#{@child.pid}).")

  commandFor: (editor, selection) ->
    # try to find a shebang
    shebang = @commandForShebang(editor)
    return shebang if shebang?

    # Don't lookup by extension from selection.
    if (!selection)
      # try to lookup by extension
      if editor.getPath()?
        for ext in Object.keys(@extensionMap).sort((a,b) -> b.length - a.length)
          boundary = if ext.match(/^\b/) then '' else '\\b'
          if editor.getPath().match(boundary + ext + '$')
            return @extensionMap[ext]

    # lookup by grammar
    scope = editor.getLastCursor().getScopeDescriptor().scopes[0]
    for name in Object.keys(@scopeMap)
      if scope.match('^source\\.' + name + '\\b')
        return @scopeMap[name]

  commandForShebang: (editor) ->
    match = editor.lineTextForBufferRow(0).match(/^#!\s*(.+)/)
    match and match[1]

  runnerView: ->
    for pane in atom.workspace.getPanes()
      for view in pane.getItems()
        return {pane: pane, view: view} if view instanceof OurRunnerView
    {pane: null, view: null}

  lastOf: (txt, x) ->
    i = txt.length - 1
    while i > -1
      if txt[i] == x
        return i
      ##
      i--
    ##
    return -1
  ##

  pullDir: (txt) ->
    i = this.lastOf(txt, '/')
    return txt.substr(0, i+1)
  ##

  repby: (txt, x, y) ->
    out = ''
    i
    for i in txt
      if txt[i] == x
        out += y
      else
        out += txt[i]
      ##
    ##
    return out
  ##

  separate: (txt, x) ->
    out = []
    i
    out[0] = ''
    out[1] = ''
    f=true
    for i in txt
      if f && txt[i] == x
        f = false
      else
        if f
          out[0] += txt[i]
        else
          out[1] += txt[i]
        ##
      ##
    ##
    return out
  ##

  modifier: (x) ->
    p = @lastOf(x, '.')
    if p < 0
      return ''
    ##
    p++
    return x.substr(p)
  ##

  filepart: (x) ->
    p = @lastOf(x, '/')
    if p < 0
      return x;
    ##
    p++
    return x.substr(p)
  ##

  pathpart: (x) ->
    p = @lastOf(x, '/')
    if p<0
      return ''
    ##
    return x.substr(0, p+1)
  ##
  getJson: (fn) ->
    try
      rc = @getFs(fn)
      if rc
        return JSON.parse(rc)
      else
        return false
    catch e
      @error=e
  ##
  getFs: (fn) ->
    @error = ''
    if @isExist(fn)
      d = fs.readFileSync(fn).toString()
      return d
    else
      @error = 'file not found file=' + fn
      return false
    ##
  ##
  isExist: (fn) ->
    try
      return fs.existsSync(fn)
    catch e
      return false
    ##
  ##
  userPath: (a) ->
    rc = ''
    i = 0
    s = ''
    for x in a
      if i > a.length - 2
        return rc
      if i > 2
        rc = rc + s + x
        s = '/'
      ##
      i++
    ##
    return rc
  ##
  loadFile: (path) ->
    d=fs.readFileSync(path)
    f=0
    out=[]
    x=' '+d
    while f<d.length-1
      t=x.indexOf('\n', f)
      if t<0 then t=x.length-1
      e=x.substring(f, t)
      out.push(e)
      f=t+1
    ##
    return out
  ##
##
module.exports = new OurIde
