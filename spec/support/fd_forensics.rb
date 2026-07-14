# Temporary forensic instrumentation for the residual EBADF flake.
# Enable with FD_FORENSICS=1. Scans all open Ruby IO objects after each
# example and after each Celluloid.shutdown, looking for:
#
#   * ZOMBIE: an IO whose fd is gone from /proc/self/fd — its fd was closed
#     at kernel level while the Ruby object still thinks it is open. When GC
#     later finalizes it, it will close() whatever now owns that fd number.
#   * DUP: two open IO objects sharing one fd number — the recycling has
#     already happened; the older object is the armed bomb.
#
# Detected zombies are reported with their allocation site and defused
# (autoclose = false) so each planting event is caught exactly once and
# does not cascade into later examples.
if ENV["FD_FORENSICS"]
  require "objspace"
  ObjectSpace.trace_object_allocations_start

  module FdForensics
    LOG = File.open(ENV.fetch("FD_FORENSICS_LOG", "fd_forensics.log"), "a")
    LOG.sync = true

    def self.describe(io)
      alloc = begin
        "#{ObjectSpace.allocation_sourcefile(io)}:#{ObjectSpace.allocation_sourceline(io)}"
      rescue StandardError
        "alloc-unknown"
      end
      "#{io.class}(0x#{io.object_id.to_s(16)}) allocated at #{alloc}"
    end

    def self.scan(label)
      example = RSpec.current_example ? RSpec.current_example.full_description : "(no example)"
      seen = {}
      ObjectSpace.each_object(IO) do |io|
        begin
          next if io.closed?
          next unless io.autoclose? # defused/borrowed fds can't detonate via GC
          fd = io.fileno
          next if fd.nil? || fd < 3 # skip stdio
        rescue IOError, ArgumentError
          next
        end

        unless File.exist?("/proc/self/fd/#{fd}")
          LOG.puts "[#{label}] ZOMBIE fd=#{fd} #{describe(io)} | during: #{example}"
          io.autoclose = false rescue nil
          next
        end

        if (other = seen[fd])
          LOG.puts "[#{label}] DUP fd=#{fd} #{describe(io)} AND #{describe(other)} | during: #{example}"
        else
          seen[fd] = io
        end
      end
    rescue StandardError => e
      LOG.puts "[#{label}] scan error: #{e.class}: #{e.message}"
    end
  end

  module Celluloid
    class << self
      alias_method :shutdown_without_forensics, :shutdown
      def shutdown
        result = shutdown_without_forensics
        FdForensics.scan("post-shutdown")
        result
      end
    end
  end

  RSpec.configure do |config|
    config.after(:each) do
      FdForensics.scan("post-example")
    end
  end
end
