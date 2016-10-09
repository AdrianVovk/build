{View} = require 'atom-space-pen-views'

module.exports =
  class BuildStatus extends View
    @content: ->
      @div "HELLO"

    initialize: ->
      atom.tooltips.add this,
        title: 'TOOLTIP'
        command: 'find-and-replace:show-find'
        commandElement: 'atom-'
