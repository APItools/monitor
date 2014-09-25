angular.module('slug.middleware_specs', ['ui.router'])
.config ($stateProvider) ->
  $stateProvider
    .state 'specs',
      abstract: true
      url: '/middlewares'
      views:
        "":
          controller: 'MiddlewareSpecCtrl'
          template: '<ui-view name="main"></ui-view>'

    .state 'specs.list',
        url: '/'
        views:
          main:
            templateUrl: '/middleware_specs/index.html'
            controller: 'MiddlewareSpecsListCtrl'

    .state 'spec.new',
        parent: 'specs'
        url: '/new'
        views:
          main:
            templateUrl: '/middleware_specs/new.html'
            controller: 'MiddlewareSpecNewCtrl'

    .state 'spec',
        parent: 'specs'
        url: '/:middlewareSpecId'
        views:
          main:
            templateUrl: '/middleware_specs/show.html'
            controller: 'MiddlewareSpecShowCtrl'

    .state 'spec.share',
        parent: 'spec.new'
        url: '/:middlewareUuid'
        views:
          "main@specs":
            templateUrl: '/middleware_specs/new.html'
            controller: 'MiddlewareSpecNewFromCtrl'

    .state 'spec.edit',
        parent: 'spec'
        url: '/edit'
        views:
          "main@specs":
            templateUrl: '/middleware_specs/edit.html'
            controller: 'MiddlewareSpecEditCtrl'

    .state 'spec.github',
        parent: 'spec'
        url: '/github'
        views:
          "main@specs":
            templateUrl: '/middleware_specs/github.html'
            controller: 'MiddlewareSpecGithubCtrl'

.factory 'DefaultMiddlewareCode', ->
  """
  return function(request, next_middleware)
    -- every middleware has to call next_middleware,
    -- so others have chance to process the request/response

    -- deal with request
    local response = next_middleware()
    send.notification({msg=response.status, level='info'})
    -- deal with response
    return response
  end
  """

.factory 'MiddlewareSpec', ($resource) ->
  $resource '/api/middleware_specs/:id', id: '@_id'

.controller 'MiddlewareSubscriptionCtrl', (
  $scope, GitHubSpec, GitHubSearchCode
) ->
  $scope.spec = { user: '3scale', repo: 'no500-brainslug' }

  $scope.search = ->
    query =
      [$scope.query,
        'language:json', 'in:file', 'path:brainslug.json'].join(' ')

    GitHubSearchCode.get q: query, (results) ->
      $scope.results = for item in results.items
        GitHubSpec.get(
          user: item.repository.owner.login, repo: item.repository.name
        )

  $scope.load = ->
    $scope.results = []
    GitHubSpec.get $scope.spec, (result) -> $scope.results.push(result)
    GitHubSpec.get $scope.spec, (result) -> $scope.results.push(result)
    GitHubSpec.get $scope.spec, (result) -> $scope.results.push(result)

.controller 'MiddlewareSpecCtrl', ($scope, $state, $stateParams, flash) ->
  $scope.save = (spec) ->
    spec.$save ->
      flash.success = "Middleware Spec #{spec.name} saved"
      $state.transitionTo('specs.list')

.controller 'MiddlewareSpecsListCtrl', (
  $scope, MiddlewareSpec, $location, GitHub
) ->

  GitHub.user ||= 'mikz'
  GitHub.token.set('60b6f9b60278b86a843d34f52558df7f016f0399')

  $scope.github = GitHub

  $scope.specs = MiddlewareSpec.query()

  # extract both these to directives
  $scope.badges = (spec) ->
    spec.badges ||= [
      { icon: 'icon-hdd', name: 'local' }
      { icon: 'icon-github', name: 'GitHub' }
      { icon: 'icon-code-fork', name: 'fork' }
      { icon: 'icon-code-unlock', name: 'public' }
    ]
  $scope.rating = (spec) ->
    return spec.rating if spec.rating
    rating = Math.ceil(Math.random() * 5)
    stars = []

    for i in [1 .. rating] by 1
      stars.push({ icon: 'icon-heart' })

    for i in [rating + 1 .. 5] by 1
      stars.push({icon: 'icon-heart-empty'})

    spec.rating = stars

