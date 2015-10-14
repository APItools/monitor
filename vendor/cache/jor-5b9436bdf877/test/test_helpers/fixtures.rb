module TestHelpers
  module Fixtures

    def create_sample_doc_cs(partial_doc = {})
      doc = {
        "_id" => 1,
        "name" => {
                   "first" => "John",
                   "last" => "Backus"
                 },
        "birth" => Time.mktime("1924","12","03","05","00","00").to_i,
        "death" => Time.mktime("2007","03","17","04","00","00").to_i,
        "contribs" => [ "Fortran", "ALGOL", "Backus-Naur Form", "FP" ],
        "awards" => [
                    {
                      "award" => "W.W. McDowellAward",
                      "year" => 1967,
                      "by" => "IEEE Computer Society"
                    },
                    {
                      "award" => "National Medal of Science",
                      "year" => 1975,
                      "by" => "National Science Foundation"
                    },
                    {
                      "award" => "Turing Award",
                      "year" => 1977,
                      "by" => "ACM"
                    },
                    {
                      "award" => "Draper Prize",
                      "year" => 1993,
                      "by" => "National Academy of Engineering"
                    }
        ]
      }
      doc.merge(partial_doc)
    end

    def create_sample_doc_restaurant(partial_doc = {})
      doc = {
        "_id" => 1,
        "name" => "restaurant",
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
                   },
        ]
      }
      doc.merge(partial_doc)
    end

  end
end

Test::Unit::TestCase.send(:include, TestHelpers::Fixtures)
