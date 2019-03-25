require 'google/apis/gmail_v1'
require 'googleauth'

desc "generate refresh token for gmail credentials"
task "gmail:credentials", [:group_name] => [:environment] do |_, args|
  group = Group.find_by(name: args[:group_name])
  if !group
    puts "ERROR: Expecting rake gmail:credentials[group_name]"
    exit 1
  end

  credentials = Google::Auth::UserRefreshCredentials.new(
    client_id: group.custom_fields[Jobs::ProcessGmail::GMAIL_CLIENT_ID_FIELD],
    client_secret: group.custom_fields[Jobs::ProcessGmail::GMAIL_CLIENT_SECRET_FIELD],
    scope: Google::Apis::GmailV1::AUTH_SCOPE,
    redirect_uri: "urn:ietf:wg:oauth:2.0:oob"
  )

  puts "Authorize Discourse at #{credentials.authorization_uri.to_s}"

  puts "Enter the code:"
  credentials.code = STDIN.gets
  credentials.fetch_access_token!

  puts "Your access token is #{credentials.access_token}."
  group.custom_fields[Jobs::ProcessGmail::GMAIL_REFRESH_TOKEN_FIELD] = credentials.access_token
  group.save_custom_fields
end
