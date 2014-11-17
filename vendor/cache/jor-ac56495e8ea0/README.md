
# JOR

## Description

**JOR** is the acronym for **J**SON **o**ver **R**edis. 

The project provides storage for JSON documents that uses Redis as the backend data-store. JOR also provides a MongoDB-like query language for fast retrieval. JOR is heavily inspired by the API of MongoDB. 

JOR aims to only offer: 

* CRUD for JSON documents, and 
* a JSON based query language to find the documents matching the constrains of the query document

For instance, the document

	doc = {
        "_id" => 42,
        "name" => "bon menjar",
        "stars" => 3,
        "cuisine" => ["asian", "japanese"],
        "address" => {
                       "address" => "Main St 100",
                       "city"    => "Ann Arbor",
                       "zipcode" => "08104"
                     },
        "description" => "very long description that we might not want to index",
        "wines" => [
                   {
                     "name" => "wine1",
                     "year" => 1998,
                     "type" => ["garnatxa", "merlot"]
                   },
                   {
                      "name" => "wine2",
                      "year" => 2009,
                      "type" => ["syrah", "merlot"]
                   }
        ]
  	}

can be inserted like this:

	jor.create_collection("restaurants")
	jor.restaurants.insert(doc)

and retrieved by using a query (that is also a document). For instance:

	jor.restaurants.find({})

will return all documents in the `restaurants` collection. 

	jor.restaurants.find({"_id" => 42})

will return all documents whose `_id` is 42. The query document can be arbitrarily complex:

	jor.restaurants.find({
		"stars" => {"$gte" => 3}, 
		"wines" => {"type" => 
				{"$in" => ["garnatxa", "syrah"]}}
	})

the `find` will return restaurants with 3 or more stars that also have wines of type
garnatxa or syrah.

## Getting Started

### Installation

From rubygems

	gem install jor

From source

	git clone https://github.com/solso/jor.git
	build jor.gemspec
	gem install 


### Initialize

You can pass the your own redis handler on instantiation…

	require 'jor'
		
	redis = Redis.new(:driver => :hiredis)
	jor = JOR::Storage.new(redis)
		
if you don't, JOR will create a redis connection against redis' default (localhost, port 6379). 

We advise using `hiredis` to improve performance.

JOR is not thread-safe at the current version.

## How to

### Collections

JOR allows to have multiple **collections**. A collections is a container of documents that are mean to be group together. The operations `insert`, `delete` and `find` are scoped by a collection.

To create a collection:

	jor.create_collection("restaurants") 

Number of documents in collection:

	jor.restaurant.count()
	
Id of the last document inserted in the collection, zero if empty

  jor.restaurant.last_id()

Delete a collection with all its documents:

	jor.destroy_collection("restaurants")

Delete all collections:

	jor.destroy_all()

Collections can be created to have **auto_incremental** ids

	jor.create_collection("events", :auto_increment => true)
  
A collection is either auto_incremental or not, cannot be both types at the same time. The default type is not auto-incremental.

Auto-incremental collections expect documents without the field `_id`, which will be assigned automatically upon insertion.

### Insert

To insert documents to a collection just do `insert`. The parameters can be either a `Hash` (will be stored as JSON encoded string), or an `Array` of `Hash` objects

	jor.restaurant.insert(doc)
	jor.restaurant.insert([doc1, doc2, …, docN])

There is marginal benefits to use bulk insertion, it's mostly for convenience.

Every document stored in JOR has an field called **´_id´** that is unique within a collection. Trying to insert a document with an `_id` that already exists will raise an exception.

The `_id` must be a natural number (>=0), remember that you only need to define the field `_id` when dealing with collections that are not auto-incremental (the default case).

By the way, field names cannot start with `'` or with `$`. These characters are reserved.

There are two other special fields:

* `_created_at`: it is set when inserting a document, and should not changed ever again. The field is indexed by default.
* `_updated_at`: it is set every time the document is updated. Also indexed by default. 

Both times are unix epoch time in milli-seconds (the decimal part).

#### Options:

`:exclude_fields_to_index`

If you know that you will never do a search for a field you might want to exclude it from the indexes. By default all fields are indexes. Adding fields to be excluded improves the efficiency of the insert.

For instance, if you want to exclude the field `description` from the index:

	jor.restaurant.insert(doc, 
      	{:excluded_fields_to_index => {"description" => true}})

