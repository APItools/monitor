require 'jor_destroy_all'

module JORHelper
  def redis
    @redis ||= Redis.new(driver: :hiredis)
  end

  def jor
    @jor ||= JOR::Storage.new(redis)
  end
end
