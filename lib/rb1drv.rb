require 'excon'
require 'oauth2'
require "rb1drv/version"

module Rb1drv
  # Base class to support oauth2 authentication and sending simple API requests.
  #
  # Call +#root+ or +#get+ to get an +OneDriveDir+ or +OneDriveFile+ to wotk with.
  class OneDrive
    attr_reader :oauth2_client, :logger, :access_token
    # Instanciates with app id and secret.
    def initialize(client_id, client_secret, callback_url, logger=nil)
      @client_id = client_id
      @client_secret = client_secret
      @callback_url = callback_url
      @logger =  logger
      @oauth2_client = OAuth2::Client.new client_id, client_secret,
        authorize_url: 'https://login.microsoftonline.com/common/oauth2/v2.0/authorize',
        token_url: 'https://login.microsoftonline.com/common/oauth2/v2.0/token'
      @conn = Excon.new('https://graph.microsoft.com/', persistent: true)
      @conn.logger = @logger if @logger
    end

    # Issues requests to API endpoint.
    #
    # @param uri [String] relative path of the API
    # @param data [Hash] JSON data to be post
    # @param verb [Symbol] HTTP request verb if data is given
    #
    # @return [Hash] response from API.
    def request(uri, data=nil, verb=:post)
      @logger.info(uri) if @logger
      query = {
        path: File.join('v1.0/me/', uri),
        headers: {
          'Authorization': "Bearer #{@access_token.token}"
        }
      }
      if data
        query[:body] = JSON.generate(data)
        query[:headers]['Content-Type'] = 'application/json'
        @logger.info(query[:body]) if @logger
        verb = :post unless [:post, :put, :delete].include?(verb)
        response = @conn.send(verb, query)
      else
        response = @conn.get(query)
      end
      JSON.parse(response.body)
    end
  end
end

require 'rb1drv/auth'
require 'rb1drv/onedrive'
require 'rb1drv/onedrive_item'
require 'rb1drv/onedrive_dir'
require 'rb1drv/onedrive_file'
require 'rb1drv/onedrive_404'
