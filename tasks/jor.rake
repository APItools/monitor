require 'jor'
require 'hiredis'
require 'active_support/core_ext/object/blank'
require 'active_support/json'

namespace :jor do

  def redis
    @redis ||= Redis.new(driver: :hiredis)
  end

  def jor
    @jor ||= JOR::Storage.new(redis)
  end

  desc "clears all jor data"
  task :clear do
    redis = Redis.new(driver: :hiredis)
    redis.eval(
        "for _,k in ipairs(redis.call('keys', '#{JOR::Storage::NAMESPACE}/*')) do
           redis.call('del', k)
         end"
    )
  end

  desc "lists collections or lists all elements in the collection if run with collection ENV var set"
  task :dump do |t, args|
    collections = args.extras.presence
    collections ||= (ENV['collections'] || ENV['COLLECTIONS']).split(',')
    collections.map!(&:strip)

    available_collections = jor.collections
    # dump all if user passed '*'
    collections = available_collections if collections == ['*']

    collections.each do |collection|
      unless available_collections.index(collection)
        puts "jor collections are:"
        puts
        puts jor.collections
        puts
        puts "Use: rake jor:dump collections=<your-collection>"
        puts "or: rake jor:dump[your-collection,other-one]"

        exit 1
      end
    end

    pairs = collections.map do |collection|

      puts "Elements of collection #{collection} are:"

      docs = jor.send(collection).find({}, max_documents: -1).each do |doc|
        puts doc.to_json
      end

      puts

      [collection, docs]
    end

    if file = ENV['FILE']
      Pathname(file).open('w') do |f|
        f.print Hash[pairs].to_json
      end

      puts "Written json dump to #{file}"
    end
  end


  def auto_increment_key(collection)
    "#{JOR::Storage::NAMESPACE}/collection/#{collection}/auto-increment"
  end

  def auto_increment?(collection)
    case redis.get(auto_increment_key(collection))
      when 'true'
        true
      when 'false'
        false
      else
        nil
    end
  end

  def auto_increment!(collection, value)
    redis.set(auto_increment_key(collection), value.to_s)
  end

  desc "Import jor documents from a dump"
  task :import, :file do |t, args|
    file = args[:file] or raise "Missing file parameter"
    file = Pathname(file)
    json = file.read

    dump = ActiveSupport::JSON.decode(json)

    dump.each do |collection, docs|
      begin
        coll = jor.send(collection)
        auto = auto_increment?(collection)

        auto_increment!(collection, false)

        docs.each do |doc|
          begin
            coll.insert(doc)
          rescue JOR::DocumentIdAlreadyExists
            coll.update({'_id' => doc['_id']}, doc)
          end
        end
      rescue JOR::CollectionDoesNotExist
        jor.create_collection(collection)
        retry
      ensure
        auto_increment!(collection, auto)
      end
    end
  end
end
