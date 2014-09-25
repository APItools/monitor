describe "BrainMiddlewareSearch Service", ->

  [BrainMiddlewareSearch, $httpBackend] = []

  beforeEach module('slug.middlewares')
  beforeEach inject (_BrainMiddlewareSearch_, _$httpBackend_) ->
    $httpBackend = _$httpBackend_
    BrainMiddlewareSearch = _BrainMiddlewareSearch_

  afterEach ->

    $httpBackend.verifyNoOutstandingExpectation()
    $httpBackend.verifyNoOutstandingRequest()

  it 'does middleware spec search from brain', ->
    search = BrainMiddlewareSearch('endpoint')

    search.query = 'burning'

    $httpBackend
      .expectGET('/api/brain/middleware_specs/search?endpoint=endpoint&page=1&per_page=4&query=burning')
      .respond([
        {
          id: 4
          name: "Burningman categorize events"
        }
        {
          id:5
          name:"Burningman demultiply events"

        }])
    $httpBackend
      .expectGET('/api/brain/middleware_specs/search?endpoint=endpoint&page=2&per_page=4&query=burning')
      .respond([])

    search.find()
    search.loadMore()
    expect(search.loading).toBe true

    $httpBackend.flush()
    expect(search.loading).toBe false
    expect(search.specs.length).toBe 2
