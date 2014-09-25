angular.module('slug.filters', [])

.filter 'moment', ->
  # FIXME: this is very inefficient now, it evaluates each time in digest phase
  (time, format = 'LLLL') -> moment.utc(time).format(format)

.filter 'unix', ->
  (input) -> moment.unix(input).valueOf()

.filter 'truncate', ->
  (input, length) ->
    return unless input
    input = String(input)
    return input if !input or input?.length <= length
    input.substring(0, length) + "..." # use &hellip; somehow, maybe UTF-8 char?

.filter 'ms', ->
  (input) -> if input then "#{Math.round(input * 1000)} ms" else 'cached'

.filter 'status', ->
  (input) ->
    switch
      when 300 > input >= 100
        'success'
      when 400 > input >= 300
        'redirect'
      when 500 > input >= 400
        'client-error'
      when 600 > input >= 500
        'server-error'
      else
        'unknown'
