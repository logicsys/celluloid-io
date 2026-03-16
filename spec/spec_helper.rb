require "rubygems"
require "bundler/setup"

require "rspec/retry"
require "celluloid/rspec"
require "celluloid/io"

module Specs
  remove_const(:ALLOW_SLOW_MAILBOXES) if defined?(ALLOW_SLOW_MAILBOXES)
  ALLOW_SLOW_MAILBOXES = true # TODO: Remove hax.
end

# Guard Celluloid.shutdown against being called when the system is already
# stopped. The shared actor examples call Celluloid.shutdown in their own
# around hook, which can leave the system nil before the library: :IO
# around hook from configure_rspec.rb tries to shut down again.
module Celluloid
  class << self
    alias_method :shutdown_without_guard, :shutdown
    def shutdown
      return unless running?
      shutdown_without_guard
    end
  end
end

Dir[*Specs::INCLUDE_PATHS].map { |f| require f }
