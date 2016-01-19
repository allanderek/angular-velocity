# compute server url from arguments

defaultHost = "http://localhost"
host = casper.cli.options['host'] or defaultHost
port = casper.cli.options['port'] or
  if host is defaultHost then "5000" else "80"

portString = if port == "80" or port == 80 then "" else ":#{port}"

unless (host.match /localhost/) or (host.match /staging/)
  casper.die "Server url contains neither 'localhost' nor 'staging', aborting"

serverUrl = "#{host}#{portString}"
casper.echo "Testing against server at #{serverUrl}"

debug_dump_html = () ->
  "Occasionally can be useful during debugging just to dump the current HTML."
  casper.echo (casper.getHTML())

class BaseTestClass
  get_url: (local_url) ->
    serverUrl + "/" + local_url

  check_flashed_message: (test, expected_message, category) ->
    selector = "div.alert.alert-#{category}"
    test.assertSelectorHasText selector, expected_message,
        'Checking flashed message'


class NormalFunctionalityTest extends BaseTestClass
  names: ['NormalFunctionality']
  description: "Tests the normal functionality of ...."
  numTests: 1

  testBody: (test) ->
    url = @get_url '/'
    casper.thenOpen url, ->
      main_menu_css = 'nav .container #navbar ul li'
      test.assertExists main_menu_css

class FeedbackTest extends BaseTestClass
  names: ['FeedbackTest']
  description: "Tests the feedback mechanism."
  numTests: 1

  testBody: (test) ->
    url = @get_url '/'
    casper.open url
    casper.thenClick '#feedback-link', ->
      # casper.waitUntilVisible 'form#give_feedback'
      form_values =
        'input[name="feedback_email"]' : 'avid_user@google.com'
        'input[name="feedback_name"]' : 'Avid User'
        'textarea[name="feedback_text"]' : 'I think this site is great.'
      # The final 'true' argument means that the form is submitted.
      @fillSelectors 'form#give-feedback', form_values, true
    casper.then =>
      @check_flashed_message test, 'Thanks for your feedback!', 'info'

runTestClass = (testClass) ->
  casper.test.begin testClass.description, testClass.numTests, (test) ->
    casper.start()
    testClass.testBody(test)
    casper.run ->
      test.done()

runTestClass (new NormalFunctionalityTest)
runTestClass (new FeedbackTest)

casper.test.begin 'The shutdown test', 0, (test) ->
  casper.start()
  casper.thenOpen 'http://localhost:5000/shutdown', method: 'post', ->
    casper.echo 'Shutting down ...'
  casper.run ->
    casper.echo 'Shutdown'
    test.done()
