module Rb1drv
  module Errors

    class Error < StandardError
    end

    class ApiError < Error
      attr_reader :api_hash

      def initialize(api_hash)
        @api_hash = api_hash
        super(api_hash.dig('error', 'message'))
      end

      def code
        api_hash.dig('error', 'code')
      end

      def inner_error
        api_hash.dig('error', 'innererror') || {}
      end
    end

  end
end
