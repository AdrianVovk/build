{CompositeDisposable} = require 'atom'

notifyInfo = (message, options) ->
  if atom.config.get 'build.notify'
    atom.notifications.addInfo(message, options)

notifySuccess = (message, options) ->
  if atom.config.get 'build.notify'
    atom.notifications.addInfo(message, options)

module.exports = Build =
  config:
    notify:
      type: 'boolean'
      default: true
      title: 'Show notifications'
      description: 'Errors will always be displayed'
    useWrapper:
      type: 'boolean'
      default: true
      title: 'Use gradle wrapper'
      description: 'Use gradle wrapper instead of the local gradle installation to build projects'

  activate: ->
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.commands.add 'atom-workspace',
      'build:run': (event) =>
        @runTask('Run')
      'build:debug': (event) =>
        @runTask('Debug')
      'build:run-task': (event) =>
        TaskPicker = require './ui/task-pick'
        new TaskPicker(@runTask)

  deactivate: ->
    @subscriptions.dispose()

  runTask: (task, opts) ->
    notifyInfo "Running task '#{task}'", detail: "Options: #{opts}"
    notifySuccess "Task '#{task}' complete", detail: "Options: #{opts}"
