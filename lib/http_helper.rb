require 'active_support/core_ext/object/to_query'
require 'httpclient'
require 'httpclient/include_client'

module HTTPHelper

  class Client
    extend HTTPClient::IncludeClient

    include_http_client

    def initialize(host = self.class::DEFAULT_HOST)
      @host = host
    end

    def url(path)
      URI.join(@host, path)
    end
  end

  class ApiClient < Client
    DEFAULT_HOST = 'http://localhost:7071'

    def post(path, body = nil, header: {})
      http_client.post(url(path), body: body, header: header)
    end
  end

  def host
    'http://localhost:7071'
  end

  def api_client
    ApiClient.new
  end

  def api_get(path, params = {})
    JSON.parse get("#{api}#{path}", query: params.to_query).content
  end

  def api_post(path, body = nil)
    post("#{api}#{path}", body: body).content
  end

  ##
  # These methods return 'response' and use 'default_host' variable
  def do_post(path, body="")
    post("#{host}#{path}", body: body.to_json, status: nil)
  end

  def do_get(path, **params)
    get("#{host}#{path}", status: nil, query: params.to_query)
  end

  def do_async_get(path, **params)
    get("#{host}#{path}", status: nil, query: params.to_query, async: true)
  end

  def do_delete(path, **params)
    delete("#{host}#{path}", status: nil)
  end
  ##
  # These methods require whole uri with host
  def get(url, **options)
    do_request('get', url, **options)
  end

  def delete(url, **options)
    do_request('delete', url, **options)
  end

  def post(url, **options)
    do_request('post', url, **options)
  end

  ##
  # These also require whole uri and return just content / parsed json

  def post_json(url, **options)
    JSON.parse(do_request('post', url, header: {'Content-Type' => 'application/json'}, **options).content)
  end

  def get_content(url, **options)
    response = get(url, **options)
    response.content || ""
  end

  def get_json(url, **options)
    json = get_content(url, **options)
    JSON.parse(json)
  end

  def delete_json(url, **options)
    json = delete_content(url, **options)
    JSON.parse(json)
  end

  def http_client
    @_http_client ||= HTTPClient.new
  end

  private

  def do_request(method, url, status: 200, query: nil, host: nil, body: nil, header: {}, async: false)
    uri = URI.parse(url)

    if host
      header['Host'] = uri.host
      uri.host = URI.parse(host).host
    end

    method = "#{method}_async" if async

    response = http_client.request(method,
                                  uri,
                                  body: body,
                                  query: query,
                                  header: header)

    expect(response.status).to eq(status) if status

    response # this returns something that has a content and status
  end

end
