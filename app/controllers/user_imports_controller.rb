class UserImportsController < ApplicationController     

  before_filter :user_fields, only: [:create, :create_user]
  before_filter :validate_file_extension, :validate_csv, :validate_file_data, only:[:create]
  before_filter :validate_mutiple_values, :initialize_valid_params, only: [:create_user]

  OPTIONS_TO_REMOVE = [["Id", :id], ["Last Login On", :last_login_on], ["Auth Source", :auth_source_id], 
                      ["Identity Url", :identity_url], ["Salt", :salt], ["Type", :type], ["Created On", :created_on], 
                      ["Updated On", :updated_on], ["Hashed Password", :hashed_password], ["Status", :status]]
  USER_PREFERENCES = ["comments_sorting", "no_self_notified", "warn_on_leaving_unsaved", "hide_mail", "time_zone"]

  def index
    @import = UserImport.new
    render 'index'
  end

  def create
		render :finalize
  end

  def create_user
    @user_ready_to_save.each_with_index do |user, index|
      if user.save
        Mailer.account_information(user, @user_param_hash[index]["password"]).deliver if @user_param_hash[index]["send_email"] == "1"
        create_user_prefrences(user, index)
			end
		end
		flash[:notice] = l(:user_imported_successfully_message, :no_of_users => @user_ready_to_save.length)
		redirect_to import_index_path
  end

  def download
		respond_to do |format|
		  format.csv do
		    response.headers['Content-Type'] = 'text/csv'
    		response.headers['Content-Disposition'] = 'attachment; filename = sample.csv'
    		render :template => "user_imports/download.csv.erb", :type => 'text/csv; header = present'
			end
		end
  end

private

  def create_user_prefrences(user, index)
    has_user_preferences = ((USER_PREFERENCES-@user_param_hash[index].keys).length != USER_PREFERENCES.length)
    return unless has_user_preferences
    ["hide_mail", "time_zone"].each do |pref|
      user.pref.send("#{pref}=", @user_param_hash[index][pref]) unless @user_param_hash[index][pref].blank?
    end

    others =  ["comments_sorting", "warn_on_leaving_unsaved", "no_self_notified"].each.inject({}) do |result, preference_fields|
                result.merge!(preference_fields.to_sym => @user_param_hash[index][preference_fields]) unless @user_param_hash[index][preference_fields].blank?
              end
    user.pref.others = others
    user.pref.save
  end

  def user_fields
    @fields = ((User.columns.map {|field| [field.name.titleize, field.name.to_sym] }) + 
              (User.new.available_custom_fields.collect{|column| [column.name, column.id]}))
    @fields = @fields + [["Password", :password], ["Hide Mail", :hide_mail], ["No Self Notification", :no_self_notified], 
                          ["Time Zone", :time_zone], ["Comments Sorting", :comments_sorting], 
                          ["Warn when leaving a page with unsaved text", :warn_on_leaving_unsaved], 
                          ["Send account information to the user", :send_email]] - OPTIONS_TO_REMOVE
  end

  def validate_file_extension
  	return if params[:user_import].blank?
    file_name = params[:user_import][:csv].original_filename
	  flash_error_and_render(l(:error_file_not_of_csv_extension)) if File.extname(file_name) != (".csv")
  end

  def validate_csv
  	@import = UserImport.new(params[:user_import])
	  render :index unless @import.valid?
  end

  def validate_file_data
    return if params[:user_import].blank?
    begin
      @csv_rows = CSV.parse(params[:user_import][:csv].read)
      flash_error_and_render(l(:error_invalid_csv_data)) and return if @csv_rows.blank? or @csv_rows.size < 2
      # validate number of columns in csv, where 4 stands for default number of mandatory fields for User creation.
      @csv_rows.each {|column| break  @render_back = true if column.size < 5}
    rescue Exception => e
      flash_error_and_render(e.message)
    end
  end

  def flash_error_and_render(error_message, render_view = 'index')
    @import = UserImport.new if render_view == 'index'
    flash.now[:error] = error_message
    render :"#{render_view}"
  end

  def validate_mutiple_values
    @csv_rows = eval(params[:import][:csv])
 	  options = params[:options].reject(&:empty?)
  	flash_error_and_render(l(:error_to_try_map_same_field_twice),'finalize')  unless (options.uniq.length == options.length)
  end

  def initialize_valid_params
    @user_param_hash, @user_ready_to_save, validation_failed = [], [], false
		@csv_rows[1...@csv_rows.length].each do |user|
	  	@user = User.new(:language => Setting.default_language, :mail_notification => Setting.default_notification_option)
      user_validator = UserValidator.new(user, params[:options])
      user_param_hash = user_validator.user_param_hash
      @user.safe_attributes = user_param_hash
      @user.login = user_param_hash["login"]
      @user.admin = (user_param_hash["admin"] == "yes") if !user_param_hash["admin"].blank?
      @user.language = user_param_hash["language"].to_sym if !user_param_hash["language"].blank? and UserValidator::LANGUAGE_ABBR.include?(user_param_hash["language"].to_sym)

      unless user_param_hash["password"].blank?
        @user.password, @user.password_confirmation = user_param_hash["password"], user_param_hash["password"] unless @user.auth_source_id
      else
        @user.password = ""
      end

      unless user_validator.errors.blank? and @user.valid?
        @user.errors.messages.merge!(user_validator.errors.messages)
  			validation_failed = true
  			break
			else
				@user_param_hash << user_param_hash
				@user_ready_to_save << @user
			end
    end
    @user.errors[:base] << l(:duplicate_user_email_or_login) unless ((@user_ready_to_save.count == @user_ready_to_save.map(&:login).uniq.count) and (@user_ready_to_save.count == @user_ready_to_save.map(&:mail).uniq.count))
	  render :finalize if validation_failed or !@user.errors.blank?
  end
end
