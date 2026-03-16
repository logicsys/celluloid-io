require "spec_helper"

RSpec.describe Celluloid::IO, library: :IO do
  it_behaves_like "a Celluloid Actor", Celluloid::IO do
    let(:example_port) { assign_port }

    context :timeouts do
      let :sleeping_actor_class do
        Class.new do
          include Celluloid::IO
          def initialize(addr, port)
            @server = Celluloid::IO::TCPServer.new(addr, port)
            async { @server.accept ; sleep 10 }
          end
        end
      end
      let :foo_actor_class do
        Class.new do
          include Celluloid::IO
          def initialize(addr, port)
            @sock = Celluloid::IO::TCPSocket.new(addr, port)
          end

          # returns true if the operation timedout
          def timedout_read(duration)
            begin 
              timeout(duration) do
                @sock.wait_readable
              end
            rescue Celluloid::TaskTimeout
              return true
            end
            false
          end
 
          # returns true if the socket is still registered (ArgumentError from IO selector)
          # returns false if the socket was freed and can be re-registered
          def failed_write
            begin
              timeout(1) do
                @sock.wait_readable
              end
            rescue Celluloid::TaskTimeout
              return false
            rescue ArgumentError # IO Selector Exception
              return true
            end
            false
          end
        end
      end

      it "frees up the socket when a timeout error occurs" do
        sleeping_actor_class.new(example_addr, example_port)
        a2 = foo_actor_class.new(example_addr, example_port)
      
        expect(a2.timedout_read(1)).to eq true # this ensures that the socket timed out trying to read
        expect(a2.failed_write).to eq false # this ensures that the socket is freed up and still usable
      end
    end
  end
end
