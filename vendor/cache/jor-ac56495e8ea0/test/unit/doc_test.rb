require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class StorageTest < JOR::Test::Unit::TestCase

  def setup
    super
    @jor = JOR::Storage.new(Redis.new(:db => 9, :driver => :hiredis))
    @jor.create_collection("test")
  end

  def teardown
    @jor.redis.flushdb() if @safe_to_remove
  end

  def test_all_paths
    doc = create_sample_doc_restaurant({"_id" => 1})
    paths = JOR::Doc.paths("",doc)

    expected_paths = [
      {"path_to"=>"/_id", "obj"=>1, "class"=>Fixnum},
      {"path_to"=>"/name", "obj"=>"restaurant", "class"=>String},
      {"path_to"=>"/stars", "obj"=>3, "class"=>Fixnum},
      {"path_to"=>"/cuisine", "obj"=>"asian", "class"=>String},
      {"path_to"=>"/cuisine", "obj"=>"japanese", "class"=>String},
      {"path_to"=>"/address/address", "obj"=>"Main St 100", "class"=>String},
      {"path_to"=>"/address/city", "obj"=>"Ann Arbor", "class"=>String},
      {"path_to"=>"/address/zipcode", "obj"=>"08104", "class"=>String},
      {"path_to"=>"/description", "obj"=>"very long description that we might not want to index", "class"=>String},
      {"path_to"=>"/wines/name", "obj"=>"wine1", "class"=>String},
      {"path_to"=>"/wines/year", "obj"=>1998, "class"=>Fixnum},
      {"path_to"=>"/wines/type", "obj"=>"garnatxa", "class"=>String},
      {"path_to"=>"/wines/type", "obj"=>"merlot", "class"=>String},
      {"path_to"=>"/wines/name", "obj"=>"wine2", "class"=>String},
      {"path_to"=>"/wines/year", "obj"=>2009, "class"=>Fixnum},
      {"path_to"=>"/wines/type", "obj"=>"syrah", "class"=>String},
      {"path_to"=>"/wines/type", "obj"=>"merlot", "class"=>String}
    ]

    assert_equal expected_paths, paths
  end

  def test_path_selectors
    doc = {"_id" => 1, "year" => 1898, "list" => {"quantity" => 15}}
    paths = JOR::Doc.paths("",doc)

    expected_paths = [
      {"path_to"=>"/_id", "obj"=>1, "class"=>Fixnum},
      {"path_to"=>"/year", "obj"=>1898, "class"=>Fixnum},
      {"path_to"=>"/list/quantity", "obj"=>15, "class"=>Fixnum}
    ]
    assert_equal expected_paths, paths

    doc = {"_id" => 1, "year" => 1898, "list" => {"quantity" => {"$lt" => 60}}}
    paths = JOR::Doc.paths("",doc)

    expected_paths = [
      {"path_to"=>"/_id", "obj"=>1, "class"=>Fixnum},
      {"path_to"=>"/year", "obj"=>1898, "class"=>Fixnum},
      {"path_to"=>"/list/quantity", "obj"=>{"$lt"=>60}, "class"=>Hash, "selector"=>true}
    ]
    assert_equal expected_paths, paths

    doc = {"_id" => 1, "year" => 1898, "list" => {"quantity" => {"$gt" => 10, "$lt" => 60}}}
    paths = JOR::Doc.paths("",doc)

    expected_paths = [
      {"path_to"=>"/_id", "obj"=>1, "class"=>Fixnum},
      {"path_to"=>"/year", "obj"=>1898, "class"=>Fixnum},
      {"path_to"=>"/list/quantity", "obj"=>{"$gt"=>10, "$lt"=>60}, "class"=>Hash, "selector"=>true}
    ]
    assert_equal expected_paths, paths

    doc = {"_id" => {"$in" => [1, 2, 42]}}
    paths = JOR::Doc.paths("",doc)
    expected_paths = [
      {"path_to"=>"/_id", "obj"=>{"$in"=>[1, 2, 42]}, "class"=>Hash, "selector"=>true}
    ]
    assert_equal expected_paths, paths

    doc = {"_id" => {"$all" => [1, 2, 42]}}
    paths = JOR::Doc.paths("",doc)
    expected_paths = [
      {"path_to"=>"/_id", "obj"=>{"$all"=>[1, 2, 42]}, "class"=>Hash, "selector"=>true}
    ]
    assert_equal expected_paths, paths
  end

  def test_difference

    doc = {"_id" => 1, "year" => 1898,
            "list" => {"quantity" => 15, "extra" => "long description that you want to skip"}}
    paths = JOR::Doc.paths("",doc)

    expected_paths = [
      {"path_to"=>"/_id", "obj"=>1, "class"=>Fixnum},
      {"path_to"=>"/year", "obj"=>1898, "class"=>Fixnum},
      {"path_to"=>"/list/quantity", "obj"=>15, "class"=>Fixnum},
      {"path_to"=>"/list/extra", "obj"=>"long description that you want to skip", "class"=>String}
    ]
    assert_equal expected_paths, paths

    paths_to_exclude = JOR::Doc.paths("",{"_id" => 1})

    assert_raise JOR::FieldIdCannotBeExcludedFromIndex do
      JOR::Doc.difference(paths,paths_to_exclude)
    end

    paths_to_exclude = JOR::Doc.paths("",{"list" => {"extra" => ""}})

    expected_paths = [
      {"path_to"=>"/list/extra", "obj"=>"", "class"=>String}
    ]
    assert_equal expected_paths, paths_to_exclude

    diff_paths = JOR::Doc.difference(paths, paths_to_exclude)

    expected_paths = [
      {"path_to"=>"/_id", "obj"=>1, "class"=>Fixnum},
      {"path_to"=>"/year", "obj"=>1898, "class"=>Fixnum},
      {"path_to"=>"/list/quantity", "obj"=>15, "class"=>Fixnum}
    ]
    assert_equal expected_paths, diff_paths

    paths_to_exclude = JOR::Doc.paths("",{"list" => true})
    diff_paths = JOR::Doc.difference(paths, paths_to_exclude)

    expected_paths = [
      {"path_to"=>"/_id", "obj"=>1, "class"=>Fixnum},
      {"path_to"=>"/year", "obj"=>1898, "class"=>Fixnum},
    ]
    assert_equal expected_paths, diff_paths


    paths_to_exclude = JOR::Doc.paths("",{"list" => {"extra" => true}, "year" => true})
    diff_paths = JOR::Doc.difference(paths, paths_to_exclude)

    expected_paths = [
      {"path_to"=>"/_id", "obj"=>1, "class"=>Fixnum},
      {"path_to"=>"/list/quantity", "obj"=>15, "class"=>Fixnum}
    ]
    assert_equal expected_paths, diff_paths

  end
end
