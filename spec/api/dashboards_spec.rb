require 'spec_helper'

describe "Dashboard" do
  let(:host)     { "http://localhost:7071" }
  let!(:twitter)  { sans_created_at load_fixture('services', 'twitter', true) }
  let!(:empty)  { sans_created_at load_fixture('dashboards', 'empty_dashboard', true) }
  let!(:complex)  { sans_created_at load_fixture('dashboards', 'complex_dashboard', true) }

  it 'indexes all dashboards of a given service' do
    dashboards = get_json("#{host}/api/services/#{empty['service_id']}/dashboards/")
    dashboards.size.should == 2
  end

  it 'shows a dashboard' do
    dashboard = get_json("#{host}/api/services/#{empty['service_id']}/dashboards/#{empty['_id']}")
    dashboard["graphs"]["0"]["name"].should == "empty"
  end

  it 'modifies a dashboard' do
    attributes = {"graphs" =>  {"0" => {"name" => "updated"}}}
    post_json("#{host}/api/services/#{empty['service_id']}/dashboards/#{empty['_id']}",
              body: attributes.to_json).should include attributes
    dashboard = get_json("#{host}/api/services/#{empty['service_id']}/dashboards/#{empty['_id']}")
    dashboard["graphs"]["0"]["name"].should == "updated"
  end

  it 'errs on updating not existing dashboard' do
    attributes = {"graphs" =>  {"0" => {"name" => "updated"}}}
    post_json("#{host}/api/services/#{empty['service_id']}/dashboards/0",
              status: 404, body: attributes.to_json)

  end

  it 'destroys a dashboard' do
    get_json("#{host}/api/services/#{empty['service_id']}/dashboards/").size.should == 2
    do_delete("/api/services/#{empty['service_id']}/dashboards/#{empty['_id']}")
    get_json("#{host}/api/services/#{empty['service_id']}/dashboards/").size.should == 1
  end

  context "created dashboard" do
    let(:service_id) { empty['service_id'] }
    let(:response) { do_post("/api/services/#{service_id}/dashboards/", dashboard) }
    let(:dashboard) { {name: 'my dash' } }

    it "has proper service_id" do
      json = dashboard.merge(service_id: service_id).to_json

      expect(response.content).to be_json_eql(json).excluding('_id', '_created_at', '_updated_at')
    end
  end
end
