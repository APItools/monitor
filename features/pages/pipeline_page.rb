class PipelinePage
  include Capybara::DSL

  def middleware_spec(name)
    find('.middleware-stack .middleware', text: name)
  end

  def pipeline
    find('.pipeline .middleware-list')
  end

  def save_pipeline
    click_link('Save Pipeline')
  end

  def add_middleware(name)
    middleware_spec(name).drag_to(pipeline)
  end

  def has_middleware?(name)
    pipeline.assert_selector('.middleware', text: name)
  end
end
