local ngxjor = require 'ngxjor'

local to_path = function(path)
  return table.concat(path.path_to or {})
end

local sorted = function(t)
  table.sort(t, function(a, b)
               if to_path(a) == to_path(b) then
                 return a.obj < b.obj
               else
                 return to_path(a) < to_path(b)
               end
            end)
  return t
end

local function shallow_clone(t1)
  local res = {}
  for i,v in pairs(t1) do
    res[i] = v
  end
  return res
end

local function shallow_merge(default, dominant)  -- returns new table with contents of both tables
  local res = shallow_clone(default)
  for k,v in pairs(dominant) do
    res[k] = v
  end
  return res
end

local function create_sample_doc_cs(partial_doc)
  local doc = {
    _id = 1,
    name = {
      first = "John",
      last = "Backus"
    },
    birth = Time.mktime("1924","12","03","05","00","00").to_i,
    death = Time.mktime("2007","03","17","04","00","00").to_i,
    contribs = { "Fortran", "ALGOL", "Backus-Naur Form", "FP" },
    awards = {
      {
        award = "W.W. McDowellAward",
        year = 1967,
        by = "IEEE Computer Society"
      },
      {
        award = "National Medal of Science",
        year = 1975,
        by = "National Science Foundation"
      },
      {
        award = "Turing Award",
        year = 1977,
        by = "ACM"
      },
      {
        award = "Draper Prize",
        year = 1993,
        by = "National Academy of Engineering"
      }
    }
  }
  if partial_doc then
    return shallow_merge(doc, partial_doc)
  else
    return doc
  end
end

local function create_sample_doc_restaurant(partial_doc)
  local doc = {
    _id = 1,
    name = "restaurant",
    stars = 3,
    cuisine = {"asian", "japanese"},
    address = {
      address = "Main St 100",
      city    = "Ann Arbor",
      zipcode = "08104"
    },
    description = "very long description that we might not want to index",
    wines = {
      {
        name = "wine1",
        year = 1998,
        type = {"garnatxa", "merlot"}
      },
      {
        name = "wine2",
        year = 2009,
        type = {"syrah", "merlot"}
      },
    }
  }
  if partial_doc then
    return shallow_merge(doc, partial_doc)
  else
    return doc
  end
end

