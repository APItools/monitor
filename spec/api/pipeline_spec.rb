require 'spec_helper'

describe "Pipeline" do
  let(:host)       { 'http://localhost:7071' }
  let(:service)    { load_fixture('services', 'twitter', true) }
  let(:service_id) { service['_id'] } # should be 1

  describe('POST /api/services/:service_id/pipeline') do
    it 'Updates a pipeline' do
      pipeline   = load_fixture('pipelines', 'updated', true)

      response   = post_json("#{host}/api/services/#{service_id}/pipeline",
                             body: pipeline.to_json)

      pipeline['middlewares'].should == response['middlewares']
    end
  end

  describe '/api/services/:service_id/pipeline' do
    it 'returns a pipeline' do
      pipeline   = load_fixture('pipelines', 'original', true)

      response = get_json("#{host}/api/services/#{service_id}/pipeline")

      pipeline['middlewares'].should == response['middlewares']
    end
  end
end