Excluding fields is something to consider because the performance of the insert in linear with the number of fields of the document O(#fields). An excluded fields will not affect the content of the document, it will just make it not "findable".

We advise to exclude any fields that is a string that does not serve as a symbol or tag since strings fields can only be found by a exact match.

You can also exclude fields that are objects, for instance, if you do not want to index the types of wines:

	jor.restaurant.insert(doc, 
      	{:excluded_fields_to_index => {"wines" => {"type" => true}}})
      	
Exclusion is per document based, it will only affect the document being inserted.

The field `_id` cannot be excluded.

Note that if you exclude a field from the index you will not be able to use that field on `find` operations. Search is only done over indexed fields. Unless explicitly stated all fields of the documents are indexed. 


### Find

To retrieve the stored documents you only need to define a query document (also a Hash). The interface is inspired on the MongoDB query language, so if you are familiar with it will be straight forward.

	jor.restaurant.find({})

will find all restaurants in the collection. The query document is all `{}`.

The query document `{"_id" => 42}` will only return one (or zero) restaurant documents. The one whose field `_id` has value 42. 

The query document is a subset of the original stored document. For the fields defined, it will match the value. For those who are not defined, it will act as a wildcard.

Some `operators` are also available:

* For comparisons:
	* **$gt**: greater than (>)
	* **$gte**: greater than or equal (>=) 
	* **$lt**: lower than (<)
	* **$lte**: lower than or equal (<=)

* For sets:
	* **$in**: the value must be in the defined set
	* **$all**: all values must be in the defined set

The syntax to use the `operators` also follows a hash 

	jor.restaurants.find({
		"stars" => {"$gte" => 3}, 
		"wines" => {
			"year" => 2008,
			"type" => {
			  "$all" => ["garnatxa", "syrah"]
			}
		}		
	})

The query document will return all documents that match all 3 conditions:

The field `start` must be greater or equal than 3, they have at least one `wine` that is from `year` 2008 and the `type` of wine contains both garnatxa and syrah (turns out that wines can be mixed)

The following `find` returns all documents whose `_id` is on the list

	jor.restaurants.find({"_id" => {"$in" => [1, 3, 5, 7, 11]}})

The result of the `find` in an Array of the documents (as Hash objects). The documents are returned by ascending `_id`. 

#### Options:

`find` accepts the following options that you can override:

* `:max_documents`, the maximum number of documents to be returned, by default 1000.
* `:only_ids`, return only the ids instead of the Hash, by default false. This is useful for joins.
* `:raw`, returns only the document as JSON encoded strings, you save JOR to do the final parsing of the JSON encoded string. By default false.
* `:reversed`, returns the documents sorted by descendant `_id`. Default if false.


### Delete

Deleting a document is basically like doing a `find` with the exception that all documents that meet the query document will be deleted.

	jor.restaurants.find({"_id" => 42})

Deletes the document with `_id` 42 (only one document by definition).

	jor.restaurants.delete({"address" => {"zipcode" => "08104"}})

Deletes any document that the `zipcode` on its `address` is "08104".


### Update

Updating a document is also doing a `find` and doing a deep merge of the documents found and the source doc. For instance,

	jor.restaurants.update({"_id" => 42}, {"address" => {"zipcode" => "08105"}})
 
Updates (or add if did not exist) the `address` => `zipcode` of the document with `_id` 42.

	jor.restaurants.update({"address" => {"zipcode" => "08105"}} , {"address" => {"zipcode" => "08106"}})

Updates all documents with `zipcode` "08105" to "08106". Updates are __not__ limited to a single document. The update applies
to all the documents that match the first argument of the `update` operation.

Indexes are managed in the same way than an `insert` operations, so that you can use `:exclude_fields_to_index` as options.

If the update is a removal of a field, you must do it like this:

	jor.restaurants.update({"_id" => 42}, {"address" => nil)
  
Note that this will remove all the fields that hang from `address`, whether it is a value, array or a hash.    
  
### Misc Operations

You can find which document fields are indexed by doing,

	jor.restaurants.indexes(doc_id)
	
This operation will return all fields that are indexed, but not all the indexes there are. Numeric fields, for instance, have two indexes.	
  
Also, you can get sysadmin related info,

	jor.info()
  
 
## Benchmarks

The thing is quite fast (thanks to Redis). 

With a commodity laptop (macbook air) we can get between 300~400 documents inserts per second for the restaurant example used in this README.

The complexity of an `insert` and `find` operations depend on the number of fields of the document and the query document respectively. For the case of the restaurant document there are 16 fields.

Real benchmarks are more than welcomed.

## To Do

* normalize indexed strings (downcase, trimmed, something else) so that at least the == on a string is case insensitive. Tokenizing a string is easy to do, but can affect performance O(#fields + #words_on_string_fields). Perhaps as an option.

## Contribute

Fork the [project](http://github.com/solso/jor/) and send pull requests. 






