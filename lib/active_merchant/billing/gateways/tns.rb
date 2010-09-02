module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class TnsGateway < Gateway
      TEST_URL = 'https://staging.uat.dialectpayments.com/api/nvp/version/1'
      LIVE_URL = 'https://staging.uat.dialectpayments.com/api/nvp/version/1'
      LOCALHOST_URL = 'http://localhost/api/nvp/version/1'
      URL = TEST_URL
      # URL = LOCALHOST_URL

      # possible result codes
      # SUCCESS The transaction was successfully processed
      # PENDING The transaction is currently in progress or pending processing
      # FAILURE The transaction was declined or rejected by the gateway, acquirer or issuer
      # UNKNOWN The result of the transaction is unknown 
      # ERROR
      SUCCESS_TYPES = ["SUCCESS", "PENDING"]
      FAILURE_TYPES = ["FAILURE", "UNKNOWN"]
      GATEWAY_CODES = ["INVALID_REQUEST", "APPROVED"]

      RESPONSE_GATEWAY_CODES = {
        "APPROVED" => "Transaction Approved",
        "UNSPECIFIED_FAILURE" => "Transaction could not be processed",
        "DECLINED" => "Transaction declined by issuer",
        "TIMED_OUT" => "Response timed out",
        "EXPIRED_CARD" => "Transaction declined due to expired card",
        "INSUFFICIENT_FUNDS" => "Transaction declined due to insufficient funds",
        "ACQUIRER_SYSTEM_ERROR" => "Acquirer system error occured processing the transaction",
        "SYSTEM_ERROR" => "Internal system error occured processing the transaction",
        "NOT_SUPPORTED" => "Transaction type not supported",
        "DECLINED_DO_NOT_CONTACT" => "Transaction declined - do not contact issuer",
        "ABORTED" => "Transaction aborted by card holder",
        "BLOCKED" => "Transaction blocked due to Risk or 3D Secure blocking rules",
        "CANCELLED" => "Transaction cancelled by card holder",
        "DEFERRED_TRANSACTION_RECEIVED" => "Deferred transaction received and awaiting processing",
        "REFERRED" => "Transaction declined - refer to issuer",
        "AUTHENTICATION_FAILED" => "3D Secure authentication failed",
        "INVALID_CSC" => "Invalid card security code",
        "LOCK_FAILURE" => "Order locked - another transaction is in progress for this order",
        "SUBMITTED" => "Transaction submitted - response has not yet been received",
        "NOT_ENROLLED_3D_SECURE" => "Card holder is not enrolled in 3D Secure",
        "PENDING" => "Transaction is pending",
        "EXCEEDED_RETRY_LIMIT" => "Transaction retry limit exceeded",
        "DUPLICATE_BATCH" => "Transaction declined due to duplicate batch",
        "DECLINED_AVS" => "Transaction declined due to address verification",
        "DECLINED_CSC" => "Transaction declined due to card security code",
        "DECLINED_AVS_CSC" => "Transaction declined due to address verification and card security code",
        "DECLINED_PAYMENT_PLAN" => "Transaction declined due to payment plan",
        "UNKNOWN" => "Response unknown"
      }

      TRANSACTION_TYPES = {
        "AUTHORIZATION" => "Authorization",
        "BALANCE_ENQUIRY" => "Balance Enquiry",
        "CAPTURE" => "Capture",
        "CREDIT_PAYMENT" => "Credit Payment",
        "PRE_AUTHORIZATION" => "Pre-Authorization",
        "PAYMENT" => "Payment (Purchase)",
        "REFUND" => "Refund",
        "VOID_AUTHORIZATION" => "Void Authorization",
        "VOID_CAPTURE" => "Void Capture",
        "VOID_CREDIT_PAYMENT" => "Void Credit Payment",
        "VOID_PAYMENT" => "Void Payment",
        "VOID_REFUND" => "Void Refund",
        "OTHER" => "Other transaction types"
      }
      

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['AU']

      self.default_currency = 'AUD'

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club]
      
      # The homepage URL of the gateway
      self.homepage_url = 'http://www.tnsi.com.au'
      
      # The name of the gateway
      self.display_name = 'Transaction Network Services'
      
      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        @headers = {}
        @headers['Content-Type'] = "application/x-www-form-urlencoded;charset=utf-8"
        @headers['User-Agent'] = "Mozilla"
        super
      end
      
      def authorize(money, creditcard, options = {})
        post = {}

        add_invoice(post, options)
        add_creditcard(post, creditcard)
        # add_address(post, creditcard, options)        
        # add_customer_data(post, options)

       commit('AUTHORIZE', money, post)
      end
      
      def purchase(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)        
        add_address(post, creditcard, options)   
        add_customer_data(post, options)
             
        commit('sale', money, post)
      end                       
    
      def capture(money, authorization, options = {})
        commit('CAPTURE', money, post)
      end
    
      private                       
      
      def add_customer_data(post, options)
      end

      def add_address(post, creditcard, options)      
      end

      def add_invoice(post, options)
        post['order.id'] = options[:order_id]
      end
      
      def add_creditcard(post, creditcard)
        post['card.holder.fullName'] = creditcard.first_name
        post['card.number']          = creditcard.number
        post['card.expiry.month']    = creditcard.month
        post['card.expiry.year']     = creditcard.year
        post['card.securityCode']    = creditcard.verification_value if creditcard.verification_value.present?
      end

      def commit(action, money, parameters)
        parameters[:merchant]     = @options[:login]
        parameters[:apiPassword]  = @options[:password]
        parameters[:apiOperation] = action
        parameters['transaction.amount'] = amount(money)
        parameters['transaction.currency'] = self.default_currency
        parameters['transaction.id'] = rand(1234)

        puts "\nXXXXXXXXXXXXXXXX", "COMMITTING POST DATA: #{post_data(parameters)} length: #{post_data(parameters).length}"        , "XXXXXXXXXXXXXXXX\n\n"
        
        data = parse( ssl_post(URL, post_data(parameters), @headers) )

        success = SUCCESS_TYPES.include?(data["result"])

        message = message_from(data)
        
        Response.new(success, message, data, 
          :test => Base.test?, 
          :authorization => data["transaction.receipt"],
          :cvv_result => data["cvv"],
          :avs_result => { :code => data["avs"] }
        )
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
        puts "response: #{response.inspect}"
        if response["result"] == "ERROR"
          return CGI.unescape(response["explanation"] || response["supportCode"])
        else
          return RESPONSE_GATEWAY_CODES[response["response.gatewayCode"]]          
        end
      end
      
      def post_data(parameters = {})
        parameters.collect { |key, value| "#{key}=#{ CGI.escape(value.to_s)}" }.join("&")
      end
    end
  end
end

