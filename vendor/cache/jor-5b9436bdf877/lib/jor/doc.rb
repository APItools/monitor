
module JOR
  class Doc

    def self.paths(path,h)
      if h.class==Hash
        v = []
        h.each do |k,val|
          if JOR::Storage::SELECTORS_ALL.member?(k)
            return [{"path_to" => path, "obj" => h, "class" => h.class, "selector" => true}]
          else
            raise InvalidFieldName.new(k) if ((k!="_id") && (k!="_created_at") && (k!="_updated_at")) && (k[0]=="_" || k[0]=="$")
            v << paths("#{path}/#{k}",val)
          end
        end
        return v.flatten
      else
        if h.class==Array
          v = []
          if h.size>0
            h.each do |item|
              v << paths("#{path}",item)
           end
          else
            v << ["#{path}"]
          end
          return v.flatten
        else
          return [{"path_to" => path, "obj" => h, "class" => h.class}]
        end
      end
    end

    def self.difference(set, set_to_substract)
      return set if set_to_substract.nil? || set_to_substract.size==0

      to_exclude = []
      set_to_substract.each do |item|
        raise FieldIdCannotBeExcludedFromIndex.new unless item["path_to"].match(/\/_id/)==nil
        to_exclude << Regexp.new("^#{item["path_to"]}")
      end

      res = []
      set.each do |item|
        not_found = true
        to_exclude.each do |re|
          not_found = not_found && re.match(item["path_to"])==nil
        end
        res << item if not_found
      end
      return res
    end

    def self.deep_merge(dest, source)
      res = Hash.new
      dest.merge(source) do |key, old_v, new_v|
        res[key] = ((old_v.class == Hash) && (new_v.class == Hash))  ? deep_merge(old_v, new_v) : new_v
      end
    end

  end
end