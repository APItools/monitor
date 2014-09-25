angular.module('slug.services.demo', ['slug.service', 'slug.services'])

.factory 'DemoService', (Service, uuid) ->
  create: (demo, callback) ->
    endpoints = [ {url: demo.endpoint, code: demo.key} ]

    service =
      name: "#{demo.name} API",
      description: demo.description,
      endpoints: endpoints,
      demo: demo.key

    Service.save(service, callback)

  update: (service, demo) ->
    endpoints = [ {
      url: demo.endpoint,
      code: demo.key + uuid().substr(0, 8)
    } ]
    angular.extend service,
      name: "#{demo.name} API",
      description: demo.description,
      endpoints: endpoints, demo: demo.key

.factory 'DemoApis', ->
  apis = [
    {
      key: 'echo',
      name: 'Echo',
      img: 'echo.png',
      endpoint: 'https://echo-api.herokuapp.com' ,
      description: 'Echo is simple service which responds for every request
        with JSON containing the request information. Like looking in the
        mirror. Useful for debugging middlewares.',
      calls: [
        {
          url: '/',
          name: 'GET /',
          method: 'GET'
        }
        {
          url: '/',
          name: 'POST /',
          method: 'POST'
        }
        {
          url: '/url',
          name: 'GET /url',
          method: 'GET'
        }
        {
          url: '/whatever',
          name: 'PUT /whatever',
          method: 'PUT'
        }
      ]
    }
    {
      key: 'github',
      name: 'GitHub',
      img: 'github.png',
      endpoint: 'https://api.github.com',
      description: 'GitHub has Hypermedia JSON API. Some parts are public &
        rate limited to 60 requests per hour. You can use OAuth to authenticate
        and use up to 5,000 requests per hour.',
      calls: [
        {
          url: '/events?per_page=1',
          name: 'Get public events',
          method: 'GET'
        }
        {
          url: '/gists/public?per_page=1',
          name: 'Get public gists',
          method: 'GET'
        }
        {
          url: '/orgs/github/events',
          name: "Get GitHub events",
          method: 'GET'
        }
        {
          url: '/gists/public',
          name: 'Get public gists',
          method: 'GET'
        }
        {
          url: '/zen',
          name: "Get a zen koan",
          method: 'GET'
        }
        {
          url: '/emojis',
          name: 'Get all emojis',
          description: 'Do you see any Teletubbies in here? Do you see a
            slender plastic tag clipped to my shirt with my name printed on it?
            Do you see a little Asian child with a blank expression on his face
            sitting outside on a mechanical helicopter that shakes when you put
            quarters in it? No?'
        }
        {
          url: '/users/vmg/starred',
          name: "Get repos starred by vmg",
          method: 'GET'
        }
        {
          url: '/repos/nginx/nginx/stargazers',
          name: "Get nginx/nginx stargazers",
          method: 'GET'
        }
        {
          url: '/repos/github/hubot/issues',
          name: "Get issues in github/hubot",
          method: 'GET'
        }
      ]
    }
    {
      key: 'facebook',
      name: 'Facebook',
      img: 'facebook.png',
      endpoint: 'https://graph.facebook.com',
      description: 'Facebook has JSON API which is mostly protected by OAuth,
        but some parts of Graph API are open.',
      calls: [
        {
          url: '/mike.shaver',
          name: 'Get info about a user',
          method: 'GET'
        }
        {
          url: '/19292868552',
          name: 'Get info about a page',
          method: 'GET'
        }
      ]
    }
    {
      key: 'reddit',
      name: 'Reddit',
      img: 'reddit.png',
      endpoint: 'http://www.reddit.com/'
      description: 'Reddit has both JSON and XML api (which is open source)
        with some open parts, but most of it is behind OAuth.',
      calls: [
        {
          url: '/user/peter/about.json',
          name: 'Get info about a user',
          method: 'GET'
        }
        {
          url: '/subreddits/new.json',
          name: 'Get new subreddits',
          method: 'GET'
        }
        {
          url: '/subreddits/search.json?q=kitten',
          name: 'Search subreddits for "kitten"',
          method: 'GET'
        }
        {
          url: '/random.json',
          name: 'Get a random subreddit',
          method: 'GET'
        }
        {
          url: '/api/username_available.json?user=peter',
          name: "Check username availability",
          method: 'GET'
        }
      ]
    }
    {
      key: 'stackexchange',
      name: 'Stack Exchange',
      img: 'stackoverflow.png',
      endpoint: 'https://api.stackexchange.com/2.1',
      description: 'Stack Exchange has JSON API which is mostly open to public
        with some parts with OAuth authentication.',
      calls: [
        {
          url: '/badges?site=stackoverflow',
          name: 'Get all badges',
          method: 'GET'
        }
        {
          url: '/answers?site=stackoverflow',
          name: 'Get lastest answers',
          method: 'GET'
        }
        {
          url: '/questions?tagged=lua&site=stackoverflow',
          name: 'Get latest Lua questions',
          method: 'GET'
        }
        {
          url: '/similar?title=get%20css%20by%20ajax&site=stackoverflow',
          name: 'Get similar questions',
          method: 'GET'
        }
        {
          url: '/tags/lua/top-askers/all_time?site=stackoverflow',
          name: 'Get top Lua askers',
          method: 'GET'
        }
        {
          url: '/tags/java/synonyms?site=stackoverflow',
          name: 'Get Java tag synonyms',
          method: 'GET'
        }
      ]
    }
    {
      key: 'wikipedia',
      name: 'Wikipedia',
      img: 'wikipedia.png',
      endpoint: 'http://en.wikipedia.org/w/api.php',
      description: 'Wikipedia has API with many output formats like: json, php,
        yaml, txt, xml, ....',
      calls: [
        {
          url: '?format=php&action=query&titles=David%20Hasselhoff',
          name: 'Get David Hasselhoff page, as PHP',
          method: 'GET'
        }
        {
          url: '?format=json&action=query&titles=Austin_powers&prop=revisions',
          name: 'Get page revisions',
          method: 'GET'
        }
        {
          url: '?format=json&action=query&titles=Earth|Wind|Fire',
          name: 'Search Earth, Wind or Fire',
          method: 'GET'
        }
        {
          url: '?format=json&action=sitematrix',
          name: 'Get sitematrix',
          method: 'GET'
        }
        {
          url: '?format=json&action=compare&fromtitle=red&totitle=green',
          name: 'Compare Red and Green',
          method: 'GET'
        }
      ]
    }
    {
      key: 'bitbucket',
      name: 'Bitbucket',
      img: 'bitbucket.png',
      endpoint: 'https://bitbucket.org/api',
      description: 'Bitbucket has JSON REST API with public access to open
        source repositories.',
      calls: [
        {
          url: '/2.0/repositories/rude/love/commits',
          name: 'Get repo commits',
          method: 'GET'
        }
        {
          url: '/1.0/repositories/rude/love/followers',
          name: 'Get repo followers',
          method: 'GET'
        }
        {
          url: '/1.0/repositories/rude/love/events',
          name: 'Get repo events',
          method: 'GET'
        }
        {
          url: '/1.0/repositories/rude/love/branches',
          name: 'Get repo branches',
          method: 'GET'
        }
      ]
    }
  ]
  _(apis).indexBy('key')

