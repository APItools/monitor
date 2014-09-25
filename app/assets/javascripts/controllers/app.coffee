angular.module('slug.controllers')

.factory 'System', ($http) ->
  initialize: -> $http.post('/api/system/initialize')
  reset: -> $http.post('/api/system/reset')

.controller 'AppController', ($scope, Service, System, $http) ->
  System.initialize()

  $http(method: 'GET', url: '/api/brain').success (data) ->
    $scope.brain = data.host
