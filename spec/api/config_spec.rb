require 'spec_helper'

describe "Config" do

  let(:host)     { "http://localhost:7071" }
  let!(:simple_config)     { load_fixture('config', 'simple') }

  describe "GET /api/config/" do
    it "returns the whole config" do
      get_json("#{host}/api/config").to_json.should be_json_eql(simple_config.to_json)
    end
  end

  describe "POST /api/config/" do
    it "partial update and returns whole config" do
      attributes = {'name' => 'Mufasa'}
      new_config = {'oauth_access_token' =>  "123", "name" =>  "Mufasa"}
      post_json("#{host}/api/config", body: attributes.to_json).should include(new_config)
    end

    it "can't update slug_name" do
      attributes = {'slug_name' => 'key-key'}
      new_config = {'oauth_access_token' =>  "123", "name" =>  "simba"} # original
      res = post_json("#{host}/api/config", body: attributes.to_json)

      res.should include(new_config)
      res.should_not include(attributes)
    end
  end

  describe "GET /api/get_slug_name" do
    it "gets slug_name" do
      attributes = {'slug_name' => 'key-key'}
      post_json("#{host}/api/set_slug_name", body: attributes.to_json)
      res = get_json("#{host}/api/get_slug_name")
      res['slug_name'].should be_eql('key-key')
    end
  end

  describe "POST /api/set_slug_name" do
    it "updates slug_name" do
      attributes = {'slug_name' => 'key-key'}
      new_config = {'oauth_access_token' =>  "123", "name" =>  "simba"}
      res = post_json("#{host}/api/set_slug_name", body: attributes.to_json)

      res.should include(new_config)
      res.should include(attributes)
    end
  end

end
