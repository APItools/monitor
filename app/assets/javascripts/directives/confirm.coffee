angular.module('slug.directives.confirm', [])
  .directive "slugConfirm", () ->
    ACTIVE_CLASS = 'slug-confirm-active'
    
    transclude: true
    priority: -1
    template: """
      <span class="slug-confirm-original" ng-transclude/>
      <span class="slug-confirm-box">
        <a href class="slug-confirmation">{{ confirm ? confirm : "Yes" }}</a> | <a class="slug-cancel" href> {{ cancel ? cancel : "No" }}</a>
      </span>
      """
    scope:
      confirm: "=slugConfirmText"
      cancel: "=slugCancelText"
    link: (scope, element, attrs) ->
      element.addClass('slug-confirm')

      confirmation = element.find('.slug-confirmation')

      confirmation.bind 'focusout', ->
        element.removeClass(ACTIVE_CLASS)

      element.bind 'click', (event) ->
        element.toggleClass(ACTIVE_CLASS)

        unless event.target == confirmation.get(0)
          event.stopImmediatePropagation()
          event.preventDefault()
