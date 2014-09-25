describe 'Middlewares', ->
  [middlewares] = []

  beforeEach module('slug.middlewares')
  beforeEach inject (Middlewares) ->
    middlewares = (middlewares) -> new Middlewares(middlewares)

  it 'can be compared with a number', ->
    empty = middlewares({})
    expect(+empty).toBe(0)

    full = middlewares({one: {position: 1}})
    expect(+full).toBe(1)

    expect(full > 0).toBe(true)
    expect(full >= 1).toBe(true)