.factory 'DemoCall', ($http) ->
  perform: (service, call) ->
    params =
      url: call.url
      args: call.args
      body: call.body
      method: call.method
    $http(
      method: 'GET',
      url: "/api/services/#{service._id}/call",
      cache: false,
      params: params,
      transformResponse: []
    )

.controller 'DemoCallCtrl', ($scope, DemoCall, $analytics, uuid) ->
  updateResponse = (response) ->
    $scope.loading = false
    $scope.response = response.data
    $scope.status = response.status
    $scope.contentType = response.headers('Content-Type')?.split(';')[0]

  $scope.perform = ->
    $scope.loading = true
    call = DemoCall.perform($scope.service, $scope.call)
    call.then(updateResponse, updateResponse)
    $analytics.eventTrack('demo_call.used',
      service_id: $scope.service._id, demo: $scope.service.demo, call: $scope.call)

.directive 'demoCall', ->
  scope:
    call: '=demoCall'
    service: '=demoService'
  controller: 'DemoCallCtrl'
  template: """
            <div class="call">
              <span ng-class="{visible: response && !loading}"
                class="status-code label label-{{ status | status }}">
                {{ status }}
              </span>
              <button class="btn-call" type="button" ng-disabled="loading"
                ng-click="perform()">
                <i ng-class="{'icon-refresh': loading,
                  'icon-cloud-download': !loading}" ></i> {{ call.name }}
                  </button>


              <span class="loading" ng-show="loading">loading&hellip;</span>
                <span ng-if="response">
                  <a class="demo-response" ng-href="services/{{service._id}}/traces">
                    See response <i class="icon-chevron-right"></i>
                  </a>
                </span>
            </div>
            """
