module JOR
  class Collection

    DEFAULT_OPTIONS = {
      :max_documents => 1000,
      :raw => false,
      :only_ids => false,
      :reversed => false,
      :excluded_fields_to_index => {}
    }

    def initialize(storage, name, auto_increment = false)
      @storage = storage
      @name = name
      @auto_increment = auto_increment
    end

    def name
      @name
    end

    def redis
      @storage.redis
    end

    def storage
      @storage
    end

    def auto_increment?
      @auto_increment
    end

    def insert(docs, options = {})
      raise NotInCollection.new unless name
      opt = merge_and_symbolize_options(options)

      docs.is_a?(Array) ? docs_list = docs : docs_list = [docs]

      docs_list.each_with_index do |doc, i|
        if auto_increment?
          raise DocumentDoesNotNeedId.new(name) unless doc["_id"].nil?
          doc["_id"] = next_id()
        else
          raise DocumentNeedsId.new(name) if doc["_id"].nil?
        end

        doc["_created_at"] ||= Time.now.to_f

        encd = JSON::generate(doc)
        paths = Doc.paths("!",doc)
        id = doc["_id"]

        raise InvalidDocumentId.new(id) if !id.is_a?(Numeric) || id < 0

        if !opt[:excluded_fields_to_index].nil? && opt[:excluded_fields_to_index].size>0
          excluded_paths = Doc.paths("!",opt[:excluded_fields_to_index])
          paths = Doc.difference(paths, excluded_paths)
        end

        redis.watch(doc_key(id))
        exists = redis.get(doc_key(id))

        if !exists.nil?
          redis.multi
          redis.exec
          raise DocumentIdAlreadyExists.new(id, name)
        else
          res = redis.multi do
            redis.set(doc_key(id),encd)
            redis.zadd(doc_sset_key(),id,id)
            paths.each do |path|
              add_index(path,id)
            end
          end
          raise DocumentIdAlreadyExists.new(id, name) unless exists.nil?
        end
      end
      docs
    end

    def delete(doc)
      raise NotInCollection.new unless name
      ids = find(doc, {:only_ids => true, :max_documents => -1})
      ids.each do |id|
        delete_by_id(id)
      end
      ids.size
    end

    def update(doc_dest, doc_source, options = {})
      raise NotInCollection.new unless name
      doc_source.delete("_id") unless doc_source["_id"].nil?
      opt = merge_and_symbolize_options(options)

      doc_source["_updated_at"] = Time.now.to_f
      paths_all = Doc.paths("!",doc_source)
      excluded_paths = []

      if !opt[:excluded_fields_to_index].nil? && opt[:excluded_fields_to_index].size>0
        excluded_paths = Doc.paths("!",opt[:excluded_fields_to_index])
      end

      paths_to_index = Doc.difference(paths_all, excluded_paths)

      docs = find(doc_dest, {:max_documents => -1})

      results = []

      docs.each do |doc|

        indexes_doc = redis.smembers(idx_set_key(doc["_id"]))

        to_remove = []
        indexes_doc.each do |index_doc|
          ## for each index there is, check if it's affected by the new paths
          path_to_from_index = get_path_to_from_index(index_doc)

          paths_all.each do |path|
            if path["obj"].kind_of?(NilClass)
              if path["path_to"]==path_to_from_index
                to_remove << index_doc
              elsif path_to_from_index.index("#{path["path_to"]}/")!=nil
                to_remove << index_doc
              end
            else
              if path["path_to"]==path_to_from_index
                to_remove << index_doc
              end
            end
          end
        end

        redis.pipelined do
          to_remove.each do |index|
            remove_index(index, doc["_id"])
            redis.srem(idx_set_key(doc["_id"]),index)
          end
        end

        ## now, the indexes that refer to the changed fields are gone
        new_doc = Doc.deep_merge(doc, doc_source)
        encd = JSON::generate(new_doc)

        res = redis.multi do
          redis.set(doc_key(new_doc["_id"]),encd)
          ## note that it's not paths_all but only the ones who are not excluded
          paths_to_index.each do |path|
            add_index(path,new_doc["_id"])
          end
        end

        results << new_doc

      end

      return results
    end

    def count
      raise NotInCollection.new unless name
      redis.zcard(doc_sset_key())
    end

    def find(doc, options = {})
      raise NotInCollection.new unless name
      # list of ids of the documents
      ids = []
      opt =  merge_and_symbolize_options(options)

      if opt[:max_documents] >= 0
        num_docs = opt[:max_documents]-1
      else
        num_docs = -1
      end

      ## if doc contains _id it ignores the rest of the doc's fields
      if !doc["_id"].nil? && !doc["_id"].kind_of?(Hash) && doc.size==1
        ids << doc["_id"]
        return [] if opt[:only_ids]==true && redis.get(doc_key(ids.first)).nil?
      elsif (doc == {})
        if (opt[:reversed]==true)
          ids = redis.zrevrange(doc_sset_key(),0,num_docs)
        else
          ids = redis.zrange(doc_sset_key(),0,num_docs)
        end
        ids.map!(&:to_i)
        ##ids = redis.smembers(doc_sset_key())
      else
        paths = Doc.paths("!",doc)
        ## for now, consider all logical and
        paths.each_with_index do |path, i|
          tmp_res = fetch_ids_by_index(path)
          if i==0
            ids = tmp_res
          else
            ids = ids & tmp_res
          end
        end

        ids.map!(&:to_i)
        ids.reverse! if opt[:reversed]
      end

      return [] if ids.nil? || ids.size==0

      ## return only up to max_documents, if max_documents is negative
      ## return them all (they have already been reversed)
      if opt[:max_documents] >= 0 && opt[:max_documents] < ids.size
        ids = ids[0..opt[:max_documents]-1]
      end

      ## return only the ids, it saves fetching the JSON string from
      ## redis and decoding it
      return ids if (opt[:only_ids]==true)

      results = redis.pipelined do
        ids.each do |id|
          redis.get(doc_key(id))
        end
      end

      ## remove nils
      results.delete_if {|i| i == nil}

      ## return the results JSON encoded (raw), many times you do not need the
      ## object but only the JSON string
      return results if (opt[:raw]==true)

      results.map! { |item| JSON::parse(item) }
      return results
    end

    def last_id
      if auto_increment?
        val = redis.get("#{Storage::NAMESPACE}/#{name}/next_id")
        return val.to_i unless val.nil?
        return 0
      else
        val = redis.zrevrange(doc_sset_key(),0,0)
        return 0 if val.nil? || val.size==0
        return val.first.to_i
      end
    end

    def next_id
      redis.incrby("#{Storage::NAMESPACE}/#{name}/next_id",1)
    end

    def indexes(id)
      indexes = redis.smembers(idx_set_key(id))
      res = []
      indexes.each do |ind|
        v = ind.split("!")
        str = v[1..v.size].join("!")

        v = str.split("/")
        type = v[v.size-2]
        path = v[0..v.size-3].join("/")

        if path!=""
          value_tmp = v[v.size-1]
          w = value_tmp.split("_")
          value = w[0..w.size-2].join("_")
          ## returns the value of a Numeric as string, to cast to float or int, cannot
          ## be derived from type because it Numeric
          res << {"path" => path, "obj" => type, "value" => value}
        end
      end
      return res
    end

    protected

    def merge_and_symbolize_options(options = {})
      DEFAULT_OPTIONS.merge(options.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo})
    end

    def find_docs(doc)
      return [doc["_id"]] if !doc["_id"].nil?

      ids = []
      paths = Doc.paths("!",doc)

      ## for now, consider all logical and
      paths.each_with_index do |path, i|
        tmp_res = fetch_ids_by_index(path)
        if i==0
          ids = tmp_res
        else
          ids = ids & tmp_res
        end
      end
      ids
    end

    def check_selectors(sel)
      Storage::SELECTORS.each do |type, set|
        istrue = true
        sel.each do |s|
          istrue = istrue && set.member?(s)
        end
        return type if istrue
      end
      raise IncompatibleSelectors.new(selectors)
    end

    def find_type(obj)
      [String, Numeric, TrueClass, FalseClass].each do |type|
        return type if obj.kind_of? type
      end
      raise TypeNotSupported.new(obj.class)
    end

    def fetch_ids_by_index(path)

      if path["selector"]==true
        type = check_selectors(path["obj"].keys)
        if type == :compare
          key = idx_key(path["path_to"], find_type(path["obj"].values.first))

          rmin = "-inf"
          rmin = path["obj"]["$gte"] unless path["obj"]["$gte"].nil?
          rmin = "(#{path["obj"]["$gt"]}" unless path["obj"]["$gt"].nil?

          rmax = "+inf"
          rmax = path["obj"]["$lte"] unless path["obj"]["$lte"].nil?
          rmax = "(#{path["obj"]["$lt"]}" unless path["obj"]["$lt"].nil?

          ##ZRANGEBYSCORE zset (5 (10 : 5 < x < 10
          return redis.zrangebyscore(key,rmin,rmax)
        elsif type == :sets
          if path["obj"]["$in"]
            target = path["obj"]["$in"]
            join_set = []
            target.each do |item|
              join_set = join_set | redis.smembers(idx_key(path["path_to"], find_type(item), item))
            end
            return join_set.sort
          elsif path["obj"]["$all"]
            join_set = []
            target = path["obj"]["$all"]
            target.each do |item|
              if join_set.size==0
                join_set = redis.smembers(idx_key(path["path_to"], find_type(item), item))
              else
                join_set = join_set & redis.smembers(idx_key(path["path_to"], find_type(item), item))
              end
              return [] if (join_set.nil? || join_set.size==0)
            end
            return join_set.sort
          elsif !path["obj"]["$not"].nil?
            target = path["obj"]["$not"]
            target = [target] unless target.kind_of?(Array)
            join_set = []
            target.each do |item|
              join_set = join_set | redis.smembers(idx_key(path["path_to"], find_type(item), item))
            end
            return (redis.zrange(doc_sset_key(),0,-1) - join_set).sort
          end
        end
      end

      [String, Numeric, TrueClass, FalseClass].each do |type|
        if path["obj"].kind_of?(type)
          return redis.smembers(idx_key(path["path_to"], type, path["obj"])).sort
        end
      end
      path["obj"].kind_of?(NilClass) ? [] : (raise TypeNotSupported.new(path["obj"].class))
    end

    def delete_by_id(id)
      indexes = redis.smembers(idx_set_key(id))
      v = redis.pipelined do
        indexes.each do |index|
          remove_index(index, id)
        end
        redis.del(idx_set_key(id))
        redis.zrem(doc_sset_key(),id)
        redis.del(doc_key(id))
      end
    end

    def remove_index(index, id)
      v = index.split("_")
      key = v[0..v.size-2].join("_")
      if v.last=="srem"
        redis.srem(key, id)
      elsif v.last=="zrem"
        redis.zrem(key, id)
      else
        raise UnknownIndex.new(index,id)
      end
    end

    def add_index(path, id)
      [String, Numeric, TrueClass, FalseClass].each do |type|
        if path["obj"].kind_of?(type)
          key = idx_key(path["path_to"], type, path["obj"])
          redis.sadd(key, id)
          redis.sadd(idx_set_key(id), "#{key}_srem")
          if type==Numeric
            key = idx_key(path["path_to"], type)
            redis.zadd(key, path["obj"], id)
            redis.sadd(idx_set_key(id), "#{key}_zrem")
          end
          return true
        end
      end
      path["obj"].kind_of?(NilClass) ? true : (raise TypeNotSupported.new(path["obj"].class))
    end

    def get_path_to_from_index(index)
      ## this traverses all indexes, Numeric fields have two actual indexes that do not
      ## appear on the indexes method
      ini_pos = index.index("/!")
      ini_pos += 1

      end_pos = index.index("/String")
      end_pos = index.index("/Numeric") if end_pos.nil?
      end_pos = index.index("/TrueClass") if end_pos.nil?
      end_pos = index.index("/FalseClass") if end_pos.nil?

      raise CouldNotFindPathToFromIndex.new(index) if ini_pos.nil? || end_pos.nil?
      end_pos -= 1

      return index[ini_pos..end_pos]
    end

    def idx_key(path_to, type, obj = nil)
      tmp = ""
      tmp = "/#{obj}" unless obj.nil?
      "#{Storage::NAMESPACE}/#{name}/idx/#{path_to}/#{type}#{tmp}"
    end

    def idx_set_key(id)
      "#{Storage::NAMESPACE}/#{name}/sidx/#{id}"
    end

    def doc_key(id)
      "#{Storage::NAMESPACE}/#{name}/docs/#{id}"
    end

    def doc_sset_key()
      "#{Storage::NAMESPACE}/#{name}/ssdocs"
    end

  end
end