describe("ngxjor", function()
  before_each(function()
    ngxjor:reset()
  end)

  describe('get_doc_paths', function()
    it("builds a path if doc is a non-table type", function()
      local empty = {}
      local str = { {
        class = "String",
        obj = "hello",
        path_to = {"!"}
      } }
      local t = { {
        class = "TrueClass",
        obj = true,
        path_to = {"!"}
      } }
      local f = { {
        class = "FalseClass",
        obj = false,
        path_to = {"!"}
      } }
      local num = { {
        class = "Numeric",
        obj = 0,
        path_to = {"!"}
      } }

      assert.are.same(empty, ngxjor.get_doc_paths(ngxjor, "!", {}))
      assert.are.same(str, ngxjor.get_doc_paths(ngxjor, "!", 'hello'))
      assert.are.same(f, ngxjor.get_doc_paths(ngxjor, "!", false))
      assert.are.same(t, ngxjor.get_doc_paths(ngxjor, "!", true))
      assert.are.same(num, ngxjor.get_doc_paths(ngxjor, "!", 0))
    end)

    it("generates the same object when enclosed into an array", function()
      local f = { {
        class = "FalseClass",
        obj = false,
        path_to = {"!"}
      } }
      assert.are.same(f, ngxjor.get_doc_paths(ngxjor, "!", {false}))
      assert.are.same(f, ngxjor.get_doc_paths(ngxjor, "!", {{false}}))
    end)
    it("checks for duplicated paths", function()

    end)
    it("works for complex docs", function()


      local expected_paths = {
        {path_to={"address", "address"}, obj = "Main St 100", class = "String"},
        {path_to={"address", "city"}, obj = "Ann Arbor", class = "String"},
        {path_to={"address", "zipcode"}, obj = "08104", class = "String"},
        {path_to={"stars"}, obj = 3, class = "Numeric"},
        {path_to={"cuisine"}, obj = "asian", class = "String"},
        {path_to={"cuisine"}, obj = "japanese", class = "String"},
        {path_to={"_id"}, obj = 1, class = "Numeric"},
        {path_to={"wines", "type"}, obj = "garnatxa", class = "String"},
        {path_to={"wines", "type"}, obj = "merlot", class = "String"},
        {path_to={"wines", "year"}, obj = 1998, class = "Numeric"},
        {path_to={"wines", "name"}, obj = "wine1", class = "String"},
        {path_to={"wines", "type"}, obj = "syrah", class = "String"},
        {path_to={"wines", "type"}, obj = "merlot", class = "String"},
        {path_to={"wines", "year"}, obj = 2009, class = "Numeric"},
        {path_to={"wines", "name"}, obj = "wine2", class = "String"},
        {path_to={"name"}, obj = "restaurant", class = "String"},
        {path_to={"description"}, obj = "very long description that we might not want to index", class = "String"},
      }

      local dp = ngxjor.get_doc_paths(ngxjor, "", create_sample_doc_restaurant())

      assert.same(sorted(expected_paths), sorted(dp))
    end)

    it("substract sets of indexes", function()
      local original = ngxjor.get_doc_paths(ngxjor, "",
                                           {foo='bar', address={1, {si=2, no=3}}})
      local excluded = ngxjor.get_doc_paths(ngxjor, "", {address=true})
      assert.same(ngxjor.substract_set(original, excluded),
                  { { class = "String", obj = "bar", path_to = {"foo"}}})
    end)

    it("excludes fields to index", function()
         -- id can't be excluded
         --
      -- assert.same(sorted(expected_paths), sorted(dp))
    end)

    it("works with path_selectors", function()

      local doc = {_id = 1, year = 1898, list = {quantity = 15}}
      -- paths = JOR::Doc.paths("",doc)

      local expected_paths = {
        {path_to={"_id"}, obj=1, class="Numeric"},
        {path_to={"year"}, obj=1898, class="Numeric"},
        {path_to={"list", "quantity"}, obj=15, class="Numeric"}
      }
      local dp = ngxjor.get_doc_paths(ngxjor, "", doc)

      assert.are.same(sorted(expected_paths), sorted(dp))

      doc = {_id = 1, year = 1898, list = {quantity = {["$lt"] = 60}}}
      -- paths = JOR::Doc.paths("",doc)

      expected_paths = {
        {path_to = {"_id"}, obj =1, class ='Numeric'},
        {path_to = {"year"}, obj =1898, class ='Numeric'},
        {path_to = {"list", "quantity"}, obj ={["$lt"]=60}, class ="Hash", selector =true}
      }
      dp = ngxjor.get_doc_paths(ngxjor, "", doc)
      assert.are.same(sorted(expected_paths), sorted(dp))

      doc = {_id = 1, year = 1898, list = {quantity = {["$gt"] = 10, ["$lt"] = 60}}}
      -- paths = JOR::Doc.paths("",doc)

      expected_paths = {
        {path_to ={"_id"}, obj =1, class ='Numeric'},
        {path_to ={"year"}, obj =1898, class ='Numeric'},
        {path_to ={"list","quantity"}, obj ={["$gt"]=10, ["$lt"]=60}, class = "Hash", selector =true}
      }

      dp =  ngxjor.get_doc_paths(ngxjor, "", doc)
      assert.are.same(sorted(expected_paths),sorted(dp))

      doc = {_id = {["$in"] = {1, 2, 42}}}
      -- paths = JOR::Doc.paths("",doc)
      expected_paths = {
        {path_to = {"_id"}, obj ={["$in"]={1, 2, 42}}, class ='Hash', selector =true}
      }
      dp =  ngxjor.get_doc_paths(ngxjor, "", doc)
      assert.are.same(sorted(expected_paths),sorted(dp))

      doc = {_id = {["$all"] = {1, 2, 42}}}
      expected_paths = {
        {path_to ={"_id"}, obj ={["$all"]={1, 2, 42}}, class ='Hash', selector =true}
      }
      dp = ngxjor.get_doc_paths(ngxjor, "", doc)
      assert.are.same(sorted(expected_paths), sorted(dp))
    end)


    it("does differences correctly", function()


      local doc = {_id = 1, year = 1898,
      list = {quantity = 15, extra = "long description that you want to skip"}}

      local expected_paths = {
        {path_to ={"_id"}, obj =1, class ='Numeric'},
        {path_to ={"year"}, obj =1898, class ='Numeric'},
        {path_to ={"list", "quantity"}, obj =15, class ='Numeric'},
        {path_to ={"list", "extra"}, obj ="long description that you want to skip", class ='String'}
      }
      local paths =  ngxjor.get_doc_paths(ngxjor, "", doc)
      assert.are.same(sorted(expected_paths), sorted(paths) )

      -- local paths_to_exclude = ngxjor.get_doc_paths(ngxjor, "", {_id = 1})

      -- assert_raise JOR::FieldIdCannotBeExcludedFromIndex do
      --   JOR::Doc.difference(paths,paths_to_exclude)
      -- end

      local paths_to_exclude = ngxjor.get_doc_paths(ngxjor, "", {list = {extra = ""}})

      expected_paths = {
        {path_to ={"list", "extra"}, obj = "", class ='String'}
      }

      assert.are.same(sorted(expected_paths), sorted(paths_to_exclude))

      --diff_paths = JOR::Doc.difference(paths, paths_to_exclude)
      local diff_paths = ngxjor.substract_set(paths, paths_to_exclude)

      expected_paths = {
        {path_to ={"_id"}, obj =1, class ='Numeric'},
        {path_to ={"year"}, obj =1898, class ='Numeric'},
        {path_to ={"list", "quantity"}, obj =15, class ='Numeric'}
      }
      assert.are.same(sorted(expected_paths), sorted(diff_paths))

      paths_to_exclude = ngxjor.get_doc_paths(ngxjor, "", {list = true})
      diff_paths = ngxjor.substract_set(paths, paths_to_exclude)

      expected_paths = {
        {path_to ={"_id"}, obj =1, class ='Numeric'},
        {path_to ={"year"}, obj =1898, class ='Numeric'},
      }

      assert.are.same(sorted(expected_paths), sorted(diff_paths))

      paths_to_exclude = ngxjor.get_doc_paths(ngxjor, "", {list = {extra = true}, year = true})
      diff_paths = ngxjor.substract_set(paths, paths_to_exclude)

      expected_paths = {
        {path_to ={"_id"}, obj =1, class ='Numeric'},
        {path_to ={"list", "quantity"}, obj =15, class = 'Numeric'}
      }
      assert.are.same(sorted(expected_paths), sorted(diff_paths))
    end)

  end)

  describe("using real redis", function()

    it('generates created_at and updated_at', function()
      ngxjor:create_collection('test', true)

      -- local queued = {}

      local start_time=os.time()
      for _=1, 5 do
         ngxjor:insert("test", { code = 'foo' })
      end
      -- local end_time=os.time()
      local f = ngxjor:find('test', {})
      for _, v in ipairs(f) do
         assert.is.truthy(v._created_at)
         assert.is.truthy(v._updated_at)
         assert.are.equal('number', type(v._created_at))
         assert.are.equal('number', type(v._updated_at))
         -- print(v.created_at)
         -- assert.are.equal(true,
         --                 ((v._created_at > start_time) and
         --                  (v._updated_at > start_time) and
         --                  (v._created_at < end_time) and
         --                  (v._updated_at < end_time)))
      end
      -- created_at can be set to any value
      ngxjor:insert("test", { code = 'created_at', _created_at=start_time})
      assert.are.equal(start_time,
        ngxjor:find('test',
        {code='created_at'})[1]._created_at)

    end)

    it("inserts and finds", function()
      ngxjor:create_collection('test')
      local doc1 = create_sample_doc_restaurant({_id = 1})
      local doc2 = create_sample_doc_restaurant({_id = 2})
      local doc3 = create_sample_doc_restaurant({_id = 3})
      ngxjor:insert('test', doc1)
      ngxjor:insert('test', doc2)
      ngxjor:insert('test', doc3)

      assert.equal(3, ngxjor:count('test'))
      local a =  ngxjor:find('test', {})
      local aux = {}
      for k,v in pairs(a) do
        table.insert(aux, {k = k, v = v})
      end

      table.sort(aux, function(a,b)
        return a.k < b.k
      end)

      local found = ngxjor:find('test', {_id = 1})[1]
      table.sort(found)

      assert.equal(#doc1, #found)


      doc1._created_at, found._created_at, doc1._updated_at, found._updated_at = 0,0,0,0

      assert.are.same(doc1, found)

      -- assert.are.same(table.sort({}), table.sort({}))
      assert.are.same({}, {})

      -- assert.are.same({doc2}, ngxjor:find('test', {_id = 2}))
      -- assert.are.same(doc3, ngxjor:find('test', {_id = 3}))
    end)

    it('index boolean fields', function()

          ngxjor:create_collection('test')

          ngxjor:insert('test', { _id=1, foo='bar', is_true=true, is_false=false})
          ngxjor:insert('test', { _id=2, foo='bar', is_true=true, is_false=false})
          local res = ngxjor:find('test', {})
          assert.equal(true, res[1].is_true)
          assert.equal(false, res[1].is_false)

          -- finds booleans
          assert.equal(2, #(ngxjor:find('test', {is_true=true})))
          assert.equal(2, #(ngxjor:find('test', {is_false=false})))
          -- not strings
          assert.equal(0, #(ngxjor:find('test', {is_false='false'})))
          assert.equal(0, #(ngxjor:find('test', {is_true='true'})))

          -- test non-matches
          assert.equal(0, #(ngxjor:find('test', {is_true=false})))
          assert.equal(0, #(ngxjor:find('test', {is_false=true})))

          local all = ngxjor:find('test', {is_true = {['$in'] = {true, false}}})
          assert.equal(2, #all)
          local first = all[1]
          local second = all[2]

          -- print(inspect(all))

          assert.equal(1, first._id)
          assert.equal(2, second._id)
       end)

    it("sorts the results by _id", function()

      ngxjor:create_collection('test')

      ngxjor:insert('test', { _id=1, foo='one'})
      ngxjor:insert('test', { _id=2, foo='two'})
      for i=3, 25 do
        ngxjor:insert('test', { _id=i, foo=tostring(i)})
      end

      local res = ngxjor:find('test', {}, {reversed = false})
      assert.equal('one', res[1].foo)
      assert.equal('two', res[2].foo)

      local res = ngxjor:find('test', {})
      for i=1, 25 do
        assert.equal(i, res[i]._id)
      end

      local res = ngxjor:find('test', {}, {reversed = true})

      for i=1, 25 do
        assert.equal(26-i, res[i]._id)
      end
    end)

    it("deletes elements", function()
         ngxjor:create_collection('test')

         ngxjor:insert('test', { _id=1, foo='one'})
         ngxjor:insert('test', { _id=2, foo='two'})

         for i=3, 25 do
           ngxjor:insert('test', { _id=i, foo=tostring(i)})
         end

         ngxjor:delete('test', {}, {max_documents = 24})

         local res = ngxjor:find('test', {}, {reversed = true})
         assert.equal(1, #res)
         assert.equal(25, res[1]._id)
    end)

    it("deletes elements via wipe with deleted indices", function()
         ngxjor:create_collection('test')

         ngxjor:insert('test', { _id=1, foo='one'})
         ngxjor:delete_reverse_indices('test', 1)

         ngxjor:wipe_object('test', 1)
         assert.equal(0, #ngxjor:find('test', { _id = 1 }))
    end)

    it("finds element with deleted indices", function()
      ngxjor:create_collection('test')

      ngxjor:insert('test', { _id=1, foo='one'})

      assert.equal(1, #ngxjor:find('test', { _id = 1 }))
      ngxjor:delete_reverse_indices('test', 1)
      assert.equal(1, #ngxjor:find('test', { _id = 1 }))

      ngxjor:wipe_object('test', 1)
    end)

    it("change all indexes", function()
      ngxjor:create_collection('test')

      ngxjor:insert('test', { _id=1, foo=true})
      ngxjor:update('test', { _id=1 }, {foo=false})

      assert.equal(1, #ngxjor:find('test', { foo = false }))
      assert.equal(0, #ngxjor:find('test', { foo = true }))

      ngxjor:delete_collection('test')
    end)
  end)

  describe('Security checks', function()
    it('validates collection names', function()
      for _,name in ipairs({'ac/dc', 'the darkness', '@ueen', ''}) do
        assert.is_nil(ngxjor:create_collection(name))
      end
    end)
  end)

  describe('differenciation of a/aa', function()
    it('#focus diferences object structure from jor structure in keys', function()
      ngxjor:create_collection('test')
      ngxjor:create_collection('te')

      ngxjor:insert('test', { _id=2, level='zero'})
      ngxjor:insert('te',   { st      = 'hi',       _id=1, level='one' })
      ngxjor:insert('te',   { ['s/t'] = 'please',   _id=2, level='two' })
      ngxjor:insert('te',   { s = { t = 'please' }, _id=3, level='three' })
      ngxjor:insert('te',   { s = { t = 'bye' },    _id=4, level='four' })

      assert.equal(ngxjor:find('te', {_id = 1})[1]['st'],  'hi')
      assert.equal(ngxjor:find('te', {_id = 2})[1]['s/t'], 'please')
      assert.equal(ngxjor:find('te', {_id = 3})[1].s.t,    'please')
      assert.equal(ngxjor:find('te', {_id = 4})[1].s.t,    'bye')

      assert.equal(ngxjor:find('te', {st = 'hi'})[1]._id,           1)
      assert.equal(ngxjor:find('te', {['s/t'] = 'please'})[1]._id,  2)
      assert.equal(ngxjor:find('te', {s = {t = 'please'}})[1]._id,  3)
      assert.equal(ngxjor:find('te', {s = {t = 'bye'}})[1]._id,     4)
    end)
  end)
end)
