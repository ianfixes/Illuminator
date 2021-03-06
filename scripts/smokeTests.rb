require File.join(File.expand_path(File.dirname(__FILE__)), 'classes/IlluminatorFramework.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'classes/IlluminatorOptions.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'classes/XcodeUtils.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'classes/HostUtils.rb')

# Change directory to sample app and use that for the workspace
Dir.chdir 'SampleApp/AutomatorSampleApp'
workspace = Dir.pwd

allTestPath = '../../SampleApp/SampleTests/tests/AllTests.js'
allTestPath = HostUtils.realpath(allTestPath)

# Hard-coded options

options = IlluminatorOptions.new
options.xcode.appName = 'AutomatorSampleApp'
options.xcode.scheme = 'AutomatorSampleApp'

options.illuminator.entryPoint = 'runTestsByTag'
options.illuminator.test.tags.any = ['smoke']
options.illuminator.clean.xcode = true
options.illuminator.clean.artifacts = true
options.illuminator.clean.noDelay = true
options.illuminator.task.build = true
options.illuminator.task.automate = true
options.illuminator.task.setSim = true
options.simulator.device = 'iPhone 5'
options.simulator.language = 'en'
options.simulator.killAfter = true

options.instruments.doVerbose = false
options.instruments.timeout = 30

options.javascript.testPath = allTestPath
options.javascript.implementation = 'iPhone'

if XcodeUtils.instance.isXcodeMajorVersion 5
  options.simulator.device = 'iPhone Retina (4-inch)'
end

options.simulator.version = '8.1'
success8 = IlluminatorFramework.runWithOptions options, workspace

options.illuminator.clean.xcode = false
options.illuminator.clean.artifacts = false
options.illuminator.task.build = false
options.simulator.version = '7.1'
success7 = IlluminatorFramework.runWithOptions options, workspace

exit 1 unless success7 and success8
