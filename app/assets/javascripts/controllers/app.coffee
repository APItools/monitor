angular.module('slug.controllers')

.factory 'System', ($http) ->
  initialize: -> $http.post('/api/system/initialize')
  reset: -> $http.post('/api/system/reset')

.controller 'AppController', ($scope, Service, System, Brain) ->
  System.initialize()

  $scope.brain = Brain
