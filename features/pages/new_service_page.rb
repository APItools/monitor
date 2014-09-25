require 'capybara/dsl'

class NewServicePage
  include Capybara::DSL

  def select_demo(name)
    click_on("Use #{name} API")

    self
  end

  def create
    click_on("Save")
    self
  end

  def service_page
    ServicePage.new
  end

  def has_demo_services?
    assert_selector('.demo-service')
  end
end