.controller 'MiddlewareSpecNewCtrl', ($scope, MiddlewareSpec) ->
  $scope.spec = new MiddlewareSpec()

.controller 'MiddlewareSpecShowCtrl', (
  $scope, $stateParams, MiddlewareSpec, flash
) ->
  $scope.spec = MiddlewareSpec.get(id: $stateParams.middlewareSpecId)
  $scope.save = (spec = $scope.spec) ->
    spec.$save ->
      flash.success = "Middleware Spec #{spec.name} saved"

.controller 'MiddlewareSpecEditCtrl', ($scope, $stateParams, MiddlewareSpec) ->
  $scope.spec = MiddlewareSpec.get(id: $stateParams.middlewareSpecId)
  $scope.spec.author ||= {}

.controller 'MiddlewareSpecNewFromCtrl', (
  $scope, $stateParams, Middleware, MiddlewareSpec
) ->
  $scope.spec ||= new MiddlewareSpec()

  $scope.middleware =
    Middleware.get uuid: $stateParams.middlewareUuid, (middleware) ->
      attributes =
        code: middleware.code,
        name: middleware.name,
        description: middleware.description

      angular.extend($scope.spec, attributes)

.controller 'MiddlewareSpecGithubCtrl', (
  $scope, $stateParams, MiddlewareSpec, flash, GitHub, GitHubIntegrator,
  GitHubMessages, GitHubToken, GitHubValidator
) ->
  # FIXME: this does not smell bad, this stinks!
  $scope.spec ||= $scope.$parent.spec

  github = $scope.github = angular.copy($scope.spec?.github) || {}
  github.owner ||= GitHub.user
  github.repo ||= GitHub.repoSuggestion($scope.spec)

  GitHubToken.set('60b6f9b60278b86a843d34f52558df7f016f0399')

  $scope.save = (spec = $scope.spec) ->
    spec.github = github
    spec.$save ->
      flash.success = "Middleware GitHub integration saved"
      $scope.form.$setPristine()

  $scope.validate = ->
    $scope.messages = new GitHubMessages($scope.spec, github)
    $scope.valid = false
    success = ->
      $scope.valid = true

    failure = ->
      $scope

    GitHubValidator($scope.messages).then(success, failure)

  $scope.setUpIntegration = ->
    success = ->
      console.log('success')
    failure = ->
      console.log('failure')

    GitHubIntegrator($scope.messages).then(success, failure)

#Aight Michal, from this line till the end, if it's hurting your eyes too much,
# just get rif of it :D
.controller 'MiddlewareSpecWizardCtrl', (
  $scope, $stateParams, $location, Middleware, DefaultMiddlewareCode,
  MiddlewareSpec, flash, $state
) ->
  $scope.spec = new MiddlewareSpec(code: DefaultMiddlewareCode)

  if uuid = $stateParams.middlewareUuid?
    $scope.middleware = Middleware.get uuid: uuid, (middleware) ->
      attributes = _(middleware).pick('code', 'name', 'description')
      angular.extend($scope.spec, attributes)

  $scope.current_step ||= 0
  $scope.steps = ["General Info", "Author" , "Middleware"]

  $scope.next = ->
    if step = nextStep()
      template(step)
    else
      $scope.save()

  $scope.goTo = (index) ->
    template(index + 1)

  nextStep = () ->
    steps = $scope.steps.length
    current = $scope.current_step

    if current < steps
      $scope.current_step = ++current

  template = (step) ->
    direction = $scope.current_step < step

    [enter, leave] = if direction
      [ 'fadeInLeftBig', 'fadeOutRightBig' ]
    else
      [ 'fadeInRightBig', 'fadeOutLeftBig' ]

    $scope.slideAnimation =
      enter: "animated enter #{enter}",
      leave: "animated leave #{leave}"

    $scope.last_step = step == $scope.steps.length

    $scope.current_template = "/middleware_specs/wizard/#{step}.html"

  $scope.next()

  $scope.stepState = (index) ->
    current = $scope.current_step
    step = ++index

    if step > current
      'future'
    else if step == current
      'current'
    else if step < current
      'past'

  $scope.save = (spec = $scope.spec) ->
    spec.$save ->
      flash.success = "Middleware Spec #{spec.name} saved"
      $state.transitionTo('specs.list')
