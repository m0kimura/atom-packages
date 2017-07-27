{SelectListView} = require 'atom-space-pen-views'
OurRunnerView = require './our-runner-view'

spawn = require('child_process').spawn
fs = require('fs')
url = require('url')
p = require('path')

module.exports =
class OurProjectView extends SelectListView
  initialize: (menus)->
#    @menus = @getJson(home + '/.atom/our-ide.json')
    super
    @addClass('overlay from-top')
    @menus = menus
    items = []
    for i of @menus
      items.push(@menus[i].title)
    #
    @setItems(items)
    @panel ?= atom.workspace.addModalPanel(item: this)
    @panel.show()
#    @focusFilterEditor()
  ##

  viewForItem: (item) ->
    "<li>#{item}</li>"
  ##

  confirmed: (item, ix) ->
    for x in @menus

      if x.title == item
        @runcmd(x.command)
      ##
    ##
    @panel.hide()
  ##

  cancelled: ->
    console.log("This view was cancelled")
  ##

  runcmd: (cmd) ->
    {pane, view} = @runnerView()
    if not view?
      view = new OurRunnerView('プロジェクト環境')
      panes = atom.workspace.getPanes()
      dir = 'Bottom'
      dirfunc = @splitFuncs[dir] || @splitFuncDefault
      pane = panes[panes.length - 1][dirfunc](view)
    pane.activateItem(view)
    @execute(cmd, view)

  splitFuncDefault: 'splitRight'
  splitFuncs:
    Right: 'splitRight'
    Left: 'splitLeft'
    Up: 'splitUp'
    Down: 'splitDown'

  execute: (cmd, view) ->
#    @stop()
    view.clear()

    args = []
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
        dir = p.dirname(dir)
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

  runnerView: ->
    for pane in atom.workspace.getPanes()
      for view in pane.getItems()
        return {pane: pane, view: view} if view instanceof OurRunnerView
    {pane: null, view: null}
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
