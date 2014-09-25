
module SimpleFixturesHelper

  def load_fixture(collection, fixture_name, auto_increment = false)
    path = File.join("spec", "fixtures" , collection, "#{fixture_name}.json")
    json = load_json_from_file(path)
    if auto_increment
      json.delete('_id')
    end
    # auto_increment = !json.has_key?('_id')
    jor.create_collection(collection, :auto_increment => auto_increment) rescue nil

    fixture = jor.send(collection).insert(json)
    # cjson decoding in lua rounds _created_at to just 4 decimal places
    fixture['_created_at'] = fixture['_created_at'].round(4)
    fixture
   end

  def sans_created_at(obj)
    return obj.delete_if{ |k,v| k == '_updated_at' or k == '_created_at' } if obj.is_a? Hash
    return obj.map{|o| sans_created_at(o)} if obj.is_a? Array
    obj
  end

  private

  def load_json_from_file(file_path)
    JSON.parse(IO.read(file_path))
  end

end
