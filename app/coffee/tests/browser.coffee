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

  check_flashed_message: (test, expected_message, category,
                          test_message = 'Checking flashed message') ->
    selector = "div.alert.alert-#{category}"
    test.assertSelectorHasText selector, expected_message, test_message

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

class NativeLoginTest extends BaseTestClass
  names: ['NativeLoginTest', 'login', 'nlogin']
  description: 'Test our native username/password login procedure'
  numTests: 14
  testBody: (test) ->
    casper.thenOpen serverUrl, ->
      @fill 'form#login_form', {
        username: 'darrenlamb'
        password: 'iknowandy'
        }, true  # true = submit form
    casper.then =>
      # Darren is not known to us; he is returned to the login form
      # and sees a message that his username is not found
      test.assertExists '#login_form',
        "After trying to log in without an account, returned to login form"
      @check_flashed_message test, 'Username not found', 'danger',
        "After trying to log in without an account, message appears"

    # he sets up a new account
    # at first he gets overenthusiastic and tries to set two different passwords
    casper.thenClick '#new_account', ->
      @fill 'form#new_account_form', {
        username: 'darrenlamb'
        password1: 'iknowandy'
        password2: 'imdarrenlamb'
        }, true  # true = submit form
    # he is returned to the new account form with an error message
    casper.then =>
      test.assertExists 'form#new_account_form',
        "Darren tried non-matching passwords, is returned to form"
      @check_flashed_message test, "Passwords do not match", 'danger',
        "Darren is warned about his passwords not matching"
      # he is not logged in
      test.assertDoesntExist '#logout'

    # he tries again with matching passwords
    casper.then ->
      @fill 'form#new_account_form', {
        username: 'darrenlamb'
        password1: 'iknowandy'
        password2: 'iknowandy'
        }, true  # true = submit form
    # Darren is automatically logged in
    casper.then ->
      # the next page has a logout button
      test.assertExists '#logout',
        "Darren logged in automatically, logout button appears"
      # and shows Darren's username
      user_menu_selector = '#user-dropdown-menu a'
      test.assertSelectorHasText user_menu_selector, 'darrenlamb',
        "Darren logged in for first time, his name appears"

    # he logs out
    casper.thenClick '#logout', ->
      test.assertDoesntExist '#logout',
        "Darren logs out, logout button disappears"
      test.assertExists 'form#login_form',
        "Darren logged out, the login form is back"

    # later, he logs in again
    casper.thenOpen serverUrl, ->
      # at first he forgets what password he settled on
      @fill 'form#login_form', {
        username: 'darrenlamb'
        password: 'imdarrenlamb'
        }, true  # true = submit form
    casper.then =>
      test.assertDoesntExist '#logout',
        "After trying incorrect password, logout button doesn't appear"
      @check_flashed_message test, 'Password incorrect', 'danger',
        "After trying incorrect password, a message to that effect appears"
      test.assertExists 'form#login_form',
        "After trying incorrect password, login form is presented again"

    # he tries once more with the correct password
    casper.then ->
      @fill 'form#login_form', {
        username: 'darrenlamb'
        password: 'iknowandy'
        }, true  # true = submit form
    # this time he gets in
    casper.then ->
      test.assertExists '#logout',
        "Darren logs in again, logout button appears"
      test.assertTextExists 'darrenlamb',
        "Darren logs in again, his name appears on the page"

runTestClass = (testClass) ->
  casper.test.begin testClass.description, testClass.numTests, (test) ->
    casper.start()
    testClass.testBody(test)
    casper.run ->
      test.done()

runTestClass (new NativeLoginTest)
runTestClass (new FeedbackTest)
runTestClass (new NormalFunctionalityTest)

casper.test.begin 'The shutdown test', 0, (test) ->
  casper.start()
  casper.thenOpen 'http://localhost:5000/shutdown', method: 'post', ->
    casper.echo 'Shutting down ...'
  casper.run ->
    casper.echo 'Shutdown'
    test.done()
