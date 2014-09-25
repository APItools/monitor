class MainMenu
  include Capybara::DSL

  def services_listing
    service_name = current_service
    services_menu.click_on(service_name)
    dropdown.click_on('All Services')
    service_name
  end

  def service_name
    current_service
  end

  private

  def services_menu
    menu.find('.services-menu')
  end

  def current_service
    services_menu.find('.dropdown-toggle').text
  end

  def dropdown
    find('.main-menu-dropdown')
  end

  def menu
    find('.main-menu')
  end
end

module Navigation
  def navigation
    @navigation ||= MainMenu.new
  end
end

World(Navigation)
