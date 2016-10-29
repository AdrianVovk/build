{CompositeDisposable, BufferedProcess} = require 'atom'
path = require 'path'
fs = require 'fs-plus'
download = require 'download'

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
    useNightlyBuilds:
      type: 'boolean'
      default: false
      description: 'Use nightly builds of Fusion Compiler components'
      order: 3
    features:
      # Fusion Compiler Goodies
      type: 'object'
      order: 4
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

  # Lifecycle

  activate: ->
    taskPick = require './ui/task-pick'
    platformPick = require './ui/platform-pick'

    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.config.onDidChange 'build-fusion.useNightlyBuilds', ({oldValue, newValue}) =>
      unless newValue
        @purgeBinary()
        notifyInfo 'Restoring Stable Version of the Fusion Compiler', icon: 'history'
      @update(true, false)

    @fusionStore = path.join(atom.getConfigDirPath(), 'build-fusion')
    @gradlePath = path.join(@fusionStore, 'gradle-dist')
    @avianPath = path.join(@fusionStore, 'avian-dist')
    @update(true, false)

    @subscriptions.add atom.commands.add 'atom-workspace',
      'build:run': (event) => @runTask('run') #platformPick 'run-', (tasks) => @runTask(tasks)
      'build:debug': (event) => notifyInfo 'Debug feature coming soon' # TODO
      'build:release': (event) => platformPick 'release-', (tasks) => @runTask(tasks)
      'build:run-task': (event) => taskPick((tasks) => @runTask(tasks))
      'build:install-fusion-wrapper': (event) => @runTask('wrapper')
      'build:cancel': (event) => @cancelCompmile()
      'build:update-fusion': (event) => @update(false, false)

    if atom.inDevMode()
      @subscriptions.add atom.commands.add 'atom-workspace',
        'build:purge-binary': (event) => @purgeBinary()
        'build:purge-gradle': (event) => @purgeGradle()
        'build:purge-avian': (event) => @purgeAvian()

  deactivate: ->
    notifyInfo "Stopping Any Running Fusion Builds"
    @cancelCompmile()

    @subscriptions.dispose() # Dispose of all of the objects
    @purgeBinary() if atom.packages.isPackageDisabled('build-fusion') # Remove any downloaded gradle and avian disributions

  # Command Runner

  cmd: (args, dir, gradlePath) => # Runs command with given arguments
    new Promise (resolve, reject) =>
      wrapper = path.join(dir.getPath(), 'gradlew') if atom.config.get 'build-fusion.useWrapper'
      build.proc = new BufferedProcess
        command: if fs.isFileSync(wrapper) then wrapper else path.join(gradlePath, 'bin', 'gradle')
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
      notifySuccess "Fusion Build Cancelled", icon: 'x'
    else
      atom.notifications.addError "Fusion Build Not Running"

  runTask: (tasks) ->
    notifyInfo "Fusion Build Starting", detail: "Tasks: #{tasks.toString()}"

    # Count up priority here
    @args = tasks

    # Figure out which project to compile
    @dir = atom.project.getDirectories().filter((d) -> d.contains(atom.workspace.getActiveTextEditor()?.getPath()))[0]

    @cmd @args, @dir, @gradlePath # Run it

  # UI Modifications

  consumeStatusBar: (statusBar) -> # TODO
    # TODO: FIX THIS STUFF
    #BuildStatus = require './ui/build-status'
    #statusBar.addRightTile (item: new BuildStatus, priority: 0)

  # Binary Management

  update: (silent = false, install = true) ->
    gradleDistInfo = if atom.config.get('build-fusion.useNightlyBuilds') then 'http://services.gradle.org/versions/nightly' else 'http://services.gradle.org/versions/current'
    avianDistInfo = 'https://api.github.com/repos/ReadyTalk/avian/tags'
    downloadInfo = []
    downloadInfo.push download(gradleDistInfo, @fusionStore).then (data) =>
      @gradleJson = JSON.parse(data)
      try
        @gradleCurrentJson = JSON.parse(fs.readFileSync(path.join(@fusionStore, 'gradleInfo.json').toString()))
      catch e
        @gradleCurrentJson = JSON.parse('{"version":"0"}')

      infoExt = if atom.config.get('build-fusion.useNightlyBuilds') then 'nightly' else 'current'
      if install
        fs.removeSync(path.join(@fusionStore,"gradleInfo.json"))
        fs.moveSync(path.join(@fusionStore, infoExt), path.join(@fusionStore,"gradleInfo.json"))
      else
        fs.removeSync(path.join(@fusionStore,infoExt))
    downloadInfo.push download(avianDistInfo, @fusionStore).then (data) =>
      tagsJSON = JSON.parse(data)
      jsonString = "{\"version\":\"#{tagsJSON[0].name.split('v')[1]}\",\"downloadUrl\":\"#{tagsJSON[0].zipball_url}\",\"fileNameExt\":\"#{tagsJSON[0].commit.sha.slice(0,7)}\"}"
      @avianJson = JSON.parse(jsonString)
      try
        @avianCurrentJson = JSON.parse(fs.readFileSync(path.join(@fusionStore, 'avianInfo.json').toString()))
      catch e
        @avianCurrentJson = JSON.parse('{"version":"0"}')
      if install
        fs.removeSync(path.join(@fusionStore,"avianInfo.json"))
        fs.removeSync(path.join(@fusionStore, 'tags'))
        fs.writeFile(path.join(@fusionStore, "avianInfo.json"), jsonString)
      else
        fs.removeSync(path.join(@fusionStore, 'tags'))
    Promise.all(downloadInfo).then (values) =>
      doUpdateGradle = @gradleJson?.version > @gradleCurrentJson?.version
      doUpdateAvian = @avianJson?.version > @avianCurrentJson?.version
      fs.makeTree(@fusionStore)
      detailString = ""
      if doUpdateGradle
        detailString += "New Gradle Version: #{@gradleJson.version}"
      if doUpdateAvian
        detailString += "\nNew Avian Version: #{@avianJson.version}"
      if doUpdateGradle or doUpdateAvian
        if install
          console.log 'Build Fusion: Starting Binary Updates'
          notifyInfo 'Updating Fusion Compiler', detail: detailString, icon: 'cloud-download'
          todo = []
          todo.push(@updateGradle()) if doUpdateGradle
          todo.push(@updateAvian()) if doUpdateAvian
          Promise.all(todo).then (values) =>
            notifySuccess 'Fusion Compiler Binary Installed', detail: detailString
        else
          notifyInfo 'Fusion Compiler Update Available', detail: detailString, icon: 'versions', buttons: [
            text: 'Install'
            className: 'icon icon-cloud-download'
            onDidClick: =>
              @update()
          ]
      else
        notifyInfo('Fusion Compiler Not Updated', detail: "Already up to date\nGradle Version: #{@gradleCurrentJson.version}\nAvian Version: #{@avianCurrentJson.version}", icon: 'stop') unless silent


  updateGradle: (silent = false, install = true) ->
    console.log 'Updating Gradle Binary'
    @purgeGradle(false) # Clean out old install directory
    download(@gradleJson.downloadUrl, @fusionStore, extract: true).then () =>
      fs.moveSync(path.join(@fusionStore,"gradle-#{@gradleJson.version}"), @gradlePath)
      console.log 'Gradle Binary Update: Done'

  updateAvian: () ->
    console.log 'Updating Avian Binary'
    @purgeAvian(false) # Clean out old install directory
    download(@avianJson.downloadUrl, @fusionStore, extract: true).then () =>
      fs.moveSync(path.join(@fusionStore,"ReadyTalk-avian-#{@avianJson.fileNameExt}"), @avianPath)
      console.log 'Avian Binary Update: Done'

  purgeBinary: (silent = false) ->
    fs.removeSync(@fusionStore)
    notifySuccess 'Fusion Compiler deactivated' unless silent

  purgeGradle: (purgeDistInfo = true) ->
    fs.removeSync(@gradlePath) if fs.existsSync(@gradlePath)
    distInfoPath = path.join(@fusionStore,'gradleInfo.json')
    fs.removeSync(distInfoPath) if fs.existsSync(distInfoPath) and purgeDistInfo

  purgeAvian: (purgeDistInfo = true) ->
    fs.removeSync(@avianPath) if fs.existsSync(@avianPath)
    distInfoPath = path.join(@fusionStore,'avianInfo.json')
    fs.removeSync(distInfoPath) if fs.existsSync(distInfoPath) and purgeDistInfo
