require 'spec_helper'

describe "Notifications" do

  let(:host) { 'http://localhost:7071' }
  # let(:host)      { 'http://echo-code.yyy.brain.3scale.net:10002' }

  let(:localhost) { 'http://localhost:10002' }

  def get_response_key(key)
    get_json("#{host}/echo", host: localhost)[key]
  end

  before(:each) do
    load_fixture('events',  'service_created')
    load_fixture('events',  'service_deleted')
    load_fixture('events',  'already_read_event')
    # load_fixture('events',  'service_created')
  end

  context 'when there are unread events' do

    it 'gets all via the index by default' do
      arr = get_json("#{host}/api/events")
      arr.size.should == 3
    end

    it 'gets read ones if asked' do
      arr = get_json("#{host}/api/events?read=1")
      arr.size.should == 1
    end

    it 'gets unread if read param is blank' do
      arr = get_json("#{host}/api/events?read=")
      arr.size.should == 2
    end


    # "smembers" "jor/events/idx/!/read/FalseClass/false"
    # "get" "jor/events/docs/2"
    # "get" "jor/events/docs/1"

    it 'gets just the unread vi index' do
      arr = get_json("#{host}/api/events", query: {query: {"read" =>  false}.to_json })
      arr.size.should be_eql(2)
    end

    xit 'processes them once'
  end

  context 'from a collector' do
    xit 'gets processed by all the observers'
  end

end
