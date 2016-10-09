{CompositeDisposable, BufferedProcess} = require 'atom'
path = require 'path'
fs = require 'fs-plus'

notifyInfo = (message, options) ->
  if atom.config.get 'build-fusion.notify'
    atom.notifications.addInfo(message, options)

notifySuccess = (message, options) ->
  if atom.config.get 'build-fusion.notify'
    atom.notifications.addSuccess(message, options)

notifyWarn = (message, options) ->
  if atom.config.get 'build-fusion.notify'
    atom.notifications.addWarning(message, options)

module.exports = build =
  config:
    notify: # Do we bother the user?
      type: 'boolean'
      default: true
      title: 'Show notifications'
      description: 'Errors will always be displayed'
      order: 1
    useWrapper: # Do we use the fusion wrapper?
      type: 'boolean'
      default: true
      description: 'Use Fusion Wrapper. This allows projects intended for older Fusion versions to be run with the correct configuration.'
      order: 2
    features: # Fusion Compiler Goodies
      type: 'object'
      order: 3
      properties:
        useLiveCompile:
          type: 'boolean'
          default: true
          title: 'Use Live Compile'
          description: 'Use Live Compile to compile code while it is being written, improving build speeds'
        useInstantRun:
          type: 'boolean'
          default: true
          title: 'Use Instant Run'
          description: 'Use Instant Run to run code without packaging it. Improves build speeds'
        useSmartScale:
          type: 'boolean'
          default: true
          title: 'Use Smart Scale'
          description: 'Use Smart Scale to automatically sort and prioritize tasks, allowing maximum efficiency'

  activate: ->
    TaskPicker = require './ui/task-pick'
    PlatformPicker = require './ui/platform-pick'

    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-workspace',
      'build:run': (event) => new PlatformPicker 'run-', (tasks) => @runTask(tasks)
      'build:debug': (event) => notifyInfo 'Debug feature coming soon' # TODO
      'build:release': (event) => new PlatformPicker 'release-', (tasks) => @runTask(tasks)
      'build:run-task': (event) => new TaskPicker (tasks) => @runTask(tasks)
      'build:install-fusion-wrapper': (event) => @runTask('wrapper')
      'build:cancel': (event) => @cancelCompmile()

  consumeStatusBar: (statusBar) -> # TODO
    # TODO: FIX THIS STUFF
    #BuildStatus = require './ui/build-status'
    #statusBar.addRightTile (item: new BuildStatus, priority: 0)

  deactivate: ->
    notifyInfo "Stopping Fusion Build"
    @cancelCompmile()

    # Dispose of all of the objects
    @subscriptions.dispose()

  cmd: (args, dir) => # Runs command with given arguments
    new Promise (resolve, reject) ->
      wrapper = path.join(dir.getPath(), 'gradlew') if atom.config.get 'build-fusion.useWrapper'
      build.proc = new BufferedProcess
        command: if fs.isFileSync(wrapper) then wrapper else path.join(atom.packages.getActivePackage('build-fusion').path, 'fusion', 'bin', 'gradle')
        args: ["-b", "manifest.kt"].concat(args)
        options: {cwd: dir.getPath(), env: process.env}
        stdout: (output) -> console.log "Build Output: #{output}"
        stderr: (error) ->
          notifyWarn 'Fusion Error', detail: "Details: #{error}"
          console.error "Build error: #{error}"
        exit: (code) ->
          if code is 0
            notifySuccess "Fusion Build Complete", detail: "Output Location: #{path.join(dir.getPath(), 'out')}"
            console.log "Build Complete"
            resolve "Build Complete"
          else
            atom.notifications.addError "Fusion Build Failed", detail: "Details: Exit Code #{code}"
            console.error "Build Error: Exit Code #{code}"
            reject code.toString()
      build.proc.onWillThrowError (errorObject) ->
        reject errorObject.error.toString()

  cancelCompmile: -> # Kills compiler process
    if @proc
      @proc.kill()
      notifySuccess "Fusion Build Cancelled"
    else
      atom.notifications.addError "Fusion Build Not Running"

  runTask: (tasks) ->
    notifyInfo "Fusion Build Starting", detail: "Tasks: #{tasks.toString()}"

    # Count up priority here
    @args = tasks

    # Figure out which project to compile
    @dir = atom.project.getDirectories().filter((d) -> d.contains(atom.workspace.getActiveTextEditor()?.getPath()))[0]

    # Run it
    @cmd @args, @dir
