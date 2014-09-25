require 'spec_helper'

describe "MiddlewareSpec" do

  let(:host) { 'http://localhost:7071' }

  def middleware_spec(name)
    load_fixture('middleware_specs', name)
  end

  let(:simple) { middleware_spec('simple') }
  let(:fancy) { middleware_spec('fancy') }

  describe "creating middleware specs" do
    let(:pipeline) { load_fixture('pipelines', 'minimal', true) }

    it 'creates a new middleware spec' do
      attributes = { name: 'sample spec', author: 'someone' }
      response = do_post('/api/middleware_specs', attributes)
      expect(response.status).to eq(201)
    end

    it 'updates middleware when middleware_id is passed' do

      uuid = pipeline['middlewares']['fake-uuid']['uuid']
      attrs = { name: 'spec', middleware_id: uuid }
      response = do_post('/api/middleware_specs', attrs)

      expect(response.status).to eq(201)
      spec = JSON.parse(response.content)

      response = do_get("/api/services/#{pipeline['service_id']}/pipeline")

      expect(response.status).to eq(200)

      pipeline = JSON.parse(response.content)
      middleware = pipeline['middlewares']['fake-uuid']

      expect(middleware['spec_id']).to eq(spec['_id'])
    end
  end

  describe "deleting middleware specs" do
    it 'deletes the middleware spec' do
      id = simple['_id']
      response = do_delete("/api/middleware_specs/#{id}")
      expect(response.status).to eq(200)
    end
  end

  describe "get middleware spec" do
    it 'returns one middleware spec by id' do
      response = do_get("/api/middleware_specs/#{simple['_id']}")
      expect(response.status).to eq(200)
      expect(response.content).to eq(simple.to_json)
    end
  end

  describe "update middleware spec" do
    it 'updates middleware spec by id' do
      response = do_post("/api/middleware_specs/#{simple['_id']}", name: 'fancy')
      expect(response.status).to eq(200)
      updated = simple.merge(name: 'fancy')
      expect(response.content).to be_json_eql(updated.to_json).excluding('_updated_at')
    end
  end


end
