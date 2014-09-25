require 'spec_helper'

describe "echo" do

  let(:host)      { 'http://echo-code-yyy.conrad.pre.3scale.net:10002' }
  let(:localhost) { 'http://localhost:10002' }

  def get_response_key(key)
    get_json("#{host}/echo", host: localhost)
  end

  before(:each) do
    load_fixture('services',  'echo_service')
  end

  let(:make_echo_call) { get_json("#{host}/echo", host: localhost) }

  it 'fires an event from a middleware' do
    load_fixture('pipelines', 'fire_event_pipeline')
    jor.create_collection("events", {auto_increment: true})

    make_echo_call

    events = jor.events.find(msg: 'we triggered this')
    expect(events.first).to include('channel' => 'syslog', 'level' => 'info')
  end

  it 'can access the trace' do
    load_fixture('pipelines', 'access_trace_pipeline')
    jor.create_collection("events", {auto_increment: true})

    make_echo_call

    events = jor.events.find(msg: 'we triggered this')
    expect(events.first).to have_key('data')
    expect(events.first['data']).to have_key('trace')
  end

  it 'can access the trace' do
    load_fixture('pipelines', 'modify_and_access_trace_pipeline')
    jor.create_collection("events", {auto_increment: true})

    make_echo_call

    events = jor.events.find(msg: 'trace was modified')
    expect(events.first).to have_key('data')
  end

  # FIXME: for the moment we can't make state persistent in middlewares.
  it 'can has private state via a closure' do
    pending("for the moment we can't make state persistent in middlewares.")
    load_fixture('pipelines', 'internal_state_pipeline')
    jor.create_collection("events", {auto_increment: true})
    old_events = jor.events.count
    a = get_json("#{host}/echo", host: localhost)
    b = get_json("#{host}/echo", status: 403, host: localhost)
  end
end
