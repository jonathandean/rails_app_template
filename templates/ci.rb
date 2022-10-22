#!/usr/bin/env ruby

# Usage: bin/ci [options]
#
# --no-[STEP]  Exclude the specified step
# --only STEP  Run only the specified step
#
# Examples:
#
#   bin/ci --no-brakeman
#   bin/ci --only rspec

require "open3"
require "optparse"

# Define steps.
# NOTE: The order here determines the order they are performed.
STEPS = {
  "bundle-audit" => "bundle audit check --update",
  "brakeman" => "bundle exec brakeman",
  "rspec" => "bundle exec rspec"
}

def perform_step(name, cmd)
  Open3.popen3(cmd) do |stdin, stdout, stderr, thread|
    { STDOUT => stdout, STDERR => stderr }.each do |output, input|
      Thread.new do
        last_char = nil
        while char = input.getc do
          if last_char.nil? || last_char == "\n"
            output.print "[#{name}] "
          end
          output.print char
          last_char = char
        end
      end
    end

    thread.join

    status = thread.value
    unless status.success?
      exit status.exitstatus
    end
  end
end

options = { steps: STEPS.keys }

OptionParser.new do |parser|
  parser.on("--only=ONLY") do |only|
    options[:steps] = only.split(",")
  end

  STEPS.keys.each do |step|
    parser.on("--no-#{step}") do
      options[:steps].delete(step)
    end
  end
end.parse!

options[:steps].each do |step|
  perform_step step, STEPS[step]
end