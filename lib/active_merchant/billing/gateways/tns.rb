# -*- coding: utf-8 -*-
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class TnsGateway < Gateway
      class_inheritable_accessor :url

      # TNS uses only one url for both testing and live transactions
      # To perform test transactions, you need to use a test
      # merchant_id account
      self.url = 'https://secure.ap.tnspayments.com/api/nvp/version/1'

      # possible result codes
      # SUCCESS The transaction was successfully processed
      # PENDING The transaction is currently in progress or pending processing
      # FAILURE The transaction was declined or rejected by the gateway, acquirer or issuer
      # UNKNOWN The result of the transaction is unknown 
      # ERROR
      SUCCESS_TYPES = ["SUCCESS", "PENDING"]
      FAILURE_TYPES = ["FAILURE", "UNKNOWN"]
      GATEWAY_CODES = ["INVALID_REQUEST", "APPROVED"]

      RESPONSE_GATEWAY_CODES            = {
        "APPROVED"                      => "Transaction Approved",
        "UNSPECIFIED_FAILURE"           => "Transaction could not be processed",
        "DECLINED"                      => "Transaction declined by issuer",
        "TIMED_OUT"                     => "Response timed out",
        "EXPIRED_CARD"                  => "Transaction declined due to expired card",
        "INSUFFICIENT_FUNDS"            => "Transaction declined due to insufficient funds",
        "ACQUIRER_SYSTEM_ERROR"         => "Acquirer system error occured processing the transaction",
        "SYSTEM_ERROR"                  => "Internal system error occured processing the transaction",
        "NOT_SUPPORTED"                 => "Transaction type not supported",
        "DECLINED_DO_NOT_CONTACT"       => "Transaction declined - do not contact issuer",
        "ABORTED"                       => "Transaction aborted by card holder",
        "BLOCKED"                       => "Transaction blocked due to Risk or 3D Secure blocking rules",
        "CANCELLED"                     => "Transaction cancelled by card holder",
        "DEFERRED_TRANSACTION_RECEIVED" => "Deferred transaction received and awaiting processing",
        "REFERRED"                      => "Transaction declined - refer to issuer",
        "AUTHENTICATION_FAILED"         => "3D Secure authentication failed",
        "INVALID_CSC"                   => "Invalid card security code",
        "LOCK_FAILURE"                  => "Order locked - another transaction is in progress for this order",
        "SUBMITTED"                     => "Transaction submitted - response has not yet been received",
        "NOT_ENROLLED_3D_SECURE"        => "Card holder is not enrolled in 3D Secure",
        "PENDING"                       => "Transaction is pending",
        "EXCEEDED_RETRY_LIMIT"          => "Transaction retry limit exceeded",
        "DUPLICATE_BATCH"               => "Transaction declined due to duplicate batch",
        "DECLINED_AVS"                  => "Transaction declined due to address verification",
        "DECLINED_CSC"                  => "Transaction declined due to card security code",
        "DECLINED_AVS_CSC"              => "Transaction declined due to address verification and card security code",
        "DECLINED_PAYMENT_PLAN"         => "Transaction declined due to payment plan",
        "UNKNOWN"                       => "Response unknown"
      }

      TRANSACTION_TYPES       = {
        "AUTHORIZATION"       => "Authorization",
        "BALANCE_ENQUIRY"     => "Balance Enquiry",
        "CAPTURE"             => "Capture",
        "CREDIT_PAYMENT"      => "Credit Payment",
        "PRE_AUTHORIZATION"   => "Pre-Authorization",
        "PAYMENT"             => "Payment (Purchase)",
        "REFUND"              => "Refund",
        "VOID_AUTHORIZATION"  => "Void Authorization",
        "VOID_CAPTURE"        => "Void Capture",
        "VOID_CREDIT_PAYMENT" => "Void Credit Payment",
        "VOID_PAYMENT"        => "Void Payment",
        "VOID_REFUND"         => "Void Refund",
        "OTHER"               => "Other transaction types"
      }
      

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['AU']

      self.default_currency = 'AUD'

      # There are two different styles for formatting amounts in use:
      # * :dollars – The amount is formatted as a float dollar amount with two decimal places (Default)
      # * :cents – The amount is formatted as an integer value in cents
      # self.money_format = :cents
      
      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club]
      
      # The homepage URL of the gateway
      self.homepage_url = 'http://www.tnsi.com.au'
      
      # The name of the gateway
      self.display_name = 'Transaction Network Services'
      
      def initialize(options = {})
        requires!(options, :merchant_id, :password)
        @options = options
        @headers = {}
        @headers['Content-Type'] = "application/x-www-form-urlencoded;charset=utf-8"
        @headers['User-Agent'] = "Mozilla"
        super
      end
      
      def authorize(money, creditcard, options = {})
        post = {}
        post['card.token'] = options['card.token'] unless options['card.token'].blank?
        add_invoice(post, options)
        add_creditcard(post, creditcard) unless creditcard.blank?
        add_address(post, creditcard, options)
        add_customer_data(post, options)

       commit('AUTHORIZE', money, post)
      end
      
      def purchase(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)        
        add_address(post, creditcard, options)   
        add_customer_data(post, options)
             
        commit('PAY', money, post)
      end                       

      def store(creditcard, options = {})       
        post = {}

        # store card operation doesn't need the creditcard.first_name field
        creditcard.first_name = nil if creditcard.first_name

        add_creditcard(post, creditcard)

        post['action.tokenOperation'] = 'SAVE'
        
        commit('MANAGE_CARD', nil, post)
      end
      
      def capture(money, transaction_id, options = {})
        post = {}
        post['transaction.id'] = transaction_id
        add_invoice(post, options)

        commit('CAPTURE', money, post)
      end

      def refund(money, transaction_id, options = {})
        post = {}
        post['transaction.id'] = transaction_id
        add_invoice(post, options)
        commit('REFUND', money, post)
      end
      
      def authorize_with_token(money, transaction_id, card_token, options = {})
        post = {'card.token' => card_token}
        add_invoice(post, {:vpc_MerchTxnRef => transaction_id, :order_id => options[:order_id]})
        add_customer_data(post, options)
        commit('AUTHORIZE', money, post)
      end

      def retrieve_transaction(order_id, transaction_id)
        post = {}
        add_invoice(post, {:order_id => order_id, :transaction_id => transaction_id})
        commit('RETRIEVE', nil, post)
      end
      
      private
      
      def add_customer_data(post, options)
        post['customer.ipAddress'] = options[:ip_address] if options[:ip_address]
      end

      def add_address(post, creditcard, options)      
        # post['billing.address.city']          = options[:city]
        # post['billing.address.country']       = options[:country]
        # post['billing.address.phone']         = options[:phone]
        # post['billing.address.postcodeZip']   = options[:postal_code]
        # post['billing.address.stateProvince'] = options[:state]
        # post['billing.address.street']        = options[:street]
      end

      def add_invoice(post, options)
        # The unique identifier of the order, to distinguish it from any other order you ever issue
        post['order.id'] = options[:order_id]

        # The unique identifier of the transaction, to distinguish it from other transactions on the order
        post['transaction.id'] = options[:transaction_id] if options.has_key? :transaction_id
      end
      
      def add_creditcard(post, creditcard)
        post['card.holder.fullName'] = creditcard.first_name if creditcard.first_name.present?
        post['card.number']          = creditcard.number
        post['card.expiry.month']    = creditcard.month
        post['card.expiry.year']     = format(creditcard.year,:two_digits)
        post['card.securityCode']    = creditcard.verification_value if creditcard.verification_value.present?
      end

      def commit(action, money, parameters)
        parameters[:merchant]     = @options[:merchant_id]
        parameters[:apiPassword]  = @options[:password]
        parameters[:apiOperation] = action

        if ['AUTHORIZE', 'CAPTURE', 'REFUND'].include?(action)
          parameters['transaction.amount'] = amount(money)
          parameters['transaction.currency'] = self.default_currency
        end

        # TODO: remove this logging stuff after we iron out the
        # initial bugs
        filtered_post_data = post_data(parameters.merge("card.number" => "[FILTERED]", "card.expiry.month" => "[FILTERED]", "card.securityCode" => "[FILTERED]"))
        puts "\n[XXXXXXXXXXXXXXXX]", "POSTING DATA TO URL: #{self.url}: #{filtered_post_data} ", "[XXXXXXXXXXXXXXXX]\n\n"
        
        if defined?(RAILS_DEFAULT_LOGGER)
          RAILS_DEFAULT_LOGGER.debug "\n[XXXXXXXXXXXXXXXX]"
          RAILS_DEFAULT_LOGGER.debug "POSTING DATA TO URL: #{self.url}: #{filtered_post_data} "
          RAILS_DEFAULT_LOGGER.debug "[XXXXXXXXXXXXXXXX]\n\n"
        end
       
        data = parse( ssl_post(self.url, post_data(parameters), @headers) )

        success = SUCCESS_TYPES.include?(data["result"])

        message = message_from(data)
        
        response = TnsResponse.new(success, message, data, 
          :test => test?, 
          :authorization => data["transaction.receipt"],
          :cvv_result => data["response.cardSecurityCode.acquirerCode"],
          :avs_result => { :code => data["avs"] })

        puts "\n[XXXXXXXXXXXXXXXX]", "RESPONSE DATA FROM PAYMENT GATEWAY: #{response.inspect}", "[XXXXXXXXXXXXXXXX]\n\n"
        
        if defined?(RAILS_DEFAULT_LOGGER)
          RAILS_DEFAULT_LOGGER.debug "\n[XXXXXXXXXXXXXXXX]"
          RAILS_DEFAULT_LOGGER.debug "RESPONSE DATA FROM PAYMENT GATEWAY: #{response.inspect}"
          RAILS_DEFAULT_LOGGER.debug "[XXXXXXXXXXXXXXXX]\n\n"
        end

        return response
      end

      def parse(body)
        results = {}
        
        body.split(/&/).each do |pair|
          key,val = pair.split(/=/)
          results[key] = val
        end

        results
      end      
      
      def message_from(response)
        if response["result"] == "ERROR"
          response_message = CGI.unescape(response["error.explanation"] || response["supportCode"] || "Unsupported error")
        else
          response_message = RESPONSE_GATEWAY_CODES[response["response.gatewayCode"]]          
        end

        return response_message
      end
      
      def post_data(parameters = {})
        parameters.collect { |key, value| "#{key}=#{ CGI.escape(value.to_s)}" }.join("&")
      end

    end

    class TnsResponse < Response
      # add a method to response so we can easily get the
      # transaction_id and order_id
      def transaction_id
        @params["transaction.id"]
      end

      def gateway_code
        @params["response.gatewayCode"]
      end

      def transaction_amount
        @params["transaction.amount"]
      end

      def order_id
        @params["order.id"]
      end
      
      def stored_card_token
        @params["card.token"]
      end
    end

  end
end

