Redmine::Plugin.register :csv_import_users do
  name 'redmine_csv_import_users'
  author 'Systango'
  description 'This is a plugin for adding multiple users using CSV'
  version '1.0.0'
  requires_redmine :version_or_higher => '2.2.4'
end
