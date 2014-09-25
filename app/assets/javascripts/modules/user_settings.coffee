angular.module('slug.user_settings', ['ngResource'])
.factory 'UserSettings', (StoredUserSettings, $q) ->
  deferred = $q.defer()
  resolve = -> deferred.resolve(settings)
  reject = (reason) -> deferred.reject(reason)

  cache = StoredUserSettings.get(resolve, reject)

  saveCache = ->
    deferred = $q.defer()
    settings.$promise = deferred.promise
    cache.$save(resolve, reject)

  settings = {
    $promise: deferred.promise
    get: (property, callback) ->
      if callback
        cache.$promise.then (cache) ->
          callback(cache[property])
      else
        cache[property]

    extend: (object) ->
      angular.extend(cache, object)
      saveCache()

    set: (property, value) ->
      cache[property] = value
      saveCache()

    raw: cache

    reset_settings: () ->
      deferred = $q.defer()
      settings.$promise = deferred.promise

      cache.$delete ->
        cache = StoredUserSettings.get(reject, resolve)
  }

.factory 'StoredUserSettings', ($resource) ->
  $resource '/api/config'
