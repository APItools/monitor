
module JOR
  class Server

    def initialize(redis = nil)
      ## defaults to test db on redis
      redis ||= Redis.new(:db => 9, :driver => :hiredis)
      @jor = JOR::Storage.new(redis)
    end

    def call(env)
      req = Rack::Request.new(env)
      method = req.path

      if env["REQUEST_METHOD"]!="PUT"
        return [422, {"Content-Type" => "application/json"}, [{"error" => "only method accepted is PUT"}.to_json]]
      end

      clean_methods = method.gsub("/","").split(".")
      clean_methods.map!(&:to_sym)

      args = req.params["args"]
      clean_args = []
      body_str = req.body.read
      clean_args = JSON::parse(body_str) unless body_str.nil? || body_str.empty?

      begin
        obj = @jor
        res = nil

        clean_methods.each_with_index do |meth, i|
          if i==clean_methods.size()-1
            res = obj.public_send(meth,*clean_args)
          else
            obj = obj.public_send(meth)
          end
        end

        if res.class==Hash || res.class==Array
          return [200, {"Content-Type" => "application/json"}, [res.to_json]]
        else
          return [200, {"Content-Type" => "application/json"}, [{"value" => res}.to_json]]
        end
      rescue Exception => e
        return [422, {"Content-Type" => "application/json"}, [{"error" => e.message}.to_json]]
      end
    end
  end
end



