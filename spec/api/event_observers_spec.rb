require 'spec_helper'

describe "EventObserver" do

  let(:host) { 'http://localhost:7071' }

  def get_observers(path, **options)
    response = get_json("#{host}#{path}", **options)
    sans_created_at response
  end

  describe '/api/event_observers' do
    it 'is empty by default' do
      get_observers("/api/event_observers").should be_empty
    end
    it 'displays existing observers' do
      obs = 3.times.map { load_fixture('event_observers', 'simple', true) }
      get_observers("/api/event_observers").should include(*sans_created_at(obs))
    end
  end

  describe '/api/event_observers/:id' do
    it 'returns the observer with the id' do
      ob = load_fixture('event_observers', 'simple', true)
      get_observers("/api/event_observers/#{ob['_id']}").should include sans_created_at(ob)
    end
  end

  describe 'POST /api/event_observers/' do

    it 'creates a new observer with default name to timestamp' do
      attributes = {'condition' => 'foo', 'action' => 'bar', 'frequency' => 1}
      body = attributes.to_json
      post_json("#{host}/api/event_observers", status: 201, body: body).should include attributes
    end

    it 'does not create a new observer if the name already exists' do
      attributes = {'condition' => 'foo', 'action' => 'bar', 'name' => 'foo', 'frequency' => 1}
      body = attributes.to_json
      post_json("#{host}/api/event_observers", status: 201, body: body).should include attributes
    end

    it 'does not create a new observer if the name already exists' do
      attributes = {'condition' => 'foo', 'action' => 'bar', 'name' => 'foo', 'frequency' => 1}
      body = attributes.to_json
      post_json("#{host}/api/event_observers", status: 201, body: body).should include attributes
      attributes = {'condition' => 'foo', 'action' => 'bar', 'name' => 'foo', 'frequency' => 1}
      post_json("#{host}/api/event_observers", status: 403, body: body)
    end

  end

  describe 'POST /api/event_observers/:id' do
    it 'updates an existing observer' do
      ob = load_fixture('event_observers', 'simple', true)
      body = {'condition' => 'foo'}.to_json
      post_json("#{host}/api/event_observers/#{ob['_id']}", body: body).should include({'condition' => 'foo'})
    end
  end

  describe 'DELETE /api/event_observers/:id' do
    it 'removes an existing observer' do
      ob = load_fixture('event_observers', 'simple', true)
      delete("#{host}/api/event_observers/#{ob['_id']}").content.should be_empty
      get_observers("/api/event_observers/#{ob['_id']}", status: 404)['error'].should == 'event_observer not found'
    end
  end


end
