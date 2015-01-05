require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class CollectionTest < JOR::Test::Unit::TestCase

  def setup
    super
    @jor = JOR::Storage.new(Redis.new(:db => 9, :driver => :hiredis))
    @jor.create_collection("test")
  end

  def teardown
    @jor.redis.flushdb() if @safe_to_remove
  end

  def test_basic_insert_and_find_path

    doc1 = create_sample_doc_restaurant({"_id" => 1})
    @jor.test.insert(doc1)

    doc2 = create_sample_doc_restaurant({"_id" => 2})
    @jor.test.insert(doc2)

    doc3 = create_sample_doc_restaurant({"_id" => 3})
    @jor.test.insert(doc3)

    assert_equal 3, @jor.test.count()
    assert_equal 3, @jor.test.find({}).size

    assert_equal doc1.to_json, @jor.test.find({"_id" => 1}).first.to_json
    assert_equal doc2.to_json, @jor.test.find({"_id" => 2}).first.to_json
    assert_equal doc3.to_json, @jor.test.find({"_id" => 3}).first.to_json
  end

  def test_bulk_insert

    sample_docs = []
    10.times do |i|
      sample_docs << @jor.test.insert({"_id" => i, "name" => "foo_#{i}"})
    end

    assert_equal 10, @jor.test.count()

    docs = @jor.test.find({})
    10.times do |i|
      assert_equal sample_docs[i].to_json, docs[i].to_json
    end

  end

  def test_delete
    sample_docs = []
    10.times do |i|
      sample_docs << @jor.test.insert({"_id" => i, "name" => "foo_#{i}", "foo" => "bar", "year" => 2000+i, "num" => 666 })
    end

    assert_equal 10, @jor.test.count()

    assert_equal 0, @jor.test.delete({"_id" => 42})
    assert_equal 10, @jor.test.count()

    assert_equal 0, @jor.test.delete({"foo" => "not_bar"})
    assert_equal 10, @jor.test.count()

    assert_equal 1, @jor.test.delete({"_id" => 0})
    assert_equal 9, @jor.test.count()

    assert_equal 3, @jor.test.delete({"year" => { "$lt" => 2004 }})
    assert_equal 6, @jor.test.count()

    assert_equal ["4","5","6","7","8","9"].sort, @jor.redis.smembers("jor/test/idx/!/foo/String/bar").sort
    assert_equal ["4","5","6","7","8","9"].sort, @jor.redis.smembers("jor/test/idx/!/num/Numeric/666").sort
    assert_equal ["4","5","6","7","8","9"].sort, @jor.redis.zrange("jor/test/idx/!/num/Numeric",0,-1).sort

    assert_equal 6, @jor.test.delete({"foo" => "bar"})
    assert_equal 0, @jor.test.count()

    assert_equal [], @jor.redis.smembers("jor/test/idx/!/num/String/bar")
    assert_equal [], @jor.redis.smembers("jor/test/idx/!/num/Numeric/666")
    assert_equal [].sort, @jor.redis.zrange("jor/test/idx/!/num/Numeric",0,-1).sort

    assert_equal @jor.redis.keys("jor/test/idx/*"), []

  end

  def test_find_exact_string
    sample_docs = []
    10.times do |i|
      sample_docs << @jor.test.insert({"_id" => i, "name" => "foo_#{i}"})
    end

    doc = @jor.test.find({"name" => "foo_5"}).first
    assert_equal sample_docs[5].to_json, doc.to_json

    doc = @jor.test.find({"name" => "foo_7"}).first
    assert_equal sample_docs[7].to_json, doc.to_json
  end

  def test_find_empty
    assert_equal [], @jor.test.find({})
    assert_equal [], @jor.test.find({"year" => 200})
    assert_equal [], @jor.test.find({"_id" => 200})
  end

  def test_find_by_comparison_selector

    sample_docs = []
    ## years from 2000 to 2009
    10.times do |i|
      sample_docs << @jor.test.insert({"_id" => i, "name" => "foo_#{i}", "year" => 2000+i})
    end

    doc = @jor.test.find({"year" => 2005}).first
    assert_equal sample_docs[5].to_json, doc.to_json

    doc = @jor.test.find({"year" => { "$lt" => 2005 }})
    assert_equal 5, doc.size
    assert_equal sample_docs[0].to_json, doc.first.to_json
    assert_equal sample_docs[4].to_json, doc.last.to_json

    doc = @jor.test.find({"year" => { "$lte" => 2005 }})
    assert_equal 6, doc.size
    assert_equal sample_docs[0].to_json, doc.first.to_json
    assert_equal sample_docs[5].to_json, doc.last.to_json

    doc = @jor.test.find({"year" => { "$gt" => 2007 }})
    assert_equal 2, doc.size
    assert_equal sample_docs[8].to_json, doc.first.to_json
    assert_equal sample_docs[9].to_json, doc.last.to_json

    doc = @jor.test.find({"year" => { "$gte" => 2007 }})
    assert_equal 3, doc.size
    assert_equal sample_docs[7].to_json, doc.first.to_json
    assert_equal sample_docs[9].to_json, doc.last.to_json

    doc = @jor.test.find({"year" => { "$gte" => 2003, "$lt" => 2005 }})
    assert_equal 2, doc.size
    assert_equal sample_docs[3].to_json, doc.first.to_json
    assert_equal sample_docs[4].to_json, doc.last.to_json

    doc = @jor.test.find({"year" => { "$gt" => 2003, "$lt" => 9999 }})
    assert_equal 6, doc.size
    assert_equal sample_docs[4].to_json, doc.first.to_json
    assert_equal sample_docs[9].to_json, doc.last.to_json

  end

  def test_find_by_comparison_combined

    sample_docs = []
    ## years from 2000 to 2009
    10.times do |i|
      sample_docs << @jor.test.insert({"_id" => i, "year" => 2000+i, "desc" => "bar", "nested" => {"name" => "foo_#{i}", "quantity" => i.to_f}})
    end

    docs = @jor.test.find({"year" => { "$gt" => 2001, "$lt" => 2009 }, "nested" => {"quantity" => {"$lt" => 1.0}}})
    assert_equal 0, docs.size
    assert_equal [], docs

    docs = @jor.test.find({"year" => { "$gt" => 2001, "$lt" => 2009 }, "nested" => {"quantity" => {"$lt" => 4.0}}})
    assert_equal 2, docs.size
    assert_equal sample_docs[2].to_json, docs.first.to_json
    assert_equal sample_docs[3].to_json, docs.last.to_json

    docs = @jor.test.find({"year" => { "$gt" => 2001, "$lt" => 2009 }, "nested" => {"name" => "foo_#{4}", "quantity" => {"$lte" => 4.0}}})
    assert_equal 1, docs.size
    assert_equal sample_docs[4].to_json, docs.first.to_json

    docs = @jor.test.find({"year" => { "$gt" => 2001, "$lt" => 2009 }, "desc" => "bar", "nested" => {"name" => "foo_#{4}", "quantity" => {"$lte" => 4.0}}})
    assert_equal 1, docs.size
    assert_equal sample_docs[4].to_json, docs.first.to_json

    docs = @jor.test.find({"year" => { "$gt" => 2001, "$lt" => 2009 }, "desc" => "NOT_bar", "nested" => {"name" => "foo_#{4}", "quantity" => {"$lte" => 4.0}}})
    assert_equal 0, docs.size

  end

  def test_find_by_set_selector

    sample_docs = []
    ## years from 2000 to 2009
    10.times do |i|
      sample_docs << @jor.test.insert({"_id" => i, "name" => "foo_#{i}", "nested" => { "year" => 2000+i, "pair" => ((i%2)==0 ? "even" : "odd")} })
    end

    docs = @jor.test.find({"_id" => {"$in" => []}})
    assert_equal 0, docs.size

    docs = @jor.test.find({"_id" => {"$in" => [42]}})
    assert_equal 0, docs.size

    docs = @jor.test.find({"_id" => {"$in" => [8]}})
    assert_equal 1, docs.size
    assert_equal sample_docs[8].to_json, docs.first.to_json

    docs = @jor.test.find({"_id" => {"$all" => [8]}})
    assert_equal 1, docs.size
    assert_equal sample_docs[8].to_json, docs.first.to_json

    docs = @jor.test.find({"_id" => {"$in" => [1, 2, 3, 4, 42]}})
    assert_equal 4, docs.size
    assert_equal sample_docs[1].to_json, docs.first.to_json
    assert_equal sample_docs[4].to_json, docs.last.to_json

    docs = @jor.test.find({"_id" => {"$all" => [1, 2, 3, 4, 42]}})
    assert_equal 0, docs.size

    docs = @jor.test.find({"name" => {"$in" => ["foo_42"]}})
    assert_equal 0, docs.size

    docs = @jor.test.find({"name" => {"$all" => ["foo_42"]}})
    assert_equal 0, docs.size

    docs = @jor.test.find({"name" => {"$in" => []}})
    assert_equal 0, docs.size

    docs = @jor.test.find({"name" => {"$all" => []}})
    assert_equal 0, docs.size

    docs = @jor.test.find({"name" => {"$in" => ["foo_7", "foo_8", "foo_42"]}})
    assert_equal 2, docs.size
    assert_equal sample_docs[7].to_json, docs.first.to_json
    assert_equal sample_docs[8].to_json, docs.last.to_json

    docs = @jor.test.find({"nested" => {"pair" => { "$in" => ["even", "odd"]}}})
    assert_equal 10, docs.size
    assert_equal sample_docs[0].to_json, docs.first.to_json
    assert_equal sample_docs[9].to_json, docs.last.to_json

    docs = @jor.test.find({"nested" => {"pair" => { "$all" => ["even", "odd"]}}})
    assert_equal 0, docs.size

    docs = @jor.test.find({"nested" => {"pair" => { "$in" => ["even"]}}})
    assert_equal 5, docs.size
    assert_equal sample_docs[0].to_json, docs.first.to_json
    assert_equal sample_docs[8].to_json, docs.last.to_json

    docs = @jor.test.find({"nested" => {"pair" => { "$all" => ["even"]}}})
    assert_equal 5, docs.size
    assert_equal sample_docs[0].to_json, docs.first.to_json
    assert_equal sample_docs[8].to_json, docs.last.to_json

    docs = @jor.test.find({"nested" => {"pair" => { "$in" => ["even", "fake"]}}})
    assert_equal 5, docs.size
    assert_equal sample_docs[0].to_json, docs.first.to_json
    assert_equal sample_docs[8].to_json, docs.last.to_json

    docs = @jor.test.find({"nested" => {"pair" => { "$all" => ["even", "fake"]}}})
    assert_equal 0, docs.size

  end

  def test_find_by_not_selector

    sample_docs = []
    ## years from 2000 to 2009
    10.times do |i|
      sample_docs << @jor.test.insert({"_id" => i, "name" => "foo_#{i}", "nested" => { "year" => 2000+i, "even" => ((i%2)==0 ? true : false)} })
    end

    docs = @jor.test.find({"_id" => {"$not" => 3}})
    assert_equal 9, docs.size
    docs.each do |doc|
      assert_not_equal 3, doc["_id"]
    end

    docs = @jor.test.find({"_id" => {"$not" => [3]}})
    assert_equal 9, docs.size
    docs.each do |doc|
      assert_not_equal 3, doc["_id"]
    end

    docs = @jor.test.find({"_id" => {"$not" => [1, 3, 4, 42]}})
    assert_equal 7, docs.size
    docs.each do |doc|
      assert_not_equal 1, doc["_id"]
      assert_not_equal 3, doc["_id"]
      assert_not_equal 4, doc["_id"]
      assert_not_equal 42, doc["_id"]
    end

    docs = @jor.test.find({"_id" => {"$not" => [3]}})
    assert_equal 9, docs.size
    docs.each do |doc|
      assert_not_equal 3, doc["_id"]
    end

    docs = @jor.test.find({"name" => {"$not" => "foo_3"}})
    assert_equal 9, docs.size
    docs.each do |doc|
      assert_not_equal 3, doc["_id"]
    end

    docs = @jor.test.find({"name" => {"$not" => ["foo_3"]}})
    assert_equal 9, docs.size
    docs.each do |doc|
      assert_not_equal 3, doc["_id"]
    end

    docs = @jor.test.find({"name" => {"$not" => ["foo_1", "foo_3", "foo_4", "foo_42"]}})
    assert_equal 7, docs.size
    docs.each do |doc|
      assert_not_equal 1, doc["_id"]
      assert_not_equal 3, doc["_id"]
      assert_not_equal 4, doc["_id"]
      assert_not_equal 42, doc["_id"]
    end

    docs = @jor.test.find({"nested" => {"year" => {"$not" => 2004}}})
    assert_equal 9, docs.size
    docs.each do |doc|
      assert_not_equal 4, doc["_id"]
    end

    docs = @jor.test.find({"nested" => {"year" => {"$not" => [2004, 2009]}}})
    assert_equal 8, docs.size
    docs.each do |doc|
      assert_not_equal 4, doc["_id"]
      assert_not_equal 9, doc["_id"]
    end

    docs = @jor.test.find({"nested" => {"even" => true}})
    assert_equal 5, docs.size
    docs.each do |doc|
      assert_equal 0, doc["_id"]%2
    end

    docs = @jor.test.find({"nested" => {"even" => {"$not" => false}}})
    assert_equal 5, docs.size
    docs.each do |doc|
      assert_equal 0, doc["_id"]%2
    end




  end

  def test_playing_with_find_options

    n = (JOR::Collection::DEFAULT_OPTIONS[:max_documents]+100)

    n.times do |i|
      doc = create_sample_doc_restaurant({"_id" => i})
      @jor.test.insert(doc)
    end

    ## testing max_documents

    docs = @jor.test.find({})

    assert_equal JOR::Collection::DEFAULT_OPTIONS[:max_documents], docs.size
    assert_equal 0, docs.first["_id"]
    assert_equal JOR::Collection::DEFAULT_OPTIONS[:max_documents]-1, docs.last["_id"]

    docs = @jor.test.find({},{:max_documents => 20})
    assert_equal 20, docs.size

    docs = @jor.test.find({},{:max_documents => -1})
    assert_equal n, docs.size
    assert_equal 0, docs.first["_id"]
    assert_equal n-1, docs.last["_id"]

    ## testing only_ids

    docs = @jor.test.find({},{:only_ids => true, :max_documents => -1})
    assert_equal n, docs.size
    assert_equal 0, docs.first
    assert_equal n-1, docs.last

    docs = @jor.test.find({},{:only_ids => true})
    assert_equal JOR::Collection::DEFAULT_OPTIONS[:max_documents], docs.size
    assert_equal 0, docs.first
    assert_equal JOR::Collection::DEFAULT_OPTIONS[:max_documents]-1, docs.last

    ## testing reversed

    docs = @jor.test.find({},{:only_ids => true, :max_documents => -1, :reversed => true})
    assert_equal n, docs.size
    assert_equal n-1, docs.first
    assert_equal 0, docs.last

    docs = @jor.test.find({},{:only_ids => true, :reversed => true})
    assert_equal JOR::Collection::DEFAULT_OPTIONS[:max_documents], docs.size
    assert_equal n-1, docs.first
    assert_equal n-JOR::Collection::DEFAULT_OPTIONS[:max_documents], docs.last

    ## encoded false

    docs = @jor.test.find({},{:raw => true, :reversed => true})
    assert_equal JOR::Collection::DEFAULT_OPTIONS[:max_documents], docs.size
    assert_equal String, docs.first.class
    assert_equal String, docs.last.class
    assert_equal n-1, JSON::parse(docs.first)["_id"]
    assert_equal n-JOR::Collection::DEFAULT_OPTIONS[:max_documents], JSON::parse(docs.last)["_id"]

  end

  def test_exclude_indexes

    assert_raise JOR::FieldIdCannotBeExcludedFromIndex do
      @jor.test.insert(create_sample_doc_restaurant({"_id" => 1}),
        {:excluded_fields_to_index => {"_id" => true}})
    end

    @jor.test.insert(create_sample_doc_restaurant({"_id" => 1}),
      {:excluded_fields_to_index => {"description" => true}})

    @jor.test.insert(create_sample_doc_restaurant({"_id" => 42}),
      {:excluded_fields_to_index => {}})

    v = []
    @jor.test.indexes(1).each do |ind|
      v << ind["path"]
    end
    assert_equal false, v.include?("/description")

    v = []
    @jor.test.indexes(42).each do |ind|
      v << ind["path"]
    end
    assert_equal true, v.include?("/description")

    res = @jor.test.find({},{:reversed => true})
    assert_equal 2, res.size
    assert_equal "very long description that we might not want to index", res.first["description"]
    assert_equal 42, res.first["_id"]
    assert_equal "very long description that we might not want to index", res.last["description"]
    assert_equal 1, res.last["_id"]

    res = @jor.test.find({"description" => "very long description that we might not want to index"}, :reversed => true)
    assert_equal 1, res.size
    assert_equal 42, res.first["_id"]

  end

  def test_auto_increment_collections
    @jor.create_collection("no_auto_increment")
    @jor.create_collection("no_auto_increment2", :auto_increment => false)
    @jor.create_collection("auto_increment",:auto_increment => true)

    assert_equal false, @jor.no_auto_increment.auto_increment?
    assert_equal false, @jor.no_auto_increment2.auto_increment?
    assert_equal true, @jor.auto_increment.auto_increment?

    10.times do |i|
     @jor.auto_increment.insert({"foo" => "bar"})
    end

    assert_equal 10, @jor.auto_increment.count()

    assert_raise JOR::DocumentDoesNotNeedId do
     @jor.auto_increment.insert({"_id"=> 10, "foo" => "bar"})
    end

    assert_equal 10, @jor.auto_increment.count()
    assert_equal 10, @jor.auto_increment.last_id()
    assert_equal 0, @jor.no_auto_increment.last_id()
  end

  def test_last_id_for_collections
    @jor.create_collection("no_auto_increment")
    @jor.create_collection("auto_increment",:auto_increment => true)

    assert_equal 0, @jor.no_auto_increment.last_id()
    assert_equal 0, @jor.auto_increment.last_id()

    10.times do |i|
     @jor.auto_increment.insert({"foo" => "bar"})
    end

    assert_equal 10, @jor.auto_increment.last_id()
    assert_not_nil @jor.auto_increment.find({"_id" => 10}).first

    10.times do |i|
     @jor.no_auto_increment.insert({"_id" => i+10, "foo" => "bar"})
    end

    assert_equal 19, @jor.no_auto_increment.last_id()
    assert_not_nil @jor.no_auto_increment.find({"_id" => 10}).first
  end

  def test_ids_expections_for_collections
    @jor.create_collection("no_auto_increment")
    @jor.create_collection("auto_increment",:auto_increment => true)

    assert_raise JOR::DocumentDoesNotNeedId do
      @jor.auto_increment.insert({"_id"=> 10, "foo" => "bar"})
    end

    assert_raise JOR::DocumentNeedsId do
      @jor.no_auto_increment.insert({"foo" => "bar"})
    end

    assert_raise JOR::InvalidDocumentId do
      @jor.no_auto_increment.insert({"_id"=> "10", "foo" => "bar"})
    end

    assert_raise JOR::InvalidDocumentId do
      @jor.no_auto_increment.insert({"_id"=> -1, "foo" => "bar"})
    end
  end

  def test_ids_will_be_sorted
   v = [1, 10, 100, 1000, 10000, 2, 20, 200, 2000, 20000]
   v_sorted = v.sort
   v_shuffled = v.shuffle

   v_shuffled.each do |val|
     @jor.test.insert({"_id" => val, "foo" => "bar"})
   end

   res = @jor.test.find({})
   assert_equal v.size, res.size

   res.each_with_index do |item, i|
     assert_equal v_sorted[i], item["_id"]
   end
  end

  def test_concurrent_inserts

    threads = []
    inserted_by_thread = []
    5.times do |i|
      inserted_by_thread[i] = []
      threads << Thread.new {
        id = i
        1000.times do |j|
          begin
            doc = @jor.test.insert(create_sample_doc_restaurant({"_id" => j}))
            inserted_by_thread[id] << j unless doc.nil?
            sleep(0.1) if (j%200==0)
          rescue Exception => e
          end
        end
      }
    end

    threads.each do |t|
      t.join()
    end

    res = @jor.test.find({},{:max_documents => -1})
    assert_equal 1000, res.size

    all = inserted_by_thread[0]
    inserted_by_thread.each do |curr|
      all =  all & curr
    end
    assert_equal 0, all.size

    all = inserted_by_thread[0]
    inserted_by_thread.each do |curr|
      all =  all | curr
    end
    assert_equal 1000, all.size
  end

  def test_intervals
    1000.times do |i|
      @jor.test.insert(create_sample_doc_restaurant({"_id" => i, "at" => i}))
    end

    docs = @jor.test.find({})
    assert_equal 1000, docs.size

    docs = @jor.test.find({"at" => {"$lt" => 100}})
    assert_equal 100, docs.size

    docs = @jor.test.find({"at" => {"$lt" => 100, "$gte" => 50}})
    assert_equal 50, docs.size

    curr = 50
    docs.each do |doc|
      assert_equal curr, doc["_id"]
      curr+=1
    end

    docs = @jor.test.find({"at" => {"$lt" => 100, "$gte" => 150}})
    assert_equal 0, docs.size
  end

  def test_update
    sample_docs = []
    5.times do |i|
      sample_docs << @jor.test.insert({"_id" => i, "name" => "foo_#{i}", "foo" => "bar", "year" => 2000+i })
    end

    @jor.test.update({"name" => "foo_4"}, {"name" => "foo_changed_4", "additional_field" => 3})

    docs = @jor.test.find({"name" => "foo_4"})
    assert_equal 0, docs.size()

    [{"additional_field" => 3}, {"name" => "foo_changed_4"}, {"year" => 2004}].each do |search_doc|
      docs = @jor.test.find(search_doc)
      assert_equal 1, docs.size()
      assert_equal "foo_changed_4", docs.first["name"]
      assert_equal 3, docs.first["additional_field"]
      assert_equal 2004, docs.first["year"]
      assert_equal "bar", docs.first["foo"]
    end

  end

  def test_update_with_id
    sample_docs = []
    5.times do |i|
      sample_docs << @jor.test.insert({"_id" => i, "name" => "foo_#{i}", "foo" => "bar", "year" => 2000+i })
    end

    docs = @jor.test.update({"name" => "foo_4"}, {"name" => "foo_changed_4", "additional_field" => 3, "_id" => 666})
    assert_equal 1, docs.size()
    assert_equal "foo_changed_4", docs.first["name"]
    assert_equal 4, docs.first["_id"]

    docs = @jor.test.find({"_id" => 4})
    assert_equal 1, docs.size()
    assert_equal "foo_changed_4", docs.first["name"]
    assert_equal 4, docs.first["_id"]
  end

  def test_update_with_excluded_fields
    sample_docs = []
    5.times do |i|
      sample_docs << @jor.test.insert({"_id" => i, "name" => "foo_#{i}", "foo" => "bar", "year" => 2000+i })
    end

    docs = @jor.test.update({"foo" => "bar"}, {"foo" => "bar_changed", "description" => "long ass description"},
      {:excluded_fields_to_index => {"description" => true}})

    assert_equal 5, docs.size()
    assert_equal "long ass description", docs.first["description"]
    assert_equal "long ass description", docs.last["description"]

    docs = @jor.test.find({"foo" => "bar_changed"})
    assert_equal 5, docs.size()
    assert_equal "long ass description", docs.first["description"]
    assert_equal "long ass description", docs.last["description"]

    docs = @jor.test.find({"description" => "long ass description"})
    assert_equal 0, docs.size()

    docs = @jor.test.update({"foo" => "bar_changed"}, {"description" => "long ass description"})
    assert_equal 5, docs.size()

    docs = @jor.test.find({"description" => "long ass description"})
    assert_equal 5, docs.size()
  end

  def test_update_massive_update

    sample_docs = []
    5.times do |i|
      sample_docs << @jor.test.insert({"_id" => i, "name" => "foo_#{i}", "foo" => "bar", "year" => 2000+i })
    end

    docs = @jor.test.find({"foo" => "bar"})
    assert_equal 5, docs.size()

    docs = @jor.test.find({"foo" => "bar_changed"})
    assert_equal 0, docs.size()

    docs = @jor.test.find({"bar" => "bar_added"})
    assert_equal 0, docs.size()

    @jor.test.update({"foo" => "bar"}, {"foo" => "bar_changed", "bar" => "bar_added"})

    docs = @jor.test.find({"foo" => "bar"})
    assert_equal 0, docs.size()

    docs = @jor.test.find({"foo" => "bar_changed"})
    assert_equal 5, docs.size()

    docs = @jor.test.find({"bar" => "bar_added"})
    assert_equal 5, docs.size()
  end

  def test_update_remove_field

    sample_docs = []
    5.times do |i|
      sample_docs << @jor.test.insert({"_id" => i, "name" => "foo_#{i}", "foo" => "bar", "year" => 2000+i })
    end

    @jor.test.update({"foo" => "bar"}, {"foo" => nil, "xtra" => "large"})

    docs = @jor.test.find({"foo" => "bar"})
    assert_equal 0, docs.size()

    docs = @jor.test.find({})
    assert_equal 5, docs.size()

    docs.each_with_index do |d, i|
      assert_equal "foo_#{i}", d["name"]
      assert_equal i, d["_id"]
      assert_equal nil, d["foo"]
      assert_equal "large", d["xtra"]
    end

    @jor.test.update({"xtra" => "large"}, {"foo" => "bar"})

    docs = @jor.test.find({"foo" => "bar"})
    assert_equal 5, docs.size()

    docs.each_with_index do |d, i|
      assert_equal "foo_#{i}", d["name"]
      assert_equal i, d["_id"]
      assert_equal "bar", d["foo"]
      assert_equal "large", d["xtra"]
    end

  end

  def test_update_remove_filed_nested

    @jor.test.insert(create_sample_doc_restaurant({"_id" => 42}))
    docs = @jor.test.find({"address" => {"zipcode" => "08104"}})
    assert_equal 1, docs.size()

    indexes_before = @jor.test.indexes(42)

    @jor.test.update({"_id" => 42}, {"address" => {"zipcode" => nil}})
    docs = @jor.test.find({"address" => {"zipcode" => "08104"}})
    assert_equal 0, docs.size

    indexes_after =  @jor.test.indexes(42)
    ## -1  because we removed address/zipcode, but plus 1 because now _updated_at exists
    assert_equal indexes_before.size, indexes_after.size
    indexes_after.each do |item|
      assert_equal false, ["/address/zipcode"].include?(item["path"])
    end


    docs = @jor.test.find({"_id" => 42})
    assert_equal 1, docs.size
    assert_equal "Ann Arbor", docs.first["address"]["city"]
    assert_equal "Main St 100", docs.first["address"]["address"]

    @jor.test.update({"_id" => 42}, {"address" => nil})
    docs = @jor.test.find({"address" => {"zipcode" => "08104"}})
    assert_equal 0, docs.size

    indexes_after =  @jor.test.indexes(42)
    assert_equal indexes_before.size - 2, indexes_after.size

    indexes_after.each do |item|
      assert_equal false, ["/address/zipcode", "/address/address", "/address/city"].include?(item["path"])
    end

  end

  def test_update_arrays

    sample_docs = []
    5.times do |i|
      sample_docs << @jor.test.insert({"_id" => i, "name" => "foo_#{i}", "foo" => [1,2,3,4,5], "year" => 2000+i })
    end

    @jor.test.update({"_id" => 4}, {"foo" => [6,7,8]})
    docs = @jor.test.find({"_id" => 4})
    assert_equal 1, docs.size()
    assert_equal [6,7,8].sort, docs.first["foo"].sort

    @jor.test.update({"_id" => 4}, {"foo" => {"bar" => [9, 10]}})
    docs = @jor.test.find({"_id" => 4})
    assert_equal 1, docs.size()
    assert_equal [9, 10].sort, docs.first["foo"]["bar"].sort

    @jor.test.update({"_id" => 4}, {"foo" => {"bar" => [11, 12]}})
    docs = @jor.test.find({"_id" => 4})
    assert_equal 1, docs.size()
    assert_equal [11, 12].sort, docs.first["foo"]["bar"].sort

    @jor.test.update({"_id" => 4}, {"foo" => nil})
    docs = @jor.test.find({"_id" => 4})
    assert_equal 1, docs.size()
    assert_equal nil, docs.first["foo"]

    assert_equal  0, ([{"path"=>"/name", "obj"=>"String", "value"=>"foo_4"},
                    {"path"=>"/_id", "obj"=>"Numeric", "value"=>"4"},
                    {"path"=>"/year", "obj"=>"Numeric", "value"=>"2004"}] - @jor.test.indexes(4)).size


  end

  def test_created_and_update_at
    start_time = Time.now.to_f
    sample_docs = []
    5.times do |i|
      sample_docs << @jor.test.insert({"_id" => i, "name" => "foo_#{i}", "foo" => [1,2,3,4,5], "year" => 2000+i })
    end
    end_time = Time.now.to_f

    sample_docs.each do |d|
      assert_equal true, d["_created_at"]>=start_time && d["_created_at"]<=end_time
    end

    docs = @jor.test.find({})
    docs.each do |d|
      assert_equal true, d["_created_at"]>=start_time && d["_created_at"]<=end_time
      assert_equal nil, d["_updated_at"]
    end

    @jor.test.insert({"_id" => 42, "name" => "foo_#{42}", "foo" => [1,2,3,4,5], "year" => 2000+42, "_created_at" => start_time})
    docs = @jor.test.find({"_id" => 42})
    assert_equal start_time, docs.first["_created_at"]

    start_time2 = Time.now.to_f
    @jor.test.update({},{"updated" => "yeah"})
    end_time2 = Time.now.to_f

    docs = @jor.test.find({})
    docs.each do |d|
      assert_equal true, d["_created_at"]>=start_time && d["_created_at"]<=end_time
      assert_equal true, d["_updated_at"]>=start_time2 && d["_updated_at"]<=end_time2
    end

    assert_equal 6, docs.size()

    @jor.test.delete({"_created_at" => {"$lte" => start_time}})
    docs = @jor.test.find({})
    assert_equal 5, docs.size()
  end

  def test_boolean_fields

    doc = @jor.test.insert({"_id" => 1, "foo" => "bar", "is_true" => true, "is_false" => false})
    assert_equal true, doc["is_true"]
    assert_equal false, doc["is_false"]

    doc = @jor.test.insert({"_id" => 2, "foo" => "bar", "is_true" => true, "is_false" => false})
    assert_equal true, doc["is_true"]
    assert_equal false, doc["is_false"]

    docs = @jor.test.find({})
    assert_equal 2, docs.size
    assert_equal true, docs.first["is_true"]
    assert_equal false, docs.first["is_false"]
    assert_equal true, docs.last["is_true"]
    assert_equal false, docs.last["is_false"]

    docs = @jor.test.find({"_id" => 2, "is_true" => true})
    assert_equal 1, docs.size
    assert_equal 2, docs.first["_id"]
    assert_equal true, docs.first["is_true"]
    assert_equal false, docs.first["is_false"]

    docs = @jor.test.find({"_id" => 2, "foo" => "not_bar"})
    assert_equal 0, docs.size

    docs = @jor.test.find({"is_false" => false})
    assert_equal 2, docs.size

    docs = @jor.test.find({"_id" => 2, "is_true" => false})
    assert_equal 0, docs.size

    docs = @jor.test.find({"_id" => 2, "is_true" => "false"})
    assert_equal 0, docs.size

    docs = @jor.test.find({"_id" => 2, "is_true" => "true"})
    assert_equal 0, docs.size

    docs = @jor.test.find({"_id" => 2, "is_true" => nil})
    assert_equal 0, docs.size

    docs = @jor.test.update({"_id" => 2, "is_true" => true}, {"is_true" => false})
    assert_equal 1, docs.size
    assert_equal false, docs.first["is_true"]

    docs = @jor.test.find({"_id" => 2})
    assert_equal 1, docs.size
    assert_equal 2, docs.first["_id"]
    assert_equal false, docs.first["is_true"]
    assert_equal false, docs.first["is_false"]

    docs = @jor.test.find({"is_true" => {"$in" => [true, false]}})
    assert_equal 2, docs.size
    assert_equal true, docs.first["is_true"]
    assert_equal false, docs.first["is_false"]
    assert_equal 1, docs.first["_id"]
    assert_equal false, docs.last["is_true"]
    assert_equal false, docs.last["is_false"]
    assert_equal 2, docs.last["_id"]

    docs = @jor.test.find({"is_true" => {"$all" => [true, false]}})
    assert_equal 0, docs.size
  end

end
