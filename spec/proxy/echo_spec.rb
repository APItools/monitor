require 'spec_helper'

describe "echo" do

  let(:host)  { 'http://echo-code-yyy.conrad.pre.3scale.net:10002' }
  let(:proxy) { 'http://localhost:10002' }
  let(:api)   { 'http://localhost:7071' }

  def get_response_key(key)
    get_json("#{host}/echo", host: proxy)[key]
  end

  let(:service) { load_fixture('services',  'echo_service') }
  before(:each) { service }

  it 'returns the request as a query string when using the echo pipeline' do
    load_fixture('pipelines', 'empty_pipeline')

    get_response_key('path').should eq("/echo")
  end

  it 'uses a minimal middleware that does nothing' do
    load_fixture('pipelines', 'echo_pipeline')

    get_response_key('path').should eq("/echo")
  end

  it 'uses a minimal middleware that does nothing. different url' do
    load_fixture('pipelines', 'echo_pipeline')
    get_json("#{host}/ech", host: proxy)['path'].should eq("/ech")
  end

  it 'uses a minimal middleware that does nothing. spaces in url ' do
    load_fixture('pipelines', 'echo_pipeline')
    get_json("#{host}/ech%20foo", host: proxy)['path'].should eq("/ech%20foo")
  end

  it 'returns the request as a query string when using the upcase pipeline' do
    load_fixture('pipelines', 'upcase_pipeline')

    get_response_key('PATH').should eq("/ECHO")
  end

  it 'executes the middlewares in the order marked by their positions' do
    load_fixture('pipelines', 'unordered_pipeline')

    get_response_key('PATH').should eq("/ECHO")
  end

  it 'can add header to requests' do
    load_fixture('pipelines', 'add_header_to_request_pipeline')

    get_response_key('headers')['foo'].should eq('bar')
  end

  it 'does not execute deactivated plugins' do
    load_fixture('pipelines', 'deactivated_pipeline')

    get_response_key('path').should eq("/echo")
  end

  it 'passes config parameters to the middleware' do
    load_fixture('pipelines', 'parametrized_pipeline')

    get_response_key('path').should eq("/hodor")
  end

  it 'passes body of PATCH' do
    load_fixture('pipelines', 'echo_pipeline')

    response = do_request(:patch, host + '/path', host: proxy, body: 'abc')
    expect(response.body).to include_json('"abc"').at_path('body')
  end

  it 'handles errors thrown from inside middlewares' do
    load_fixture('pipelines', 'error_pipeline')

    get_content("#{host}/echo", status: 500, host: proxy).should include('error thrown from error_pipeline')
  end

  it 'handles errors thrown while loading middlewares' do
    load_fixture('pipelines', 'loading_error_pipeline')

    get_content("#{host}/echo", status: 500, host: proxy).should include("error thrown from loading_error_pipeline")
  end

  it 'handles syntax errors on middlewares' do
    load_fixture('pipelines', 'syntax_error_pipeline')

    get_content("#{host}/echo", status: 500, host: proxy).should include("'<name>' expected near '('")
  end

  it 'thows an error when a middleware returns nil' do
    load_fixture('pipelines', 'return_nothing_pipeline')

    get_content("#{host}/echo", status: 500, host: proxy).should include("A middleware did not return a valid response")
  end

  it 'thows an error when a middleware *deep in the pipeline" returns nil' do
    load_fixture('pipelines', 'return_nothing_inside_pipeline')

    get_content("#{host}/echo", status: 500, host: proxy).should include("A middleware did not return a valid response")
  end

  it 'stores trace with endpoint hostname' do
    load_fixture('pipelines', 'echo_pipeline')

    get("#{host}/echo", host: proxy)
    jor.wait_for_async_locks
    last_trace_id = get_json('http://localhost:7071/api/traces/last_id')['last_id']
    last_trace = get_json("http://localhost:7071/api/traces/#{last_trace_id}")
    expect(last_trace).to include('endpoint' => '127.0.0.1:8081')
    expect(last_trace).to include('service_id' => service['_id'])
    expect(last_trace).to include('starred' => false)
  end

  it 'boolean headers are stringyfied before sending' do
    load_fixture('pipelines', 'add_bool_header_to_request_pipeline')
    get_response_key('headers')['foo'].should eq('true')
  end

  it "can replay traces" do
    load_fixture('pipelines', 'echo_pipeline')
    get("#{host}/echo", host: proxy)

    jor.wait_for_async_locks

    last_id = api_get('/api/traces/last_id')['last_id']

    api_post("/api/traces/#{last_id}/redo")
    jor.wait_for_async_locks

    redo_id = api_get('/api/traces/last_id')['last_id']

    expect(redo_id).to eq(last_id + 1)

    original = api_get("/api/traces/#{last_id}")
    copy = api_get("/api/traces/#{redo_id}")

    expect(copy['req'].to_json). # FIXME: it should not exclude the endpoint
        to be_json_eql(original['req'].to_json).excluding('endpoint')
  end

  it "handles redirects correctly, ignoring the port" do
    load_fixture('pipelines', 'echo_pipeline')
    client = HTTPClient.new

    uri = URI.parse('http://localhost:10002/redirect/')
    res = client.get(uri, header: { 'Host' => 'echo-code-yyy.conrad.3scale.net' })

    expect(res.status).to eq(303)
    expect(res.headers['Location']).to eq('http://echo-code-yyy.conrad.3scale.net/index')
  end
end
