require "spec_helper"

RSpec.describe Celluloid::IO::Reactor, library: :IO do
  let(:payload) { "balls" }
  let(:example_port) { assign_port }

  it "shouldn't crash" do
    server = ::TCPServer.new example_addr, example_port

    thread = Thread.new { server.accept }

    socket = within_io_actor { Celluloid::IO::TCPSocket.new example_addr, example_port }
    peer = thread.value
    Thread.new { loop { peer << payload } }
    handle = false

    # Main server body:
    within_io_actor do
      begin
        deadline = Time.now + 2
        loop do
          socket.readpartial(2046)
          break if Time.now > deadline
        end
      rescue Celluloid::TaskTerminated, Celluloid::TaskTimeout
      ensure
        socket.readpartial(2046)
        handle = true
      end
    end

    expect(handle).to be_truthy
  ensure
    [server, peer, socket].each { |s| s.close rescue nil }
  end
end
