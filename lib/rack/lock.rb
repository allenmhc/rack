require 'thread'
require 'rack/body_proxy'

module Rack
  # Rack::Lock locks every request inside a mutex, so that every request
  # will effectively be executed synchronously.
  class Lock
    FLAG = 'rack.multithread'.freeze

    def initialize(app, mutex = Mutex.new)
      @app, @mutex = app, mutex
    end

    def call(env)
      old, env[FLAG] = env[FLAG], false
      @mutex.lock
      unlock = Fiber.new do
        Fiber.yield @mutex.unlock
        Fiber.yield @mutex while true
      end
      response = @app.call(env)
      body = BodyProxy.new(response[2]) { unlock.resume }
      response[2] = body
      response
    ensure
      unlock.resume unless body
      env[FLAG] = old
    end
  end
end
