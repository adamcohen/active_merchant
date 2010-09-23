module ActiveMerchant #:nodoc:
  
  module Billing #:nodoc:
    
    class DialectVpcGateway < Gateway
      
      FILTERED_PARAMS = ['card_number', 'vpc_CardExp', 'vpc_AccessCode', 'vpc_CardSecurityCode']
      
      TRANSACTIONS = {
        :authorisation => 'pay',
        :purchase => 'pay',
        :capture => 'capture',
        :credit => 'refund',
        :store => 'doRequest',
        :purchase_stored => 'doRequest'
      }
      
      QSI_RESPONSE_CODES = {
        '0' => 'Transaction approved',                        #invoke with amount(00) 
        '1' => 'Transaction could not be processed',          #invoke with amount(10) 
        '2' => 'Transaction declined - contact issuing bank', #invoke with amount(05) 
        '3' => 'No reply from Processing Host',               #invoke with amount(68) 
        '4' => 'Card has expired',                            #invoke with amount(33)
        '5' => 'Insufficient credit',                         #invoke with amount(51)
        
        #The below is for information purposes only - additional 'system error' response codes. 
        #These should not occur after integration is complete and will be thrown as a standard error
        #6 = Payment Server System Error (state of transaction unknow)
        #7 = Payment Server System Error (data validation error - transaction not processed, i.e. card number invalid, incorrect access code)
        #8 = Payment Server System Error (transaction error - state of transaction unknown)
      }
      
      self.supported_countries = ['AU']
      self.default_currency = 'AUD'
      self.money_format = :cents
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club, :jcb]
      self.homepage_url = 'http://www.dialectpayments.com/'
      self.display_name = 'Dialect Payment Gateway'
      
      def initialize(options = {})
        requires!(options,:merchant_id, :access_code)
        @options = options
        super

        # Temporarily override the ssl_strict variable for showcase and systest
        Gateway.ssl_strict = false
      end  
      
      def authorize(money, creditcard, options = {})
        params = {
          :vpc_Amount           => amount(money),
          :card_number          => creditcard.number,
          :vpc_CardExp          => expiry(creditcard),
          :vpc_CardSecurityCode => creditcard.verification_value,
          :transaction_id      => options[:transaction_id],
          :vpc_OrderInfo        => options[:order_id]
        }
        commit(:authorisation, params)
      end
      
      def purchase(money, creditcard, options = {})
        params = {
          :vpc_Amount           => amount(money),
          :card_number          => creditcard.number,
          :vpc_CardExp          => expiry(creditcard),
          :vpc_CardSecurityCode => creditcard.verification_value,
          :transaction_id      => options[:transaction_id],
          :vpc_OrderInfo        => options[:order_id]
        }
        commit(:purchase, params)
      end                       
      
      def capture(money, authorization, options = {})
        params = {
          :transaction_id => options[:transaction_id],
          :vpc_TransNo => authorization,
          :vpc_Amount => amount(money),
          :vpc_User => @options[:user],
          :vpc_Password => @options[:password]
        }
        commit(:capture, params)
      end
      
      def credit(money, authorization, options = {})
        commit(:credit, params)
      end
      
      def store(creditcard, options = {})
        params = {
          :vpc_RequestType      => 'payTemplate',
          :vpc_RequestCommand   => 'doCreateTemplate',
          :card_number          => creditcard.number,
          :vpc_CardExp          => expiry(creditcard)
        }
        commit(:store, params)
      end
      
      def purchase_stored(money, options = {})
        params = {
          :vpc_RequestType      => 'payTemplate',
          :vpc_RequestCommand   => 'doSubTxn',
          :vpc_Amount           => amount(money),
          :transaction_id      => options[:transaction_id],
          :vpc_OrderInfo        => options[:order_id],
          :vpc_TemplateNo       => options[:template_no]
        }
        commit(:purchase_stored, params)
      end
      
      private                       
      
      def commit(action, params)
        if action == :store or action == :purchase_stored
          raw_response = ssl_post(@options[:scp_url], post_data(action, params))
        else
          raw_response = ssl_post(@options[:url], post_data(action, params))
        end

        response = parse( raw_response )
        Response.new(success?(response), message_from(response), response,          
        :authorization => response['TxnResponseCode'],
        :cvv_result    => cvv(response),
        :test          => Base.test?
        )
      end
      
      def post_data(action, params)
        params.update(
                      :vpc_Command => TRANSACTIONS[action],
                      :vpc_Version => 1,
                      :vpc_Merchant => @options[:merchant_id],
                      :vpc_AccessCode =>  @options[:access_code]
        )
        URI.encode(params.map{|k,v| "#{k}=#{v}"}.join('&'))
      end
      
      def expiry(credit_card)
        month = format(credit_card.month, :two_digits)
        year  = format(credit_card.year , :two_digits)
          "#{year}#{month}"
      end
      
      def success?(response)
        response['TxnResponseCode'] == '0'
      end
      
      def cvv(response)
        { 
          :code => response['CSCResultCode'],
          :message => ""
        }.to_s
      end
      
      def parse(response)
        params = {}
        pairs = response.split(/\&/)
        pairs.each do |pair|          
          key, val = pair.chomp.split(/=/, 2)
          params[key.gsub('vpc_', '')] = val unless FILTERED_PARAMS.include?(key)
        end
        params
      end    
      
      def message_from(response)
       (0..5).include?(response['TxnResponseCode'].to_i) == true ? QSI_RESPONSE_CODES[response['TxnResponseCode']] : CGI.unescape(response['Message'])
      end
      
    end
    
  end
  
end