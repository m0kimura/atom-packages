{ConfigObserver} = require 'atom'

cp = require('child_process')
spawn = cp.spawn
fs = require('fs')
url = require('url')
p = require('path')
lc = require('./our-launcher.js')
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
    atom.commands.add 'atom-workspace', 'our-ide:history', => @history()
    atom.commands.add 'atom-workspace', 'our-ide:hours', => @hours()
    atom.commands.add 'atom-workspace', 'our-ide:selection', => @run(true)
    atom.commands.add 'atom-workspace', 'our-ide:stop', => @stop()
    atom.commands.add 'atom-workspace', 'our-ide:close', => @stopAndClose()
    atom.commands.add '.our-ide', 'run:copy', ->
      atom.clipboard.write(window.getSelection().toString())
    ##
    home = process.env.HOME
    user = process.env.USER
    @launcher=new lc(user, home)
    @menus=@launcher.getMenus()
    if @menus.automation
      @automation()
    ##
  ##

  automation: () ->
    if @launcher.userenv()
      atom.notifications.addInfo('自動初期設定しました。')
    else
      atom.notifications.addError('自動初期設定ができませんでした。\n'+e)
    ##
    if @launcher.autoexec()
      atom.notifications.addInfo('自動初期処理を実行しました。')
    else
      atom.notifications.addError('自動初期処理が実行できませんでした。\n'+e)
    ##
  ##

  show: () ->
    me = this
    try
      editor = atom.workspace.getActiveTextEditor()
    catch e
      editor = false
    home = process.env.HOME
    if editor
      pa = editor.getPath()
      menu = @launcher.solveDepend(pa)
      dt={}
      dt.file = @launcher.filepart(pa)
      dt.path = @launcher.pathpart(pa).substr(home.length)
      dt.fullpath = pa
    else
      menu = @menus.main
    ##
    if !@menuView
      @menuView = new OurIdeView()
      @menuView.onDidSelect (item) ->
        i=item.n - 1
        if item.title == 'キャンセル'
          return
        if menu[i].command
          me.runcmd(me.launcher.expand(menu[i].command, dt), menu[i].title)
        else if x.procedure
          me.runproc(menu[i])
        ##
        console.log('#159', item)
      ##
    ##
    @menuView.show(menu)
  ##

  runproc: (x) ->
    switch x.procedure
      when 'test'
        atom.notifications.addInfo(x.title+'処理しました。')
      when 'template'
        try
          h = process.env.HOME
          o = h+x.parameters[1]+x.parameters[0]
          if ! fs.existsSync(o)
            r = fs.createReadStream(h+'/テンプレート/'+x.parameters[0])
            w = fs.createWriteStream(o)
            r.pipe(w)
          ##
          atom.workspace.open(o)
        catch e
          atom.notifications.addError('ERROR:'+e)
      ##
    ##
  ##

  run: (selection) ->
    editor = atom.workspace.getActiveTextEditor()
    return unless editor?
    editor.save()
    if selection
      cmd = @commandFor(editor, selection)
    else
      pa = editor.getPath()
      if @launcher.filepart(pa)=='.history'
        cmd = editor.getSelectedText()
        cmd = cmd.substr(0, cmd.length-1)
        cmd = cmd.replace('\n', ' && ')
        @runcmd(cmd, '履歴からの実行')
        return
      ##
      {mode, cmd} = @launcher.localexec(pa)
      if mode=='' && @launcher.modifier(pa)=='tsh'
        {mode, cmd}=@launcher.templauncher(pa, editor.getCursorScreenPosition())
      ##
      if mode=='NG'
        atom.notifications.addError(@launcher.error)
        return
      ##
      if mode=='exit' || cmd=='exit'
        return
      ##
      if mode=='atom'
        atom.workspace.open(cmd)
        return
      ##
      if mode=='cmd' && !cmd
        atom.notifications.addError('対応するコマンドが見つかりませんでした。')
        return
        ##
      ##
    ##
    unless cmd?
      console.warn("適切な実行が設定されていません '#{path}'")
      return
    @runcmd(cmd, editor.getTitle())
  ##

  runcmd: (cmd, title) ->
    console.log('#214', cmd)
    if atom.config.get('our-ide.showOutputWindow')
      {pane, view} = @runnerView()
      if not view?
        view = new OurRunnerView(title)
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
      view.setTitle(title)
      pane.activateItem(view)

    @execute(cmd, false, view, false)
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

  history: () ->
    home=process.env.HOME
    dt=@launcher.loadFile(home+'/.bash_history')
    x=''
    for i of dt
      x+=dt[i]+'\n'
    ##
    atom.workspace.open(home+'/.history')
    .then (editor) ->
      editor.setText(x)
      editor.setCursorBufferPosition([dt.length-1, 0])
    .catch (error) ->
      atom.notifications.addError('open error :'+error)
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
    a=@launcher.spacedelimit(cmd)
    ##splitCmd = cmd.split(/\s+/)
    ##if splitCmd.length > 1
    ##  cmd = splitCmd[0]
    ##  args = splitCmd.slice(1).concat(args)
    cmd=a[0]
    args=a.slice(1).concat(args)
    try
      dir = atom.project.getPaths()[0] || '.'
      try
        if not fs.statSync(dir).isDirectory()
          throw new Error("Bad dir")
      catch
        dir = '.'
      @child = spawn(cmd, args, {cwd: dir, shell: true, env: process.env})
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
#    try
#      if selection
#        @child.stdin.write(editor.getLastSelection().getText())
#      else if !editor.getPath()
#        @child.stdin.write(editor.getText())
    @child.stdin.end()
    view.footer("Running: #{cmd} (pid=#{@child.pid}).")

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
##
module.exports = new OurIde
