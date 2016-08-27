
runTask = (task) ->
  atom.notifications.addSuccess('Task: ' + task)

module.exports =
  config:
    useWrapper:
      type: 'boolean'
      default: true
      title: 'Use gradle wrapper'
      description: 'Use gradle wrapper instead of the local gradle installation to build projects'

  activate: (state) ->
    atom.commands.add 'atom-workspace',
      'build:run': (event) ->
        atom.notifications.addInfo 'Running',
          detail: 'Configuration: NA'
        runTask('Run')
      'build:debug': (event) ->
        runTask('Debug')
      'build:run-task': (event) ->
        runTask('Test Task')
