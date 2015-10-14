require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class ServerTest < JOR::Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    JOR::Server.new
  end

  def setup
    super
    @jor = JOR::Storage.new(Redis.new(:db => 9, :driver => :hiredis))
    @jor.create_collection("test")
  end

  def teardown
    @jor.redis.flushdb() if @safe_to_remove
  end

  def test_calling_methods

    put '/last_id'
    assert_equal 422, last_response.status
    assert_equal "Collection \"last_id\" does not exist", JSON::parse(last_response.body)["error"]

    put '/test.last_id'
    assert_equal 200, last_response.status
    assert_equal 0, JSON::parse(last_response.body)["value"]

    put '/test.last_id'
    assert_equal 200, last_response.status
    assert_equal 0, JSON::parse(last_response.body)["value"]

    doc1 = create_sample_doc_restaurant({"_id" => 1})

    put '/test.insert', [doc1].to_json
    assert_equal 200, last_response.status

    doc2 = create_sample_doc_restaurant({"_id" => 2})
    put '/test.insert', [doc2].to_json
    assert_equal 200, last_response.status

    docs = [create_sample_doc_restaurant({"_id" => 3}), create_sample_doc_restaurant({"_id" => 4})]
    put '/test.insert', [docs].to_json
    assert_equal 200, last_response.status

    put '/test.find', [{"_id" => 4}].to_json
    assert_equal 200, last_response.status
    results = JSON::parse(last_response.body)
    assert_equal 1, results.size

    put '/test.find', [{}].to_json
    assert_equal 200, last_response.status
    results = JSON::parse(last_response.body)
    assert_equal 4, results.size
    4.times do |i|
      assert_equal i+1, results[i]["_id"]
    end

    put '/test.find', [{}, {"reversed" => true}].to_json
    assert_equal 200, last_response.status
    results = JSON::parse(last_response.body)
    assert_equal 4, results.size
    4.times do |i|
      assert_equal 4-i, results[i]["_id"]
    end

    put '/test.find', [{},{"reversed" => true}].to_json
    assert_equal 200, last_response.status
    results = JSON::parse(last_response.body)
    assert_equal 4, results.size
    4.times do |i|
      assert_equal 4-i, results[i]["_id"]
    end

    put '/test.find', [{"fake" => "super_fake"}].to_json
    assert_equal 200, last_response.status
    results = JSON::parse(last_response.body)
    assert_equal 0, results.size

  end

  def test_create_collection
    put '/create_collection', ["with_autoincrement", {:auto_increment => true}].to_json
    assert_equal 200, last_response.status

    put '/create_collection', ["without_autoincrement", {:auto_increment => false}].to_json
    assert_equal 200, last_response.status

    put '/collections', [].to_json
    assert_equal 200, last_response.status
    results = JSON::parse(last_response.body)

    assert_equal ["with_autoincrement", "without_autoincrement", "test"].sort, results.sort

    put '/with_autoincrement.insert', [{"foo" => "bar"}].to_json
    assert_equal 200, last_response.status

    put '/with_autoincrement.insert', [{"_id" => 42, "foo" => "bar"}].to_json
    assert_equal 422, last_response.status
    results = JSON::parse(last_response.body)
    assert_equal JOR::DocumentDoesNotNeedId.new("with_autoincrement").to_s, results["error"]

    put '/without_autoincrement.insert', [{"foo" => "bar"}].to_json
    assert_equal 422, last_response.status
    results = JSON::parse(last_response.body)
    assert_equal JOR::DocumentNeedsId.new("without_autoincrement").to_s, results["error"]

    put '/without_autoincrement.insert', [{"_id" => 42, "foo" => "bar"}].to_json
    assert_equal 200, last_response.status
  end

  def test_is_not_put
    post '/create_collection', ["with_autoincrement", {:auto_increment => true}].to_json
    assert_equal 422, last_response.status
  end

end
