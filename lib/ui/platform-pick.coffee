{$, $$} = require 'atom-space-pen-views'
MultiSelectList = require './multi-select-list'

{CompositeDisposable} = require 'atom'

module.exports = (prefix, callback) -> new PlatformPicker(prefix, callback)

class PlatformPicker extends MultiSelectList

  getFilterKey: -> 'name'

  initialize: (@prefix, @callback) ->
    super
    @setItems [
      {name: 'Linux', id: 'linux'},
      {name: 'Windows', id: 'win32'},
      {name: 'macOS', id: 'darwin'},
      {name: 'Android', id: 'android'},
      {name: 'iOS', id: 'ios'}
    ]

    @currentPane = atom.workspace.getActivePane()
    @panel = atom.workspace.addModalPanel(item: this, visible: false)
    @panel.show()

    @dispose = atom.commands.add 'atom-text-editor', 'core:cancel': (e) => @cancel()

  # TODO: Extra Functionality
  # addButtons: ->
  #   checkboxes = $$ ->
  #     @div class:'buttons', =>
  #       @input class:'input-toggle', type:'checkbox'
  #   checkboxes.appendTo(this)
  #   super

  viewForItem: (item, matchedStr) ->
    $$ ->
      @li =>
        @text(item.name)


  completed: (items) ->
    @cancel()
    tasks = []
    tasks = tasks.concat(@prefix + item.id) for item in items
    @callback(tasks)

  cancel: ->
    @panel?.destroy()
    @dispose.dispose()
    @currentPane.activate()
