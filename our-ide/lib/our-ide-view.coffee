{SelectListView} = require 'atom-space-pen-views'
{Emitter} = require 'event-kit'

spawn = require('child_process').spawn
fs = require('fs')
url = require('url')
p = require('path')

module.exports =
class OurProjectView extends SelectListView
  initialize: ()->
    super
    console.log('#14 emitt')
    @emitter = new Emitter
    @addClass('overlay from-top')
#    @focusFilterEditor()
  ##

  show: (menus) ->
    items = []
    for i of menus
      i=i-0
      if i < 9
        nx = '0'+(i+1)
      else
        nx = i+1
      item={title: menus[i].title, n: nx}
      items.push(item)
    #
    @setItems(items)
    @panel ?= atom.workspace.addModalPanel(item: this)
    @panel.show()

  onDidSelect: (callback) ->
    @emitter.on 'did-select', callback

  viewForItem: (item) ->
    "<li>#{item.n}. #{item.title}</li>"
  ##

  confirmed: (item) ->
    @emitter.emit 'did-select', item
    @panel.hide()
  ##

  cancelled: ->
    console.log("This view was cancelled")
  ##
