AnsiToHtml = require 'ansi-to-html'
ansiToHtml = new AnsiToHtml()
{$, ScrollView} = require 'atom-space-pen-views'

defaultMessage = 'Gradle Console Empty'

module.exports = class OutputView extends ScrollView
  @content: ->
    @div class: 'build-fusion info-view', =>
      @pre class: 'output', defaultMessage

  html: defaultMessage
  text: ""
  hidden: false
  keepShown: false

  initialize: -> super

  reset: ->
    @html = defaultMessage
    @text = ""

  add: (content, supress = false) ->
    @text += content
    @html = ansiToHtml.toHtml @text
    @find(".output").html(@html)
    @internalShow() unless @hidden or supress

  internalShow: ->
    $.fn.show.call(this)

  finish: ->
    setTimeout =>
      @hide()
      @hidden = false
    , 3000 unless @keepShown

  show: ->
    @hidden = false
    @keepShown = true
    $.fn.show.call(this)

  hide: ->
    @hidden = true
    @keepShown = false
    $.fn.hide.call(this)
