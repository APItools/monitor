var browsers = [];
var reporters = [];

if(process.env.CI) { //
  reporters.push('dots');
  browsers.push('Firefox');
} else {
  browsers.push('Chrome');
  reporters.push('progress');
}

if(process.env.COVERAGE) { reporters.push('coverage'); }

module.exports = function(config) {
  "use strict";

  var files = [
    'app/vendor/angular-mocks/angular-mocks.js',
    'app/vendor/jasmine-jquery/lib/jasmine-jquery.js',

    'test/helpers/**/*.coffee',
    'test/helpers/**/*.js',
    'test/unit/**/*.js',
    'test/unit/**/*.coffee',

    // 'app/assets/javascripts/compiled/all.js',
    // {pattern: 'app/assets/javascripts/compiled/*.js', included: false, served: false, watched: false},

    {pattern: 'app/assets/javascripts/*.coffee', included: true},
    {pattern: 'app/assets/javascripts/**/*.coffee', included: true}
  ];

  if(process.env.RELEASE) { files.unshift('release/app/assets/vendor.js'); }
  else { files.unshift('app/assets/compiled/vendor.js'); }

  config.set({
    colors: !process.env.CI,
    frameworks: ["jasmine"],
    basePath: '../',
    files: files,
    preprocessors: {
      "**/*.coffee": 'coffee',
      "app/assets/javascripts/**/*.js": 'coverage'
    },

    autoWatch: true,

    // logLevel: config.LOG_DEBUG,

    browsers: browsers,
    reporters: reporters,

    plugins: [
        'karma-jasmine',
        'karma-coffee-preprocessor',
        'karma-chrome-launcher',
        'karma-firefox-launcher'
    ],

    coverageReporter: {
      type : 'html',
      dir : 'coverage/'
    },

    junitReporter: {
      outputFile: 'test_out/unit.xml',
      suite: 'unit'
    },

    coffeePreprocessor: {
      options: {
        bare: false,
        sourceMap: false
      }
    }
  });
};
