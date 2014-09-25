require "spec_helper"

describe "Event" do

  let(:host)      { 'http://localhost:7071' }
  let(:service_created_event) { {
      "channel" => "syslog",
      "level" => "info",
      "msg" => "service created",
      "_id" => 1
    }
  }

  let(:service_deleted_event) { {
      "channel" => "syslog",
      "level" => "info",
      "msg" => "service deleted",
      "_id" => 2
    }
  }


  before(:each) do
    load_fixture('events', 'service_created')
    load_fixture('events', 'service_deleted')
  end

  describe 'GET /api/events' do

    it 'gets a list of all events' do
      arr = get_json("#{host}/api/events")

      arr.size.should eq(2)
      arr[0].should include(service_created_event)
      arr[1].should include(service_deleted_event)
    end

    it 'gets a list of all events' do
      arr = get_json("#{host}/api/events?reversed=1", )

      arr.size.should eq(2)
      arr[1].should include(service_created_event)
      arr[0].should include(service_deleted_event)
    end



    it 'gets a list of some if we pass query on querystring' do
      q = {"_id" => 1}.to_json
      arr = get_json("#{host}/api/events" , query: {query: q} )
      arr.size.should eq(1)
      arr[0].should include(service_created_event)
    end

    it 'uses per_page parameter if passed' do
      arr = get_json("#{host}/api/events?per_page=1")

      arr.size.should eq(1)
      arr[0].should include(service_created_event)
    end

    it 'uses page parameter if passed. 1 is the first' do
      arr = get_json("#{host}/api/events?per_page=1&page=1")

      arr.size.should eq(1)
      arr[0].should include(service_created_event)
    end

    it 'uses page parameter if passed. 0 counts also the first' do
      arr = get_json("#{host}/api/events?per_page=1&page=0")

      arr.size.should eq(1)
      arr[0].should include(service_created_event)
    end

  end

  describe 'GET /api/events/:id' do
    it 'gets an event by id' do
      ev = get_json("#{host}/api/events/1")
      ev.should include(service_created_event)
      ev.should_not include({"_id" =>  2})
    end
  end

end
