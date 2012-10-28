require 'test_helper'

class TnsTest < Test::Unit::TestCase
  def setup
    @gateway = TnsGateway.new(
                 :merchant_id => 'TestMerchant',
                 :password => 'password'
               )

    @credit_card = credit_card
    @amount = 100
    
    @options = { 
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase',
    }
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    
    assert_equal '100831000004', response.authorization
    assert response.test?
  end

  def test_currency
    assert_equal 'AUD', @gateway.default_currency

    @gateway.default_currency = 'GBP'
    assert_equal 'GBP', @gateway.default_currency
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_amount_style   
   assert_equal '10.34', @gateway.send(:amount, 1034)
                                                  
   assert_raise(ArgumentError) do
     @gateway.send(:amount, '1034')
   end
  end

  def test_supported_countries
    assert_equal ['AU'], TnsGateway.supported_countries
  end

  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :diners_club], TnsGateway.supported_cardtypes
  end

  def test_test_flag_should_be_set_when_using_test_login_in_production
    Base.gateway_mode = :production
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_success response
    assert response.test?
  ensure
    Base.gateway_mode = :test
  end
  
  private
  
  # Place raw successful response from gateway here
  private  
  def successful_purchase_response
    "card.expiry.month=5&card.expiry.year=13&card.number=498765xxxxxxx769&card.type=VISA&merchant=TESTWESTFIELDAPI&order.id=10000000999&order.totalAuthorizedAmount=100.00&order.totalCapturedAmount=0.00&order.totalRefundedAmount=0.00&response.acquirerCode=00&response.debugInformation=%5B0%5D%5BApproved%5D%5BAAAAAAA3X9%5D&response.gatewayCode=APPROVED&result=SUCCESS&transaction.acquirer.id=NAB_MAA&transaction.amount=100.00&transaction.authorizationCode=000004&transaction.batch=1&transaction.currency=AUD&transaction.id=1234&transaction.receipt=100831000004&transaction.terminal=123456&transaction.type=AUTHORIZATION%"
  end
  
  # Place raw failed response from gateway here
  def failed_purchase_response
    # "explanation=Transaction+or+Order+ID+supplied+already+exists%2C+but+the+transaction+parameters+do+not+match.+To+retry+a+transaction%2C+the+parameters+must+be+the+same.+For+new+transactions%2C+order.id+must+be+unique+and+transaction.id+must+be+unique+for+the+order.&gatewayCode=INVALID_REQUEST&result=ERROR"

    # "explanation=Parameter+%27card.securityCode%27+value+%27xxx%27+is+invalid.+value%3A+xxx+-+reason%3A+Invalid+secure+code+length&gatewayCode=INVALID_REQUEST&result=ERROR"

    "explanation=Parameter+%27card.number%27+value+%27111111xxxxxx1111%27+is+invalid.+value%3A+111111xxxxxxx111+-+reason%3A+Invalid+card+number&gatewayCode=INVALID_REQUEST&result=ERROR"
  end
end
