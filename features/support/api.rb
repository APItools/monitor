require 'httpclient'

class API
  @@client = HTTPClient.new

  def get(path)
    @@client.get(uri(path))
  end

  def post(path)
    @@client.post(uri(path))
  end

  def wait_for(&block)
    Timeout.timeout(Capybara.default_wait_time) do
      loop do
        break if block.call
      end
    end
  end

  def uri(path)
    URI.parse(Capybara.app_host).merge('/api/').merge(path)
  end

  module Helper
    def api
      API.new
    end
  end
end

World(API::Helper)
