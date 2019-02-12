module Rb1drv
  module Errors

    class BaseError < StandardError
    end

    class ApiError < BaseError
      UNKNOWN_ERROR = 'unknown_error'
      attr_reader :response, :code, :query_path

      def initialize(response, query_path)
        @query_path = query_path
        @response = response
        @code = response.dig('error', 'code')
        message = response.dig('error', 'message') || UNKNOWN_ERROR
        super(message)
      end
    end

  end
end
