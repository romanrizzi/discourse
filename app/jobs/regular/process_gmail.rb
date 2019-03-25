require 'google/apis/gmail_v1'
require 'googleauth'
require_dependency 'imap'

module Jobs
  class ProcessGmail < Jobs::Scheduled
    sidekiq_options retry: false

    APPLICATION_NAME = "Discourse Sync Service"
    GMAIL_REDIRECT_URI = "urn:ietf:wg:oauth:2.0:oob"

    GMAIL_CLIENT_ID_FIELD = "gmail_client_id"
    GMAIL_CLIENT_SECRET_FIELD = "gmail_client_secret"
    GMAIL_REFRESH_TOKEN_FIELD = "gmail_authorization"
    GMAIL_HISTORY_ID_FIELD = "gmail_history_id"

    def execute(args)
      @args = args || {}

      group = Group.find_by(email_username: args[:email_address])
      if !group
        Rails.logger.warn("No group was found for email address: #{args[:email_address]}.")
        return
      end

      credentials = Google::Auth::UserRefreshCredentials.new(
        client_id: group.custom_fields[GMAIL_CLIENT_ID_FIELD],
        client_secret: group.custom_fields[GMAIL_CLIENT_SECRET_FIELD],
        scope: Google::Apis::GmailV1::AUTH_SCOPE,
        redirect_uri: GMAIL_REDIRECT_URI,
        refresh_token: group.custom_fields[GMAIL_REFRESH_TOKEN_FIELD]
      )
      credentials.fetch_access_token!

      service = Google::Apis::GmailV1::GmailService.new
      service.client_options.application_name = APPLICATION_NAME
      service.authorization = credentials

      sync = Imap::Sync.new(group, Imap::Providers::Gmail)
      last_history_id = group.custom_fields[GMAIL_HISTORY_ID_FIELD] || args[:history_id]
      page_token = nil

      loop do
        list = service.list_user_histories(args[:email_address], start_history_id: last_history_id, page_token: page_token)
        (list.history || []).each do |history|
          (history.messages || []).each do |message|
            begin
              message = service.get_user_message(args[:email_address], message.id, format: 'raw')
              email = {
                "UID" => message.id,
                "FLAGS" => [],
                "LABELS" => message.label_ids,
                "RFC822" => message.raw,
              }

              receiver = Email::Receiver.new(email["RFC822"],
                destinations: [{ type: :group, obj: group }],
                uid_validity: args[:history_id],
                uid: -1
              )
              receiver.process!
              sync.update_topic(email, receiver.incoming_email)

              last_history_id = history.id
            rescue Email::Receiver::ProcessingError => e
            end
          end
        end

        page_token = list.next_page_token
        break if page_token == nil
      end

      group.custom_fields[GMAIL_HISTORY_ID_FIELD] = last_history_id
      group.save_custom_fields

      nil
    end
  end
end
