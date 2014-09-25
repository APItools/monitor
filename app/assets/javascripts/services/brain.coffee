angular.module('slug.services.brain', [])

.factory 'Brain', ($http) ->
  brain = { $promise: $http(method: 'GET', url: '/api/brain') }

  brain.$promise.success (data) ->
    brain.host = data.host

  brain

.factory 'OnPremise', ($http) ->
  register: (uuid) ->
    $http.post('/api/brain/register', uuid: uuid)

  link: (key) ->
    $http.post('/api/brain/link', key: key)

  unlink: ->
    $http.post('/api/brain/unlink', {})
