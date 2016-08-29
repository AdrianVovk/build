{CompositeDisposable} = require 'atom'
{TextEditorView, View} = require 'atom-space-pen-views'

module.exports = (callback) -> new TaskPicker(callback)

class TaskPicker extends View
  @content: ->
    @div =>
      @subview 'taskInput', new TextEditorView(mini: true, placeholderText: 'Name of the task you want to run')

  initialize: (callback) ->
    @commands = new CompositeDisposable
    @currentPane = atom.workspace.getActivePane()
    @panel = atom.workspace.addModalPanel(item: this, visible: false)
    @panel.show()
    @taskInput.focus() #Bring the focus onto the task textbox

    @taskInput.on 'blur', => @close() # If focus is lost, close the window
    @commands.add atom.commands.add 'atom-text-editor', 'core:cancel': (e) => @close()

    @commands.add atom.commands.add 'atom-text-editor', 'core:confirm': (e) =>
      callback(@taskInput.getText())
      @close()

  close: ->
    @panel?.destroy()
    @commands.dispose()
    @currentPane.activate()
