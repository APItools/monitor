describe 'Documentation', ->
  beforeEach module('slug.documentation')

  it 'gets the complete hash of doc pages to urls', inject (Documentation) ->
    expect(Documentation).toBeDefined()
    expect(Documentation).toBeDefined()
    expect(Documentation['home']).toBeDefined()
