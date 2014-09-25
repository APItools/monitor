angular.module('slug.analytics', ['angulartics', 'angulartics.segment.io'])
.factory 'errorception', ($window) ->
  (error) ->
    $window._errs?.allow ||= -> $window.navigator.userAgent.indexOf("Conkeror") == -1
    if $window.location.hostname != 'localhost' then $window._errs?.push(error)

# Compatability with ui-router
.run ($analytics, $rootScope, $location, $window) ->
  $analytics.settings.pageTracking.autoTrackFirstPage = false

  $rootScope.$on '$stateChangeSuccess', (event,
                                         toState, toParams,
                                         fromState, fromParams) ->
    return unless $analytics.settings.pageTracking.autoTrackVirtualPages
    # TODO: check for redirects?
    $analytics.pageTrack($location.path())

  if $location.host() == 'localhost'
    $analytics.pageTrack = (page) ->
      console.log("$analytics.pageTrack(#{page})")
    $analytics.eventTrack = (event, properties) ->
      console.log("$analytics.eventTrack(#{event}, #{properties})")
  else
    [host, service, user] = $location.host().match(/^(\w+\-)?(\w+)/)
    $window.analytics?.identify(user, username: user)

if angular.mock
  angular.module('ngMock').provider
    $analytics:
      $get: ->
        {
          eventTrack: ->
          pageTrack: ->
          settings: {
            pageTracking: {}
          }
        }
