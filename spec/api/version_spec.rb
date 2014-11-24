require 'spec_helper'

describe "Version" do

  before { jor.create_collection('versions', auto_increment: true) }

  let(:host)        { 'http://localhost:7071' }
  let(:service)     { load_fixture('services', 'twitter', true) }
  let(:pipeline)    { load_fixture('pipelines', 'updated', true) }
  let(:version)     { jor.versions.find(:collection => 'pipelines', :object => {'_id' => pipeline_id}).first }
  let(:pipeline_id) { pipeline['_id'] }
  let(:service_id)  { service['_id'] }
  let(:version_id)  { version['_id'] }

  before(:each) do
    post_json("#{host}/api/services/#{service_id}/pipeline/", :body => pipeline.to_json)
  end

  describe '/api/versions' do
    it "returns all versions" do
      get_json("#{host}/api/versions").first['object'].should == version['object']
    end
  end

  describe '/api/versions/:id' do
    it "gets a version" do
      get_json("#{host}/api/versions/#{version_id}")['object'].should == version['object']
    end
  end

  describe 'DELETE /api/versions/:id' do
    it "destroys a version" do
      delete("#{host}/api/versions/#{version_id}").content.should be_empty
      get_json("#{host}/api/versions/#{version_id}", :status => 404)['error'].should == 'version not found'
    end
  end

  describe '/api/services/:service_id/pipeline/versions' do
    it "gets all the versions of a pipeline" do
      get_json("#{host}/api/services/#{service_id}/pipeline/versions").first['object'].should == version['object']
    end
  end
end
