class UserValidator
  include ActiveModel::Validations
  validate :validate_and_assign_send_email, :validate_and_assign_warn_on_leaving_unsaved,
           :validate_and_assign_hide_mail, :validate_and_assign_no_self_notified,
           :validate_and_assign_comments_sorting, :validate_and_assign_language,
           :validate_and_assign_timezone, :validate_and_assign_admin
  
  CHECKBOX_VALID_VALUES = ["yes", "no"]
  COMMENT_SORTING_VALUES = ["asc", "desc"]
  TIME_ZONES = ActiveSupport::TimeZone.zones_map.keys
  LANGUAGE_ABBR ||= ::I18n.load_path.map {|path| File.basename(path, '.*')}.uniq.sort.map(&:to_sym)

  def initialize(row, params)
    @headers = params
    @user_row = row
    @user_param_hash = attribute_map
    self.valid?
  end

  ["send_email", "warn_on_leaving_unsaved", "hide_mail", "no_self_notified"].each do |field|
    define_method "validate_and_assign_#{field}" do
      return if @user_param_hash[field].blank?
      return add_error(field) unless CHECKBOX_VALID_VALUES.include?(@user_param_hash[field].downcase)
      @user_param_hash[field] = field_value(field, @user_param_hash[field])
    end
  end

  def validate_and_assign_comments_sorting
    return if @user_param_hash["comments_sorting"].blank?
    self.errors.add(:comments_sorting, "is invalid") unless COMMENT_SORTING_VALUES.include?(@user_param_hash["comments_sorting"].downcase)
  end

  def validate_and_assign_language
    return if @user_param_hash["language"].blank?
    self.errors.add(:language, "is invalid") unless LANGUAGE_ABBR.include?(@user_param_hash["language"].to_sym)
  end

  def validate_and_assign_timezone
    return if @user_param_hash["time_zone"].blank?
    self.errors.add(:time_zone, "is invalid") unless TIME_ZONES.include?(@user_param_hash["time_zone"].titleize)
  end

  def validate_and_assign_admin
    return if @user_param_hash['admin'].blank?
    add_error('admin') unless CHECKBOX_VALID_VALUES.include?(@user_param_hash['admin'].downcase)
  end

  def user_param_hash
    @user_param_hash
  end

private
  def field_value(field, value)
    return (value == "yes") if ["hide_mail", "no_self_notified", "admin"].include?(field)
    (value == "yes" ? "1" : "0") if ["warn_on_leaving_unsaved", "send_email"].include?(field)
  end

  def add_error(field)
    self.errors.add(field.to_sym, "is invalid") and return if ["hide_mail", "warn_on_leaving_unsaved", "admin"].include?(field)
    self.errors[:base] << "No Self Notification is invalid" and return if field == "no_self_notified"
    self.errors[:base] << "Send account information to the user is invalid" and return if field == "send_email"
  end

  def attribute_map
    mapped_hash = {}
    @headers.each_with_index do |field, index|
      next if field.blank?
      if (Integer(field) rescue false)
        mapped_hash["custom_field_values"] = (mapped_hash["custom_field_values"] || {}).merge(field => @user_row[index])
      else
        mapped_hash[field] = @user_row[index]
      end
    end
    mapped_hash
  end
end