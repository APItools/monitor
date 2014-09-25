require 'spec_helper'

describe "Middleware" do

  let(:host) { 'http://localhost:7071' }

  describe "getting middleware by uuid" do
    let(:pipeline) { load_fixture('pipelines', 'upcase_pipeline', false) }

    it 'gets the right middleware' do
      middleware = pipeline['middlewares']['upcase-body']
      response = do_get('/api/middlewares/'+middleware['uuid'])

      expect(response.code).to eq(200)
      expect(response.body).to be_json_eql(middleware.to_json)
    end

    it 'returns not-found when it could not be found' do
      response = do_get('/api/middlewares/brainslug')
      expect(response.code).to eq(404)
    end
  end
end
