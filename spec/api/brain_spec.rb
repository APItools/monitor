require 'spec_helper'

describe "Brain" do

  let(:host)     { "http://localhost:7071" }

  describe "POST /api/brain/register" do
    it "registers into the brain with the uuid" do
      expect(post_json("#{host}/api/brain/register")).to be
    end
  end

  describe "POST /api/brain/link" do
    it "registers into the brain with the uuid" do
      expect(post_json("#{host}/api/brain/link", body: {key: 'a key'}.to_json)).to be
      expect(post_json("#{host}/api/config", body: "{}")).to include('link_key' => 'a key')
    end
  end

  describe "POST /api/brain/unlink" do
    it "registers into the brain with the uuid" do
      expect(post_json("#{host}/api/brain/register")).to be
    end
  end

end
