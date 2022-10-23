class ExampleSubcommand < Thor
  desc "hello", "Show an example command"
  long_desc <<~LONGDESC
    Show an example command
        
    Pass --verbose to print detailed information as the command runs.
  LONGDESC
  option :verbose, type: :boolean, default: false
  def hello
    verbose = options[:verbose]
    puts "Hello, world!#{verbose ? ' Verbose version.': ''}"
  end
end