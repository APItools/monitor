
module JOR
  class Storage

    NAMESPACE = "jor"

    SELECTORS = {
      :compare => ["$gt","$gte","$lt","$lte"],
      :sets => ["$in","$all","$not"]
    }

    SELECTORS_ALL = SELECTORS.keys.inject([]) { |sel, element| sel | SELECTORS[element] }

    def initialize(redis_client = nil)
      redis_client.nil? ? @redis = Redis.new() : @redis = redis_client
    end

    def redis
      @redis
    end

    def collections
      redis.smembers("#{Storage::NAMESPACE}/collections")
    end

    def create_collection(name, options = {:auto_increment => false})
      options = {:auto_increment => false}.merge(options.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo})
      raise CollectionNotValid.new(name) if self.respond_to?(name)
      is_new = redis.sadd("#{Storage::NAMESPACE}/collections",name)
      raise CollectionAlreadyExists.new(name) if (is_new==false or is_new==0)
      redis.set("#{Storage::NAMESPACE}/collection/#{name}/auto-increment", options[:auto_increment])
      name
    end

    def destroy_collection(name)
      coll_to_be_removed = find_collection(name)
      coll_to_be_removed.delete({})
      redis.pipelined do
        redis.srem("#{Storage::NAMESPACE}/collections",name)
        redis.del("#{Storage::NAMESPACE}/collection/#{name}/auto-increment")
      end
      name
    end

    def destroy_all()
      collections.each do |col|
        destroy_collection(col)
      end
    end

    def info
      res = {}
      ri = redis.info

      res["used_memory_in_redis"] = ri["used_memory"].to_i
      res["num_collections"] = collections.size

      res["collections"] = {}
      collections.each do |c|
        coll = find_collection(c)
        res["collections"][coll.name] = {}
        res["collections"][coll.name]["num_documents"] = coll.count
        res["collections"][coll.name]["auto_increment"] = coll.auto_increment?
      end

      res
    end

    protected

    def method_missing(method)
      find_collection(method)
    end

    def find_collection(method)
      redis_auto_incr = redis.get("#{Storage::NAMESPACE}/collection/#{method}/auto-increment")
      if (redis_auto_incr=="true")
        auto_increment = true
      elsif (redis_auto_incr=="false")
        auto_increment = false
      else
        raise CollectionDoesNotExist.new(method.to_s)
      end
      Collection.new(self, method, auto_increment)
    end

  end
end
