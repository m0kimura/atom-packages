{ConfigObserver} = require 'atom'

spawn = require('child_process').spawn
fs = require('fs')
url = require('url')
p = require('path')

OurIdeView = require './our-ide-view'
OurRunnerView = require './our-runner-view'

class OurIde
  config:
    showOutputWindow:
      title: 'Show Output Pane'
      description: 'Displays the output pane when running commands.'
      type: 'boolean'
      default: true
      order: 1
    ##
    paneSplitDirection:
      title: 'Pane Split Direction'
      description: 'The direction to split when opening the output pane.'
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
    atom.commands.add 'atom-workspace', 'our-ide:selection', => @run(true)
    atom.commands.add 'atom-workspace', 'our-ide:stop', => @stop()
    atom.commands.add 'atom-workspace', 'our-ide:close', => @stopAndClose()
    atom.commands.add '.our-ide', 'run:copy', ->
      atom.clipboard.write(window.getSelection().toString())
    ##
  ##

  show: () ->
    home = process.env.HOME
    menus = @getJson(home + '/.atom/our-ide.json')
    view = new OurIdeView(menus)
  ##

  run: (selection) ->
    editor = atom.workspace.getActiveTextEditor()
    return unless editor?
    if selection
      cmd = @commandFor(editor, selection)
    else
      cmd = @localexec(editor)
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

  localexec: (editor) ->
    path = editor.getPath()
    folder = path.split('/')
    if folder[3] == 'docker'
      if folder[4] == 'include'
        return 'dex build ' + folder[5]
      else
        atom.notifications.addError('ビルドできません。')
        return 'exit'
      ##
    else if folder[4] == 'cordova' or folder[5] == 'cordova'
      return 'exe cordova build'
    ####
    switch @modifier(path)
      when 'page'
        if folder[3] == 'www-kmrweb-net'
          if a.length == 5
            b = folder[4].split('.')
            atom.workspace.open('http://localhost/' + b[0] + '.html')
            return 'exit'
          ##
          if a.length == 6
            b = a[5].split('.')
            atom.workspace.open(
              'http://localhost/' + a[4] + '/' + b[0] + '.html'
            )
            return 'exit'
          ##
          atom.notifications.addError('実行できません。')
          return 'exit'
        ##
      when 'js'
        console.log('js')
        return ''
      when 'sh'
        console.log('sh')
        return ''
      when 'py'
        console.log('py')
        return 'exe pythoncv'
      else
        atom.notifications.addError('拡張子が対象外です。')
        return false
    ####
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
      args.push(editor.getPath()) if !selection
    splitCmd = cmd.split(/\s+/)
    if splitCmd.length > 1
      cmd = splitCmd[0]
      args = splitCmd.slice(1).concat(args)
    try
      dir = atom.project.getPaths()[0] || '.'
      console.log(dir)
      try
        if not fs.statSync(dir).isDirectory()
          throw new Error("Bad dir")
      catch
        dir = '.'
      @child = spawn(cmd, args, cwd: dir)
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
    p = x.lastIndexOf('.')
    if p < 0
      return ''
    ##
    p++
    return x.substr(p)
  ##

  filepart: (x) ->
    p = x.lastIndexOf('/')
    if p < 0
      return x;
    ##
    p++
    return x.substr(p)
  ##

  pathpart: (x) ->
    p = x.lastIndexOf('/')
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
##
module.exports = new OurIde
