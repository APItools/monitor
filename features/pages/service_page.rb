require 'httpclient'

class ServicePage
  include Capybara::DSL

  attr_reader :name

  def initialize
    @name = find('.service-name').text
  end

  def menu
    find('.service-nav')
  end

  def pipeline_page
    menu.click_on('Pipeline')
    PipelinePage.new
  end

  def integration_page
    menu.click_on('Integration')
    ServicePage::IntegrationPage.new
  end

  def analytics_page
    menu.click_on('Analytics')
    AnalyticsPage.new
  end

  def traces_page
    menu.click_on('Traces')
    TracesPage.new
  end

  def demo_calls_page
    menu.click_on('service-integration', text: 'Integration')
    DemoCallsPage.new(page)
  end

  def settings_page
    menu.click_on('Settings')
    SettingsPage.new
  end

  def proxy
    @proxy ||= integration_page.proxy
  end


  class Proxy
    PROXY_HOST = URI.parse('http://localhost:10002')

    def initialize(code)
      @code = code
      @client = HTTPClient.new(PROXY_HOST)
      @client.set_proxy_auth('capybara', code)
      # always send proxy auth headers
      @client.proxy_auth.basic_auth.challenge(true)
    end

    def get(path)
      uri = URI.join(PROXY_HOST, path)
      @client.get(uri)
    end
  end

  class IntegrationPage
    include Capybara::DSL

    def proxy
      ServicePage::Proxy.new(service_code)
    end

    def service_code
      find('.endpoint-example')['data-service-code']
    end
  end
end
