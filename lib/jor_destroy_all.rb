require 'jor'
require 'timeout'
module JOR
  class Storage
    WAIT_TIMEOUT = 2

    @@async_key = [JOR::Storage::NAMESPACE, 'locks', 'async'].join('/')

    def get_async_locks
      redis.get(@@async_key)
    end

    # TODO: would be nice to have this in Lua directly
    def wait_for_async_locks
      begin
        Timeout::timeout(WAIT_TIMEOUT) do
          value = get_async_locks
          while value and value.is_a?(Array) || value.to_i > 0
            sleep(0.01)
            puts value.inspect if value.is_a?(Array)
            value = get_async_locks
          end
          return true
        end
      rescue Timeout::Error
        return false
      end
    end

    def reset!
      puts("Warning: jor reset! timed out") unless wait_for_async_locks
      force_destroy_all
    end

    def destroy_all
      unless wait_for_async_locks
        puts("Warning: jor destroy_all timed out")
      end

      force_destroy_all
    end

    def force_destroy_all
      redis.eval %(
        local keys = redis.call('keys', '#{JOR::Storage::NAMESPACE}/*')
        for _,k in ipairs(keys) do
          redis.call('del', k)
        end
        return keys
      )
    end
  end
end
