beforeEach ->
  jasmine.addMatchers
    toEqualData: ->
      compare: (actual, expected) ->
        pass: angular.equals(actual, expected)
