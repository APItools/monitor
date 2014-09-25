require 'spec_helper'

describe "Traces" do

  let(:host) { 'http://localhost:7071' }

  def get_traces(path, **options)
    response = get_json("#{host}#{path}", **options)
    sans_created_at response
  end

  describe '/api/traces/last_id' do
    it 'returns the last existing id' do
      3.times { load_fixture('traces', 'simple', true) }
      get_traces("/api/traces/last_id").should == {"last_id" => 3}
    end
  end

  describe '/api/services/:service_id/traces' do

    it 'returns traces of one service' do
      load_fixture('traces', 'simple', true)
      trace = load_fixture('traces', 'service_two', true)
      response = do_get('/api/services/2/traces/search')
      json = [trace].to_json

      expect(response.status).to eq(200)
      expect(response.body).to be_json_eql(json)
    end

    it 'has working count' do
      load_fixture('traces', 'service_two', true)
      response = do_get('/api/services/2/traces/count')

      expect(response.status).to eq(200)
      expect(response.body).to be_json_eql('{"document_count": 1}')
    end
  end

  describe '/api/traces' do

    describe 'whithout parameters' do
      it 'returns an empty json' do
        get_traces("/api/traces").should be_empty
      end
    end

    describe 'with a last_id param' do
      it 'returns a json with the traces where id > than last_id' do
        all_traces = 3.times.map { load_fixture('traces', 'simple', true) }
        get_traces("/api/traces", query: {last_id: 0}).should == sans_created_at(all_traces)
      end
    end

  end

  describe '/api/traces/:id' do
    it 'gets an existing trace' do
      trace = load_fixture('traces', 'simple', true)
      get_traces("/api/traces/#{trace['_id']}").should == sans_created_at(trace)
    end

    describe 'when deleting' do
      it 'deletes an existing trace' do
        trace = load_fixture('traces', 'simple', true)
        delete("#{host}/api/traces/#{trace['_id']}").content.should be_empty
      end
      it 'deletes all pointing to /all' do
        load_fixture('traces', 'simple', true)
        load_fixture('traces', 'simple', true)
        delete("#{host}/api/traces/all").content.should be_empty
      end

      it 'errors on inexisting traces' do
        json = JSON.parse(delete("#{host}/api/traces/0", :status => 404).content)
        json['error'].should == 'trace not found'
      end
    end
  end

  describe '/api/traces/search' do
    it 'searches an existing trace by id' do
      trace = load_fixture('traces', 'simple', true)
      q = {"_id" => 1}.to_json
      get_traces("/api/traces/search", query: { "query" => q }).should include sans_created_at(trace)
    end

    it 'does not find inexising races' do
      load_fixture('traces', 'simple', true)
      q = {_id: 0}.to_json
      get_traces("/api/traces/search", query: { "query" => q }).should be_empty
    end

    it 'handles malformed json' do
      q = "{{{{"
      get_traces("/api/traces/search", query: { "query" => q }, status: 400)['error'].should == "Malformed JSON: {{{{"
    end
  end

  describe '/api/traces/:id/star' do
    it "persists an existing trace" do
      trace = load_fixture('traces', 'simple', true)
      trace['starred'] = true
      json = trace.to_json
      post("#{host}/api/traces/#{trace['_id']}/star").content.should be_json_eql(json).excluding('_updated_at')
    end

    it "throws error on inexisting request" do
      response = post("#{host}/api/traces/0/star", status: 404)
      error = { error: 'trace not found' }
      expect(response.content).to be_json_eql(error.to_json).excluding('traceback')
    end

    it 'deletes a star from trace' do
      trace = load_fixture('traces', 'starred', true)
      trace['starred'] = false
      json = trace.to_json

      response = delete("#{host}/api/traces/#{trace['_id']}/star")
      expect(response.content).to be_json_eql(json).excluding('_updated_at')
    end
  end

  describe '/api/traces/saved' do
    it "is empty when no traces are persisted" do
      3.times { load_fixture('traces', 'simple', true) }
      get_traces("/api/traces/saved").should == []
    end

    it "returns persisted traces only" do
      trace = load_fixture('traces', 'simple', true)
      3.times { load_fixture('traces', 'simple', true) }

      post("#{host}/api/traces/#{trace['_id']}/star")
      starred = sans_created_at(trace)
      starred['starred'] = true
      get_traces("/api/traces/saved").should == [starred]
    end
  end

  describe '/api/traces/count' do
    it 'counts using $gt by default and filtering via query' do
      trace = load_fixture('traces', 'simple' , true) #status == 200
      id = trace['_id']
      trace = load_fixture('traces', 'fiveohoh' , true) #status == 500
      3.times{ load_fixture('traces', 'simple' , true) }
      get_traces("/api/traces/count", query: { 'query' => {"response" =>  {"status" => 200}}.to_json, 'last_id' =>  id }).should == {'document_count' => 3}
    end
  end

  describe 'expiring traces' do
    it 'keeps just latest 1000 counting starred ones' do
      trace = load_fixture('traces', 'simple', true)
      post("#{host}/api/traces/#{trace['_id']}/star")
      1000.times{|b| load_fixture('traces', 'simple' , true) }
      trace = load_fixture('traces', 'simple', true)
      trace = load_fixture('traces', 'simple', true)
      post("#{host}/api/traces/#{trace['_id']}/star")
      run_cron
      get_traces("/api/traces/count", query: {}).should == {'document_count' => 1000}
    end

  end


end
