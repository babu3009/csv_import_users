require File.expand_path('../../test_helper', __FILE__)

class UserImportsControllerTest < ActionController::TestCase

  def setup
    @request.session[:user_id] = 1
  end

  def test_index
    get :index
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:import)
  end

  def test_download
    get :download, format: "csv"
    assert_template 'user_imports/download.csv'
  end

  def test_create
    #file with wrong format
    ['wrong_format.txt', 'blank_csv.csv', 'single_row_csv.csv', 'multiple_extensions.txt.csv'].each do |file|
      post :create, user_import: {csv: fixture_file_upload('../../plugins/csv_import_users/test/fixtures/'+file,'text/csv')}
      assert_equal false, assigns(:import).valid?
      assert_equal true, assigns(:import).errors.has_key?(:csv)
    end

    #rescuing exception for file with with illegal data
    post :create, user_import: {csv: fixture_file_upload('../../plugins/csv_import_users/test/fixtures/file_with_invalid_data.csv','text/csv')}
    assert_template 'index'

    #correct csv
    post :create, user_import: {csv: fixture_file_upload('../../plugins/csv_import_users/test/fixtures/import_users.csv','text/csv')}
    assert_template 'finalize'
  end

  def test_create_user
    #correct CSV
    options = ["login", "firstname", "lastname", "mail", "admin", "language", "mail_notification", "password", "hide_mail", 
    "time_zone", "comments_sorting", "warn_on_leaving_unsaved", "no_self_notified", "1", "send_email"]
    date_in_file = "[[\"Login\", \"Firstname\", \"Lastname\", \"Mail\", \"Admin\", \"Language\", \"Mail Notification\", 
    \"Password\", \"Hide Email\", \"Time Zone\", \"Comments Order\", \"Warn when leaving a page with unsaved text\", 
    \"No self Notification\", \"Custom Field\", \"Notify from mail\"], [\"LoginId0\", \"Firstname of User0\", \"Lastname of User0\", 
    \"user0@mailinator.com\", \"yes\", \"en\", \"only_my_events\", \"password\", \"yes\", \"Chennai\", \"asc\", \"yes\", 
    \"yes\", \"custom_field\", \"yes\"], [\"LoginId11\", \"Firstname of User11\", \"Lastname of User11\", \"user11@mailinator.com\", 
    \"yes\", \"en\", \"only_my_events\", \"password\", \"yes\", \"Chennai\", \"asc\", \"yes\", \"yes\", \"custom_field\", \"yes\"], 
    [\"LoginId12\", \"Firstname of User12\", \"Lastname of User12\", \"user12@mailinator.com\", \"yes\", \"en\", 
    \"only_my_events\", \"password\", \"yes\", \"Chennai\", \"asc\", \"yes\", \"yes\", \"custom_field\", \"yes\"], [\"LoginId13\", 
    \"Firstname of User13\", \"Lastname of User13\", \"user13@mailinator.com\", \"yes\", \"en\", \"only_my_events\", 
    \"password\", \"yes\", \"Chennai\", \"asc\", \"yes\", \"yes\", \"custom_field\", \"yes\"], [\"LoginId14\", 
    \"Filerstname of User14\", \"Lastname of User14\", \"user14@mailinator.com\", \"yes\", \"en\", \"only_my_events\", 
    \"password\", \"yes\", \"Chennai\", \"asc\", \"yes\", \"yes\", \"custom_field\", \"yes\"], [\"LoginId15\", 
    \"Firstname of User15\", \"Lastname of User15\", \"user15@mailinator.com\", \"yes\", \"en\", \"only_my_events\", 
    \"password\", \"yes\", \"Chennai\", \"asc\", \"yes\", \"yes\", \"custom_field\", \"yes\"]]"

    post :create_user, {options: options, import: {csv: date_in_file}}
    ['LoginId0', 'LoginId11', 'LoginId12', 'LoginId13', 'LoginId14', 'LoginId15'].each_with_index do |login_id, index|
      user = User.where(login: login_id).first
      assert_equal user, assigns(:user_ready_to_save)[index]
    end
    ['csv_rows', 'user_ready_to_save', 'user_param_hash', 'user'].each{ |key| assert_not_nil assigns(key.to_sym) }

    #duplicate field mapping
    options = ["login", "firstname", "lastname", "mail", "admin", "language", "mail_notification", "password", "hide_mail", 
    "time_zone", "comments_sorting", "warn_on_leaving_unsaved", "send_email", "1", "send_email"]
    post :create_user, {options: options, import: {csv: date_in_file}}
    assert_not_nil assigns(:csv_rows)
    assert_template 'finalize'

    #leaving blank mandatory fields
    options = ["", "", "", "", "admin", "language", "mail_notification", "", "hide_mail", 
    "time_zone", "comments_sorting", "warn_on_leaving_unsaved", "send_email", "1"]
    date_in_file = "[[\"Login\", \"Firstname\", \"Lastname\", \"Mail\", \"Admin\", \"Language\", \"Mail Notification\", 
    \"Password\", \"Hide Email\", \"Time Zone\", \"Comments Order\", \"Warn when leaving a page with unsaved text\", 
    \"No self Notification\", \"Custom Field\", \"Notify from mail\"], [\"LoginId0\", \"Firstname of User0\", \"Lastname of User0\", 
    \"user0@mailinator.com\", \"yes\", \"en\", \"only_my_events\", \"password\", \"yes\", \"Chennai\", \"asc\", \"yes\", 
    \"yes\", \"custom_field\"]]"
    post :create_user, {options: options, import: {csv: date_in_file}}
    assert_not_nil assigns(:csv_rows)
    ['login', 'firstname', 'lastname', 'mail', 'password'].each{|key| assert_equal true, assigns(:user).errors.has_key?(key.to_sym)}
    assert_template 'finalize'

    #mapping wrong fields
    options = ["login", "firstname", "lastname", "mail", "admin", "language", "mail_notification", "password", "hide_mail", 
    "time_zone", "comments_sorting", "warn_on_leaving_unsaved", "no_self_notified", "1", "send_email"]
    date_in_file = "[[\"Login\", \"Firstname\", \"Lastname\", \"Mail\", \"Admin\", \"Language\", \"Mail Notification\", 
    \"Password\", \"Hide Email\", \"Time Zone\", \"Comments Order\", \"Warn when leaving a page with unsaved text\", 
    \"No self Notification\", \"Custom Field\", \"Notify from mail\"], [\"LoginId0\", \"Firstname of User0\", \"Lastname of User0\", 
    \"user0@mailinator.com\", \"abc\", \"xyz\", \"1234\", \"password\", \"abc\", \"PQR\", \"wxy\", \"abc\", 
    \"cbz\", \"custom_field\", \"pqr\"]]"
    post :create_user, {options: options, import: {csv: date_in_file}}
    assert_not_nil assigns(:csv_rows)
    ['base', 'admin', 'language', 'hide_mail', 'time_zone', 'comments_sorting', 'warn_on_leaving_unsaved'].each do |key| 
      assert_equal true, assigns(:user).errors.has_key?(key.to_sym)
    end
    assert_template 'finalize'
  end
end