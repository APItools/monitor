class Operator
  constructor: (@key) ->
  valueOf: -> @key
  convert: (value) -> value
  toJSON: -> @valueOf()
  toString: -> @valueOf()

class NumericOperator extends Operator
  convert: (value) -> parseFloat(value, 10)

class SetOperator extends Operator
  convert: (value, original = []) ->
    original.push(part) for part in value.split(/,\s*/)
    original

class HeuristicsOperator
  constructor: ->
    @number = new NumericOperator
  convert: (value) ->
    numeric = @number.convert(value)
    if numeric.toString() == value then numeric else value

angular.module('slug.search', [
  'slug.directives.token_input', 'slug.directives.search', 'slug.utils'
])
.factory 'FilterBar', (Token) ->
  class FilterBar
    DOT = /\./

    constructor: ->
      @type = 'basic'
      @tokens = []

    use: (filter) ->
      @reset()

      for token in filter.tokens
        @tokens.push new Token(token)

    operator: (token) ->
      switch token.op
        when '=', '==' then return null

      # numeric
      op = switch token.op
        when '>' then '$gt'
        when '>=' then '$gte'
        when '<' then '$lt'
        when '<=' then '$lte'
      return new NumericOperator(op) if op

      # sets
      op ||= switch token.op
        when '@' then '$in'
        when '|' then '$all'

      return new SetOperator(op) if op

      op

    reset: ->
      @tokens.splice(0, @tokens.length)

    query: ->
      query = {}
      tokens = _(@tokens).filter (t) -> t.active
      groups = _(tokens).groupBy (t) -> t.key

      paths = _(groups).keys().sort()

      heuristics = new HeuristicsOperator

      for path in paths
        parts = path.split(DOT)
        root = query
        partial_path = []

        for part in parts
          partial_path.push(part)
          partial = partial_path.join('.')
          prev = root
          root = (root[part] ||= {})

          if leafs = groups[partial]
            for token in leafs
              if op = @operator(token)
                root[op] = op.convert(token.value, root[op])
              else
                prev[part] = heuristics.convert(token.value)
      return query

.factory 'TokenHeuristics', (Token) ->
  class TokenHeuristics
    constructor: (collection) ->
      @collection = collection

    singular: (properties...) ->
      @_singular = properties

    singularProperties: ->
      resource = if _.isArray(@collection) then @collection[0] else @collection
      conditions = []
      for key in @_singular
        path = key.split('.')
        value = resource
        value = value?[piece] for piece in path

        if value
          conditions.push(key: key, op: '=', value: value)

      conditions

    collectionProperties: ->
      all = _.chain(@collection)
      keys = for resource in @collection
        _.keys(resource)
      common_keys = _.intersection(keys...)
      common_keys = _(common_keys).filter (key) -> !key.match(/^(\$|_)/)

      object_keys = _(common_keys).filter (key) ->
        all.pluck(key).all(_.isObject).value()

      primitive_keys = _(common_keys).without(object_keys...)

      for key in primitive_keys
        values = all.pluck(key).value()
        reference = _.first(values)
        match = _(values).all (value) -> value == reference
        if reference && match
          { key: key, op: '=', value: reference }

    suggestions: ->
      for token in @compare() when !_.isEmpty(token)
        token.suggestion = true
        new Token(token)

    compare: ->
      return @singularProperties() if not _.isArray(@collection) or
        @collection.length <= 1

      return @collectionProperties()

.factory 'ObjectURL', ($window, defer) ->
  URL = $window.URL || $window.webkitURL

  ObjectURL =
    create: URL.createObjectURL
    revoke: URL.revokeObjectURL
    defer_revoke: (url) -> defer -> ObjectURL.revoke(url)

.factory 'JSONBlob', ->
  (object) ->
    json = angular.toJson(object)
    blob = new Blob([ json ], type: 'application/json')

.factory 'Search', (FilterBar, $timeout, animationFrame, jsonify, JSONBlob, ObjectURL) ->

  class Search
    CHECK_FOR_NEW_MS = 1000

    constructor: (@resource, scope) ->
      @filter = new FilterBar()
      scope?.$on('search', this.do)
      scope?.$on('$destroy', this.stop_refresh)
      @reversed = true
      @do()

    infinite: =>
      !@loading && @results.length < @count

    last_updated: =>
      if @last_update then new Date() - @last_update else CHECK_FOR_NEW_MS

    wasChanged: ->
      not angular.equals(@query, @filter.query())

    encodedParams: (full) ->
      params = query: @json
      params.reversed = true unless @reversed
      params.last_id = @last_id('max') unless full
      params.first_id = @last_id('min') unless full

      jQuery.param(params)

    do: =>
      @query = @filter.query()
      @json = jsonify(@query)

      @count = null
      @results = []
      @load(query: @query, @replace)

    last_id: (func) =>
      func ||= if @reversed then 'min' else 'max'
      _(@results)[func]((result) -> result._id)._id

    canLoadMore: ->
      @load_more && @results.length < @count

    download: (event) ->
      blob = JSONBlob(@results)
      url = ObjectURL.create(blob)
      angular.element(event.target).attr('href', url)
      ObjectURL.defer_revoke(url)

    reverse: ->
      @reversed = !@reversed
      @load(query: @query, @replace)

    more: ->
      @load_more = false
      @loading_more = true
      @load(query: @query, last_id: @last_id(), @append)

    refresh: ->
      @load(query: @query, last_id: @last_id('max'), reversed: false, @prepend)

    noResults: ->
      @query && !@loading && @results?.length == 0

    load: (params, callback) ->
      @stop_refresh()

      # angular would serialize it without keys starting with $
      params.query = jsonify(params.query)

      @loading = true

      if params.reversed? && !params.reversed
        delete params.reversed
      else if @reversed
        params.reversed = @reversed

      @has_more = false

      @resource.count params, (results) =>
        @count ||= results.document_count

      @resource.search params, (results) =>
        @loading = false
        @loading_more = false
        @last_update = new Date()
        callback?(results)
        @stop_tick = @ticker(params)

    replace: (results) =>
      @results = results

    prepend: (results) =>
      @results.unshift(result) for result in results

    append: (results) =>
      @results.push(result) for result in results

    stop_refresh: =>
      @stop_tick?()
      $timeout.cancel(@last_timer)

    ticker: (params) =>
      enabled = true

      tick = =>
        params.last_id = @last_id('max')
        @resource.count params, (count) =>
          @has_more = count.document_count

          if enabled
            animationFrame.withFallback =>
              @last_timer = $timeout(tick, CHECK_FOR_NEW_MS)

      tick() if @reversed
      -> enabled = false


    tokens: => @filter.tokens

    remove: (results) ->
      results = if _.isArray(results) then results else [results]
      original = @results.length
      @results = _(@results).without(results...)
      removed = original - @results.length
      @count -= removed

    use: (filter) ->
      @stop_refresh()
      @filter.use(filter)
      @using_filter = filter
      @do()

    clear: ->
      @stop_refresh()
      @filter.reset()
      @using_filter = null
      @do()
