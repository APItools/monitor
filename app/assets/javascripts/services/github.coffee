class TokenHandler
  constructor: ->
    @token = null

  set: (token) =>
    @token = token

  get: () =>
    @token

  params: (params) =>
    angular.extend(access_token: @get, params || {})

class GitHubIntegration
  constructor: (protocol, host) ->
    @redirect_uri = "http://localhost:8089/auth/#{protocol}/#{host}"
    @client_id = "75a7ae9e68e3fd530b9a"
    @url =
      "https://github.com/login/oauth/authorize?
        client_id=#{@client_id}&redirect_uri=#{@redirect_uri}"

class GitHub
  constructor: ->

  repoSuggestion: (spec)->
    param = spec.name.replace(/[^\w]+|[\s]+/g, '-')
    param.toLowerCase()

class GitHubMessages
  constructor: (spec, @github) ->
    @spec = angular.copy(spec)
    @code = @spec.code
    @spec.code = @github.repo + '.lua'

    @should = {}
    @messages = []

  reset: ->
    @should = {}
    @messages = []

  isValid: ->
    _(@messages).all (msg) ->
      if msg.confirm then msg.confirmed else true

  highlight: (message) ->
    strong = (str) -> "<strong>#{str}</strong>"
    needle = /{{\s*([^\}\s]+)\s*}}/g

    owner = @github.owner
    repo = @github.repo
    code = @spec.code

    message.replace needle, (match, key) ->
      switch key
        when 'owner/repo' then strong("#{owner}/#{repo}")
        when 'visibility' then strong('public')
        when 'spec' then strong('brainslug.json')
        when 'code' then strong(code)
        else throw Error("Unknown key: " + key)

  add: (msg, options = {}) ->
    message = angular.copy(options)
    message.text = @highlight(msg)

    @messages.push(message)

  repo_exists: ->
    @add("I'm aware that {{owner/repo}} already exists as {{visibility}}
      repository", level: 'warning', confirm: true)

  repo_missing: ->
    @add('{{visibility}} repository {{owner/repo}} will be created',
      level: 'notify')

  push_spec: ->
    @add('We will push {{spec}} middleware specification', level: 'info')

  push_code: ->
    @add('We will push {{code}} middleware code', level: 'info')

  override_spec: ->
    @add("I'm aware that {{owner/repo}} already contains different middleware
      spec", level: 'error', confirm: true)

  override_code: ->
    @add("I'm aware that {{owner/repo}} already contains different middleware
      code", level: 'warning', confirm: true)

angular.module('slug.github', ['ngResource'])
.factory 'GitHub', (GitHubToken, GitHubIntegration)->
  gh = new GitHub()
  gh.token = GitHubToken
  gh.integration = GitHubIntegration
  gh

.factory 'GitHubToken', ->
  new TokenHandler()

.factory 'GitHubMessages', ->
  GitHubMessages

.factory 'GitHubIntegration', ($location) ->
  new GitHubIntegration($location.protocol(), window.location.host)

.factory 'GitHubSpec', ($resource, GitHubToken) ->
  $resource '/api/test/test', GitHubToken.params()

.factory 'GitHubFile', ($resource, GitHubToken) ->
  $resource 'https://api.github.com/repos/:owner/:repo/contents/:path',
    GitHubToken.params(),
    save: { method: 'PUT' }

.factory 'GitHubRepo', ($resource, GitHubToken) ->
  $resource 'https://api.github.com/:scope/:owner/:repo',
    GitHubToken.params(scope: 'repos'),
    create: { method: 'POST', params: { scope: 'user', owner: 'repos' } }

.factory 'GitHubSearchCode', ($resource, GitHubToken) ->
  $resource 'https://api.github.com/search/code',
    GitHubToken.params(),
    get: { method: 'GET', headers: {Accept: 'application/vnd.github.preview'}}


.factory 'GitHubValidator', ($q, GitHubFile, GitHubRepo) ->
  (messages) ->
    defers  = ($q.defer() for _ in [1..3])
    [defer_repo, defer_spec, defer_code] = defers

    spec = messages.spec
    github = messages.github

    params = (params = {}) ->
      gh =
        owner: github.owner
        repo: github.repo
      angular.extend(params, gh)

    code_exists = (c) ->
      messages.override_code(c)
      messages.should.update_code = c
      defer_code.resolve('code exists')

    code_missing = (r) ->
      messages.push_code()
      defer_code.resolve('code missing')

    spec_exists = (s) ->
      messages.override_spec(s)
      messages.should.update_spec = s
      defer_spec.resolve('spec exists')
      GitHubFile.get(params(path: spec.code), code_exists, code_missing)

    spec_missing = (r) ->
      messages.push_spec()
      defer_spec.resolve('spec missing')
      GitHubFile.get(params(path: spec.code), code_exists, code_missing)

    repo_exists = (r) ->
      messages.repo_exists()
      defer_repo.resolve('repo exists')
      GitHubFile.get(params(path: 'brainslug.json'),
        spec_exists, spec_missing)

    repo_missing = (r) ->
      messages.should.create_repo = true
      messages.repo_missing()
      messages.push_spec()
      messages.push_code()
      d.resolve('repo missing') for d in defers

    GitHubRepo.get(github, repo_exists, repo_missing)

    $q.all((d.promise for d in defers))

.factory 'GitHubIntegrator', ($q, GitHubFile, GitHubRepo) ->
  (messages) ->
    should = messages.should
    spec   = messages.spec
    code   = messages.code

    console.log(should)

    github =
      owner: messages.github.owner
      repo: messages.github.repo

    defers  = ($q.defer() for _ in [1..3])
    [defer_repo, defer_spec, defer_code] = defers

    params = (params) ->
      angular.extend(params, github)

    messages.reset()

    do_spec = ->
      if previous = should.update_spec
        update_spec(previous)
      else
        create_spec()

    do_code = ->
      if previous = should.update_code
        update_code(previous)
      else
        create_code()

    encode = (object) ->
      Base64.encode(angular.toJson(object, true))

    spec_updated = ->
      console.log('spec updated')
      defer_spec.resolve('spec updated')
      do_code()

    code_updated = ->
      console.log('code updated')
      defer_code.resolve('code updated')

    repo_created = ->
      console.log('repo created')
      defer_repo.resolve('repo created')
      do_spec()

    repo_failed = ->
      console.log('repo failed')
      defer_repo.reject('repo failed')

    code_failed = ->
      console.log('code failed')
      defer_code.reject('code failed')

    spec_failed = ->
      console.log('spec failed')
      defer_spec.reject('spec failed')

    create_spec = ->
      GitHubFile.save(params(
        path: 'brainslug.json'),
        message: 'Create middleware spec',
        content: encode(spec), spec_updated, spec_failed)

    update_spec = (previous) ->
      GitHubFile.save(params(
        path: 'brainslug.json'),
        sha: previous.sha,
        message: 'Update middleware spec',
        content: encode(spec), spec_updated, spec_failed)

    create_code = ->
      GitHubFile.save(params(
        path: spec.code),
        message: 'Create middleware code',
        content: encode(code), code_updated, code_failed)

    update_code = (previous) ->
      GitHubFile.save(params(
        path: spec.code),
        sha: previous.sha,
        message: 'Update middleware code',
        content: encode(code), code_updated, code_failed)

    if should.create_repo
      GitHubRepo.create(
        name: github.repo,
        auto_init: true, repo_created, repo_failed)
    else
      defer_repo.resolve('repo already exists')
      do_spec()

    $q.all((d.promise for d in defers))
