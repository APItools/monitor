require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

module JOR
  module Test
    module Unit
      class TestCase < ::Test::Unit::TestCase
        def setup
          @safe_to_remove = false
          if Redis.new(:db => 9, :driver => :hiredis).keys("*").size>0
            puts "Cannot run the tests safely!! The test DB (:db => 9) is not empty, and the test will flush the data. Stopping. Clean the data manually first: redis-cli; select 9; flushdb;"
            exit(-1)
          end
          @safe_to_remove = true
        end
      end
    end
  end
end