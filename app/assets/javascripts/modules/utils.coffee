angular.module('slug.utils', [])
.factory 'deepMerge', ->
  (objects...) -> $.extend(true, objects...)

.factory 'debugMode', ($location) ->
  ->
    $location.hash() == 'debug'

.factory 'debug', (debugMode) ->
  (statement) ->
    statement() if debugMode()

.factory 'JSON', ($window) ->
  $window.JSON

.factory 'jsonify', (JSON) ->
  JSON.stringify

.factory '$loop', ($timeout) ->
    ($scope, fn, interval = 1000) ->
      $loop =
        interval: interval
        run: (args...) -> fn($loop, args...)
        schedule: (wait = $loop.interval) ->
          $loop.last_timeout = $timeout($loop.run, wait)
        listen: ($scope) ->
          $scope.$on('$destroy', $loop.destroy)
        destroy: ->
          $timeout.cancel($loop.last_timeout)

      $loop.listen($scope)
      $loop.run()
      $loop
