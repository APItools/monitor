/*
 jQuery UI Sortable plugin wrapper

 @param [ui-sortable] {object} Options to pass to $.fn.sortable() merged onto ui.config
*/
angular.module('ui.sortable', [])
  .value('uiSortableConfig',{})
  .directive('uiSortable', [ 'uiSortableConfig',
        function(uiSortableConfig) {
        return {
          require: '?ngModel',
          link: function(scope, element, attrs, ngModel) {


            var sortable;
            var opts = {};

            var callbacks = {
              receive: null,
              remove:null,
              start:null,
              stop:null,
              update:null
            };

            var apply = function(e, ui, sortable) {
              if (ngModel || sortable.relocate) {
                scope.$apply();
              }
            };

            var combineCallbacks = function(first,second){
              if(!second) { second = {}; }

              if(typeof second === "function"){
                second = { post: second };
              }

              return function(e, ui) {
                var state = sortable;
                if(second && second.pre) { second.pre(e,ui, state); }
                first(e, ui, state);
                if(second && second.post) { second.post(e, ui, state); }
              };
            };


            angular.extend(opts, uiSortableConfig);

            if (ngModel) {

              ngModel.$render = function() {
                element.sortable( "refresh" );
              };

              callbacks.start = function(e, ui) {
                // Save position of dragged item
                sortable = { index: ui.item.index() };
              };

              callbacks.update = function(e, ui, state) {
                // For some reason the reference to ngModel in stop() is wrong
                // ui.item.sortable.resort = ngModel;
                if (state) { state.updated = true; }
              };

              callbacks.receive = function(e, ui, state) {
                if(!state || !state.moved) { state = {moved: ui.item.moved, index: ui.item.index() }; }

                // added item to array into correct position and set up flag
                ngModel.$modelValue.splice(state.index, 0, state.moved);
                delete state.updated;
              };

              callbacks.remove = function(e, ui, state) {
                // copy data into item
                ui.item.moved =  ngModel.$modelValue.splice(state.index, 1)[0];
                state.removed = true;
                delete state.updated;
              };

              callbacks.stop = function(e, ui, state) {
                // reset state
                sortable = null;

                // digest all prepared changes
                if( state && state.index && state.updated && !state.moved) {

                  // Fetch saved and current position of dropped element
                  var end, start, original;
                  start = state.index;
                  end = ui.item.index();

                  // Reorder array
                  original = ngModel.$modelValue.splice(start, 1)[0];
                  ngModel.$modelValue.splice(end, 0, original);
                }

              };

            }


              scope.$watch(attrs.uiSortable, function(newVal, oldVal){
                  angular.forEach(newVal, function(value, key){

                      if( callbacks[key] ){
                          // wrap the callback
                          value = combineCallbacks( callbacks[key], value );

                          if ( key === 'stop' ){
                              // call apply after stop
                              value = combineCallbacks( value, apply );
                          }
                      }

                      element.sortable('option', key, value);
                  });
              }, true);

              // get the actual config before initializing sortable
              // FIXME: this can break callbacks or no?
              if(attrs.uiSortable) {
                angular.extend(opts, scope.$eval(attrs.uiSortable));
              }

              angular.forEach(callbacks, function(value, key ){

                    opts[key] = combineCallbacks(value, opts[key]);
              });

              // call apply after stop
              opts.stop = combineCallbacks( opts.stop, apply );

              // Create sortable

            element.sortable(opts);
          }
        };
      }
]);
