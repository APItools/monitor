
module JOR
  class Error < RuntimeError
  end

  class NoResults < Error
    def initialize(doc)
      super %(no results found for "#{doc}")
    end
  end

  class TypeNotSupported < Error
    def initialize(class_name)
      super %(Type #{class_name} not supported)
    end
  end

  class InvalidFieldName < Error
    def initialize(field)
      super %(Invalid character in field name "#{field}". Cannot start with '_' or '$')
    end
  end

  class InvalidDocumentId < Error
    def initialize(id)
      super %(The document "_id" must be a positive integer (>=0), #{id} is not valid)
    end
  end

  class DocumentIdAlreadyExists < Error
    def initialize(id, name)
      super %(A document with _id #{id} already exists in collection "{name}")
    end
  end

  class DocumentNeedsId < Error
    def initialize(name)
      super %(The collection #{name} is not auto-incremental. You must define the "_id" of the document")
    end
  end

  class DocumentDoesNotNeedId < Error
    def initialize(name)
      super %(The collection #{name} is auto-incremental. You must not define the "_id" of the document")
    end
  end

  class IncompatibleSelectors < Error
    def initialize(str)
      super %(Incompatible selectors in "#{str}". They must be grouped like this #{Storage::SELECTORS})
    end
  end

  class NotInCollection < Error
    def initialize
      super %(The current collection is undefined)
    end
  end

  class CollectionDoesNotExist < Error
    def initialize(str)
      super %(Collection "#{str}" does not exist)
    end
  end

  class CollectionAlreadyExists < Error
    def initialize(str)
      super %(Collection "#{str}" already exists)
    end
  end

  class CollectionNotValid < Error
    def initialize(str)
      super %(Collection "#{str}" is not a valid name, might be reserved)
    end
  end

  class FieldIdCannotBeExcludedFromIndex < Error
    def initialize
      super %(Field _id cannot be excluded from the index)
    end
  end

  class CouldNotFindPathToFromIndex < Error
    def initialize(str)
      super %(Could not find path_to from index #{str})
    end
  end

  class CouldNotFindPathToFromIndex  < Error
    def initialize(index, id)
      super %(Unknown index #{index} in document #{id})
    end
  end

end