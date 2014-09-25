

namespace :sample do
  require 'httpclient'

  APP_HOST          = ENV['HOST']        || 'localhost:7071'
  PROXY_HOST        = ENV['HOST']        || 'localhost:10002'
  PROXY_HOST_HEADER = ENV['HOST_HEADER'] || 'echo-xxxx.conrad.pre.3scale.net'
  SAMPLES     = [
    { method: :get,  path: '/v1/word/hello.json',     query: 'app_id=111&app_key=222' },
    { method: :get,  path: '/v1/word/fantastic.json', query: 'app_id=111&app_key=222' },
    { method: :get,  path: '/v1/word/awesome.json',   query: 'app_id=111&app_key=222' },

    { method: :post, path: '/v1/word/dry.json',       query: 'value=2&app_id=111&app_key=222' },
    { method: :post, path: '/v1/word/foo.json',       query: 'value=2&app_id=111&app_key=222' },

    { method: :get,  path: '/v1/sentence/the%20fox%20runs%20wild.json',  query: 'app_id=111&app_key=222' },
    { method: :get,  path: '/v1/sentence/the%20fox%20runs%20wild.json',  query: 'app_id=111&app_key=222' },
    { method: :get,  path: '/v1/sentence/this%20is%20really%20bad.json', query: 'app_id=111&app_key=222' }
  ]

  @client = HTTPClient.new

  def curl(method, host, path, query, headers = {})
    host = URI.parse("http://" + host)
    path = URI.join(host, path)

    response = @client.send(method, path, query, headers)

    unless successful?(response)
      puts "request #{path} failed with code #{response.code}"
    end

    response
  end

  def successful?(response)
    HTTP::Status.successful?(response.status)
  end

  def run_samples
    SAMPLES.map{ |s| curl(s[:method].to_s.downcase, PROXY_HOST, s[:path], s[:query], {'Host' => PROXY_HOST_HEADER}) }
  end

  def wait_seconds
    wait = ENV['WAIT']
    wait ? wait.to_f : rand(1...10)
  end

  desc "Run sample"
  task :once do
    exit run_samples.all?{|sample| successful?(sample) }
  end

  desc "Run sample loop"
  task :loop do
    while true do
      run_samples

      seconds = wait_seconds

      puts "Sleeping for #{seconds} seconds"
      sleep seconds
    end
  end

  desc "Call demo calls in loop like SERVICE=4 URL=/zen (for github service)"
  task :call do
    service = ENV['SERVICE']
    url  = ENV['URL']

    while true do
      curl(:get, APP_HOST, "/api/services/#{service}/call", "url=#{url}")
      print '.'
      sleep(wait_seconds)
    end
  end

  desc "Prepare the echo service for running the samples"
  task :prepare do
    curl(:post, 'localhost:7071', '/api/services/', "{'name': 'echo', 'description': 'demo service', 'endpoints': [{'url': 'http://localhost:8081', 'code': 'echo'}]}")
  end
end

task :sample => 'sample:once'
