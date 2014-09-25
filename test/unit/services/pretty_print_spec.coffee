describe 'prettyPrint', ->
  [prettyPrint] = []

  beforeEach module('slug.services.pretty_print')
  beforeEach inject (_prettyPrint_) ->
    prettyPrint = _prettyPrint_

  it 'parses json', ->
    json = '{"a":"b"}'
    pretty = prettyPrint('application/json', json)
    expect(pretty).toBe('{\n  "a": "b"\n}')
