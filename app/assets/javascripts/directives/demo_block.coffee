angular.module("slug.directives.demo_block", ["slug.user_settings"])
.directive "demoBlock", (UserSettings) ->

  compile: (element, attrs) ->
    element.addClass("demo-block")
    setting = "hide_demo_block_#{attrs.demoBlock}"
    element.hide()

    hidden = UserSettings.get setting, (hidden) ->
      hidden ||= false
      element.toggle(!hidden)

    closeLink = angular.element(
      """<button class="demo-block-remove" type="button">
          <i class="icon icon-remove"></i></button>"""
    )

    closeLink.on 'click', ->
      element.hide()
      UserSettings.set(setting, true)

    element.prepend(closeLink)
