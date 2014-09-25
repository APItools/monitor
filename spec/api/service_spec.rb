require 'spec_helper'

describe "Service" do
  before(:each) { system_reset() }

  describe 'crud' do

    let(:host)     { "http://localhost:7071" }
    let!(:twitter)  { sans_created_at load_fixture('services', 'twitter', true) }
    let!(:facebook) { sans_created_at load_fixture('services', 'facebook', true) }

    describe "/api/services/:id" do
      it "returns a service given its id" do
        get_json("#{host}/api/services/#{twitter['_id']}").should include twitter
      end
    end

    describe "/api/services" do
      it "returns all services" do
        list = get_json("#{host}/api/services")

        list.should be_a Array
        list.first.should include twitter
        list.last.should include facebook
      end
    end

    describe "POST /api/services" do

      it "creates a new service" do
        attributes = {'name' => 'paypal', 'description' => 'the paypal api', 'endpoints' => [{'url' => 'http://localhost:8081', 'code' => 'foooo'}]}
        post_json("#{host}/api/services", status: 201, body: attributes.to_json).should include attributes
      end

      it 'can create service with code containing dashes' do
        attributes = {'name' => 'paypal', 'description' => 'the paypal api',
          'endpoints' => [{'url' => 'http://localhost:8081', 'code' => 'foooo-y-tal'}]}
        post_json("#{host}/api/services", status: 201, body: attributes.to_json)
      end

      it 'generates an event for the service creation and for the pipeline' do
        attributes = {'name' => 'paypal', 'description' => 'the paypal api', 'endpoints' => [{'url' => 'http://localhost:8081', 'code' => 'foooo'}]}
        post_json("#{host}/api/services", status: 201, body: attributes.to_json).should include attributes
        q = {"_id" => 1}.to_json
        get_json("#{host}/api/events", query: {query: q} )
      end
    end

    describe "POST /api/services/:id" do
      it "updates an existing service" do
        attributes = {'name' => 'new facebook'}
        post_json("#{host}/api/services/#{facebook['_id']}", body: attributes.to_json).should include attributes
      end

      it "updates with correct endpoints" do
        attributes = {'name' => 'new facebook', 'endpoints' => [{'url' => 'http://localhost:8081', 'code' => 'foooo'}]}
        post_json("#{host}/api/services/#{facebook['_id']}", body: attributes.to_json).should include attributes
    end

      it "doesn't update with incorrect endpoints" do
        attributes = {'name' => 'new facebook', 'endpoints' => [{'url' => 'http://localhost:8081', 'code' => 'f-ooo_o'}]}
        error_msg = { 'msg' => 'Invalid Service attributes'}
        post_json("#{host}/api/services/#{facebook['_id']}", body: attributes.to_json, status: 422).should include error_msg
      end
    end
  end

  describe 'shared space' do

    let(:host)     { "http://localhost:7071" }

    describe "/api/services/:id/echo" do
      let(:api_host)      { 'http://echo-code-yyy.conrad.pre.3scale.net:10002' }
      let(:localhost)          { 'http://localhost:10002' }
      let!(:echo_service) { load_fixture('services',  'echo_service') }
      let(:service_id) { echo_service['_id'] }

      it 'keeps the state from one call to another in middleware bucket' do
        load_fixture('pipelines', 'keep_state_middleware', true)

        get_content("#{api_host}/echo", host: localhost, status: 200)
        get_content("#{api_host}/echo", host: localhost, status: 201)
      end

      it 'makes different buckets for different middlewares' do
        load_fixture('pipelines', 'isolated_middlewares')

        get_content("#{api_host}/echo", host: localhost, status: 200)
      end

      it 'keeps state from one mw to another via the service_bucket' do
        load_fixture('pipelines', 'keep_state_service')

        get_content("#{api_host}/echo", host: localhost, status: 201)
      end
    end

    describe 'DELETE /api/services/:id/' do
      let!(:echo_service) { load_fixture('services',  'echo_service', true) }
      let!(:twitter)      { sans_created_at load_fixture('services', 'twitter') }
      let(:api_host)      { 'http://echo-code-yyy.conrad.pre.3scale.net:10002' }
      let(:host)     { "http://localhost:7071" }

      it 'deletes the service' do
        delete("#{host}/api/services/#{twitter['_id']}")
        list = get_json("#{host}/api/services")
        list.size.should be_equal(1)
      end

      it 'deletes the pipeline associated to service' do

        attributes = {'name' => 'paypal', 'description' => 'the paypal api', 'endpoints' => [{'url' => 'http://localhost:8081', 'code' => 'foooo'}]}
        res = post_json("#{host}/api/services", status: 201, body: attributes.to_json)
        res.should include attributes

        delete("#{host}/api/services/#{res['_id']}")
        list = get_json("#{host}/api/services")
        get_json("#{host}/api/services/#{res['_id']}/pipeline", status: 404)
      end


    end

  end

  describe 'sandboxing' do

    let!(:echo_service)    { load_fixture('services',  'echo_service') }
    let(:api_host)         { 'http://echo-code-yyy.conrad.pre.3scale.net:10002' }
    let(:localhost)        { 'http://localhost:10002' }
    let(:api) { 'http://localhost:7071' }


    describe 'unsafe' do
      let!(:unsafe_pipeline) { load_fixture('pipelines', 'unsafe_middleware') }
      it 'stops the middlewares from touching unsafe stuff' do
        get_content("#{api_host}/echo", host: localhost, status: 500)
      end
    end

    describe 'sha256' do
      let!(:sandbox_sha_pipeline) { load_fixture('pipelines', 'sandbox_sha_pipeline') }
      it 'can access sha256 function' do
        get_content("#{api_host}/echo", host: localhost)
      end
    end

    describe 'http' do
      let!(:sandbox_sha_pipeline) { load_fixture('pipelines', 'http_client_pipeline') }
      it 'adds user-agent=Apitools' do
        response = get_content("#{api_host}/echo", host: localhost)
        expect(response).to be_json_eql('"APITools"').at_path('headers/user-agent')
      end
    end

    describe 'time' do
      let!(:sandbox_time_pipeline) { load_fixture('pipelines', 'sandbox_time_pipeline') }
      it 'can access time function' do
        get_content("#{api_host}/echo", host: localhost)
      end
    end

    describe 'xml' do
      let!(:sandbox_xml_pipeline) { load_fixture('pipelines', 'sandbox_xml_pipeline') }
      it 'can access the xml lib' do
        get_content("#{api_host}/echo", host: localhost)
      end
    end

    describe 'json' do
      let!(:sandbox_xml_pipeline) { load_fixture('pipelines', 'sandbox_json_pipeline') }
      it 'can access json module' do
        get_content("#{api_host}/echo", host: localhost)
      end
    end

    describe 'console' do
      it 'can access the console module, and it works as expected' do
        pipeline = load_fixture('pipelines', 'console_pipeline')
        mw_uuid = pipeline['middlewares']['console']['uuid']
        get_content("#{api_host}/echo", host: localhost)
        response = get_json("#{api}/api/services/#{echo_service['_id']}/console/#{mw_uuid}")
        response = sans_created_at(response)
        expect(response).to eq([
          {"level"=>"error", "msg"=>'an error', "_id"=>2},
          {"level"=>"log",   "msg"=>'a log', "_id"=>1}
        ])
      end
    end

    describe 'infinite loop' do
      # FIXME: we can't execute this without making the middlewares run as coroutines (see pipeline.lua)
      xit 'detects and prevents infinite loops by timeboxing the request execution' do
        load_fixture('pipelines', 'infinite_loop_pipeline')
        get_content("#{api_host}/echo", host: localhost, status: 500)
      end
    end
  end


end
