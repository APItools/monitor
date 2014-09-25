class DemoCallsPage

  def initialize(page)
    @page = page
  end

  def has_demo_calls?
    @page.assert_selector(demo_calls_selector)
  end

  def demo_calls
    service_demo.all(demo_calls_selector)
  end

  def has_loading_demo_calls?
    not @page.assert_no_selector('.demo-call .loading', visible: true)
  end

  private

  def service_demo
    @page.find('.service-demo')
  end

  def demo_calls_selector
    '.demo-calls .demo-call'
  end
end
