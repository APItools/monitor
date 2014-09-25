require 'spec_helper'

describe "Analytics" do

  let(:host) { 'http://localhost:7071' }

  describe '/api/stats/metrics' do

    it 'returns an empty array when there are no metrics' do
      get_json("#{host}/api/stats/metrics").should == []
    end

    it 'returns the different metrics once there are some' do
      pending "this test should wait for crontab, but it does not work"
      load_fixture('services',  'echo_service', true)
      load_fixture('pipelines', 'echo_pipeline', true)
      localhost = 'http://localhost:10002'
      echo_host = 'http://echo-code-yyy.conrad.pre.3scale.net:10002'

      get_json("#{echo_host}/echo", host: localhost) # this should make brainslug use the collector with hits, time and status

      run_cron

      # this should return true, but it returns [] :(
      get_json("#{host}/api/stats/metrics").should == [
        {'name' => 'hits',   'type' => 'count', 'desc' => 'hits'},
        {'name' => 'status', 'type' => 'count', 'desc' => 'status'},
        {'name' => 'time',   'type' => 'set',   'desc' => 'time'}
      ]
    end
  end

  describe '/api/services/{service_id}/stats/analytics' do

    it 'returns data for one service' do
      echo_service = load_fixture('services', 'echo_service', true)

      range      = { 'start' => 1372157100, 'end' => 1372160820, 'granularity' => 60}
      query      = { 'range' => range,
                     'metrics' => %w|* * time|,
                     'projections' => ['avg'],
                     'metric' => 'time',
                     'group_by' => [false, false, false] }

      response = get_content("#{host}/api/services/#{echo_service['_id']}/stats/analytics", query: {'query' => query.to_json})

      normalized_query = {
          "range"=>{
              "granularity"=>604800, # granularity is forced to "week" because of metric compacting
              "start"=>1371686400,
              "end"=>1372291200
          },
          "metric"=>"time",
          "group_by"=>[false, false, false],
          "projections"=>["avg"],
          "metrics"=>["*", "*", "time"]
      }

      expect(response).to be_json_eql(normalized_query.to_json).at_path('normalized_query')
    end
  end

  describe '/api/stats/analytics' do

    it 'returns data for all services' do
      range      = { 'start' => 1372157100, 'end' => 1372160820, 'granularity' => 60}
      query      = { 'range' => range,
                     'metrics' => %w|* * time|,
                     'projections' => ['avg'],
                     'metric' => 'time',
                     'group_by' => [false, false, false] }

      response = get_content("#{host}/api/stats/analytics", query: {'query' => query.to_json})

      normalized_query = { "range"=>{
          "granularity"=>604800, # granularity is forced to "week" because of metric compacting
          "start"=>1371686400,
          "end"=>1372291200
        },
        "metric"=>"time",
        "group_by"=>[false, false, false],
        "projections"=>["avg"],
        "metrics"=>["*", "*", "time"]
      }

      expect(response).to be_json_eql(normalized_query.to_json).at_path('normalized_query')
    end
  end
end
