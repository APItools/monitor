class HomePage
  include Capybara::DSL

  def initialize
    visit('/')
    on_premise_setup
  end

  def on_premise_setup
    find('#setup-dialog').click_on('Save')
  rescue Capybara::ElementNotFound
  end

  def add_service
    click_on('add-service', text: 'Add a service')
    NewServicePage.new
  end

  def has_welcome_page?
    assert_selector('.welcome', text: 'Welcome!')
  end

  def has_service_dashboard_empty?
    assert_selector('.dashboard-box', text: '0 Services')
    assert_selector('.dashboard-box', text: 'Latest notifications')
  end

  def has_service_dashboard?
    assert_selector('.dashboard-box', text: 'Middleware Errors')
    assert_selector('.dashboard-box', text: 'Latest notifications')
  end
end
