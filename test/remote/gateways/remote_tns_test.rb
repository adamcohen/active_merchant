# -*- coding: utf-8 -*-
require 'test_helper'

# run these tests using:
# cd vendor/gems/active_merchant-1.7.2; 
# bundle exec ruby -I test test/remote/gateways/remote_tns_test.rb

# testing credentials are stored in ~/.active_merchant/fixtures.yml
class RemoteTnsTest < Test::Unit::TestCase

  def setup
    # each order number has to be unique
    @order_id = Time.now.to_f.to_s.delete(".")

    @transaction_id = Time.now.strftime("%Y%m%d%H%M%S").to_i

    @gateway               = TnsGateway.new(fixtures(:tns))
    @gateway_auth_capture2 = TnsGateway.new(fixtures(:tns_auth_capture2))
    @gateway_purchase      = TnsGateway.new(fixtures(:tns_purchase1))
    @gateway_purchase2     = TnsGateway.new(fixtures(:tns_purchase2))

    # need to configure the proxy host/port to get this test working
    # on ci. Also need to add http_proxy_host and http_proxy_port
    # configuration directives to the ~/.active_merchant/fixtures.yml
    # file
    TnsGateway.http_proxy_host = fixtures(:tns)[:http_proxy_host]
    TnsGateway.http_proxy_port = fixtures(:tns)[:http_proxy_port]

    @amount                                      = 12000
    @nonzero_cent_amount                         = 12011
    @unprocessable_transaction_amount            = 12010
    @transaction_declined_refer_to_issuer_amount = 12001
    @transaction_declined_by_issuer_amount       = 12005
    @response_timeout_amount                     = 12068
    @expired_amount                              = 12054
    @insufficient_credit_amount                  = 12051

    @visa_card                            = credit_card('4987654321098769', :month => 5, :year => 13)
    @visa_card_with_weird_name            = credit_card('4987654321098769', :month => 5, :year => 13, :first_name => "scriptalert><s")
    @visa_card_without_name               = credit_card('4987654321098769', :month => 5, :year => 13, :first_name => nil)
    @invalid_visa_card                    = credit_card('4111111111111111', :month => 5, :year => 13)
    @visa_card_without_cvv                = credit_card('4987654321098769', :month => 5, :year => 13,
                                                        :verification_value => nil)

    @visa_card_with_invalid_cvv_code      = credit_card('4987654321098769', :month => 5, :year => 13,
                                                        :verification_value => 104)

    @visa_card_with_unregistered_cvv_code = credit_card('4987654321098769', :month => 5, :year => 13,
                                                        :verification_value => 103)

    @visa_card_with_unprocessed_cvv_code  = credit_card('4987654321098769', :month => 5, :year => 13,
                                                        :verification_value => 102)
    
    @options = { 
      :ip_address      => '10.10.10.10',
      :order_id        =>  @order_id,
      :billing_address =>  address,
      :description     => 'Store Purchase',
      :transaction_id  =>  @transaction_id
    }
  end

  # Pay (also known as Purchase) — requires a single transaction to
  # authorize the payment and transfer funds from the cardholder's
  # account to your account. This mode effectively completes the
  # Authorize and Capture operations at the same time. Pay is the most
  # common type of payment model used by merchants to accept
  # payments. Pay model is used when the merchant is allowed to bill the
  # cardholder's account immediately, for example when providing
  # services or goods on the spot.
  
  # enable after TNS adds another account to enable purchase payment models
  # def test_successful_purchase
  #   assert response = @gateway.purchase(@amount, @credit_card, @options)
  #   assert_success response
  #   assert_equal 'REPLACE WITH SUCCESS MESSAGE', response.message
  # end

  # def test_unsuccessful_purchase
  #   assert response = @gateway.purchase(@amount, @declined_card, @options)
  #   assert_failure response
  #   assert_equal 'REPLACE WITH FAILED PURCHASE MESSAGE', response.message
  # end

  def test_authorize
    assert response = @gateway.authorize(@amount, @visa_card, @options)
    assert_success response
    assert_equal 'Transaction Approved', response.message
  end

  def test_authorize_fails_with_nonzero_cent_amount
    assert response = @gateway.authorize(@nonzero_cent_amount, @visa_card, @options)
    assert_failure response
    assert_equal 'Transaction could not be processed', response.message
  end

  def test_authorize_succeeds_with_weird_name
    assert response = @gateway.authorize(@amount, @visa_card_with_weird_name, @options)
    assert_success response
    assert_equal 'Transaction Approved', response.message
  end  
  
  # def test_authorize_with_multiple_merchants
  #   assert response = @gateway_auth_capture2.authorize(@amount, @visa_card, @options)
  #   assert_success response
  #   assert_equal 'Transaction Approved', response.message
  # end

  # The following 4 tests are dependent on the CSC rules as specified
  # in your merchant administration preferences
  # def test_authorize_fails_without_cvv
  #   assert response = @gateway.authorize(@amount, @visa_card_without_cvv, @options)
  #   assert_failure response
  #   assert_equal "Parameter 'card.securityCode' is required. value: null - reason: No CSC value was provided", response.message
  # end

  # def test_authorize_fails_with_invalid_cvv_code
  #   assert response = @gateway.authorize(@amount, @visa_card_with_invalid_cvv_code, @options)
  #   assert_failure response
  #   assert_equal 'Transaction blocked due to Risk or 3D Secure blocking rules', response.message
  # end

  # def test_authorize_fails_with_unprocessed_cvv_code
  #   assert response = @gateway.authorize(@amount, @visa_card_with_unprocessed_cvv_code, @options)
  #   assert_failure response
  #   assert_equal 'Transaction blocked due to Risk or 3D Secure blocking rules', response.message
  # end

  # def test_authorize_fails_with_unregistered_cvv_code
  #   assert response = @gateway.authorize(@amount, @visa_card_with_unregistered_cvv_code, @options)
  #   assert_failure response
  #   assert_equal 'Transaction blocked due to Risk or 3D Secure blocking rules', response.message
  # end

  def test_authorize_must_have_unique_id
    assert response = @gateway.authorize(@amount, @visa_card, @options)
    assert_success response
    assert_equal 'Transaction Approved', response.message

    assert response = @gateway.authorize(@amount+1, @visa_card, @options)
    assert_failure response
    assert_equal 'Transaction or Order ID supplied already exists, but the transaction parameters do not match. To retry a transaction, the parameters must be the same. For new transactions, order.id must be unique and transaction.id must be unique for the order.', response.message
  end

  def test_authorize_with_invalid_credit_card
    assert response = @gateway.authorize(@amount, @invalid_visa_card, @options)
    assert_failure response
    assert_equal 'Transaction could not be processed', response.message
  end

  def test_authorize_with_expired_credit_card
    assert response = @gateway.authorize(@expired_amount, @visa_card, @options)
    assert_failure response
    assert_equal 'Transaction declined due to expired card', response.message
  end

  def test_authorize_with_insufficient_funds_credit_card
    assert response = @gateway.authorize(@insufficient_credit_amount, @visa_card, @options)
    assert_failure response
    assert_equal "Transaction declined due to insufficient funds", response.message
  end

  # the following test will cause all subsequent Auths to return the
  # Pending state, disable for now
  # def test_authorize_with_response_timeout
  #   assert response = @gateway.authorize(@response_timeout_amount, @visa_card, @options)
  #   assert_failure response
  #   assert_equal "Response timed out", response.message
  # end

  # can't test the following two assertions - sometimes they get
  # failures, sometimes they get pending results
  # def test_authorize_with_unprocessable_transaction
  #   assert response = @gateway.authorize(@unprocessable_transaction_amount, @visa_card, @options)
  #   assert_success response
  #   assert_equal "Transaction could not be processed", response.message
  # end

  # def test_authorize_with_transaction_declined_refer_to_issuer
  #   assert response = @gateway.authorize(@transaction_declined_refer_to_issuer_amount, @visa_card, @options)
  #   assert_failure response
  #   assert_equal "Transaction declined - refer to issuer", response.message
  # end

  def test_authorize_with_declined_by_issuer
    assert response = @gateway.authorize(@transaction_declined_by_issuer_amount, @visa_card, @options)
    assert_failure response
    assert_equal "Transaction declined by issuer", response.message
  end  
  
  def test_authorize_and_capture
    assert response = @gateway.authorize(@amount, @visa_card, @options)
    assert_success response
    assert_equal 'Transaction Approved', response.message
    assert response.transaction_id

    assert capture = @gateway.capture(@amount, response.transaction_id.to_i + 1, :order_id => response.order_id)
    assert_success capture
  end

  def test_authorize_and_capture_with_nonzero_cent_amount
    assert response = @gateway.authorize(@amount, @visa_card, @options)
    assert_success response
    assert_equal 'Transaction Approved', response.message
    assert response.transaction_id

    assert capture = @gateway.capture(5084, response.transaction_id.to_i + 1, :order_id => response.order_id)
    assert_success capture
  end

  def test_authorize_and_capture_partial_amount
    partial_amount = @amount - 10000

    assert response = @gateway.authorize(@amount, @visa_card, @options)
    assert_success response
    assert_equal 'Transaction Approved', response.message
    assert response.transaction_id

    assert capture = @gateway.capture(partial_amount, response.transaction_id.to_i + 1, :order_id => response.order_id)
    assert_success capture
  end

  def test_authorize_and_capture_fails_when_capturing_amount_larger_than_original_authorized_amount
    assert response = @gateway.authorize(@amount, @visa_card, @options)
    assert_success response
    assert_equal 'Transaction Approved', response.message
    assert response.transaction_id

    assert capture = @gateway.capture(@amount + 100000, response.transaction_id.to_i + 1, :order_id => response.order_id)
    assert_failure capture
    assert_match /Requested capture amount exceeds outstanding authorized amount/, capture.message
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, @transaction_id, :order_id => @order_id)
    assert_failure response
    assert_match /Parameter 'order\.id' value '#{@order_id}' is invalid. value: #{@order_id} - reason: No payments identified/, response.message
  end

  def test_authorize_and_capture_and_refund
    assert response = @gateway.authorize(@amount, @visa_card, @options)
    assert_success response
    assert_equal 'Transaction Approved', response.message
    assert response.transaction_id

    assert capture = @gateway.capture(@amount, response.transaction_id.to_i + 1, :order_id => response.order_id)
    assert_success capture
    
    assert refund = @gateway.refund(@amount, response.transaction_id.to_i + 2, :order_id => response.order_id)
    assert_success refund
  end
  
  def test_failed_refund
    assert response = @gateway.refund(@amount, @transaction_id, {:order_id => @order_id})
    assert_failure response
    assert_match /Parameter 'order\.id' value '#{@order_id}' is invalid. value: #{@order_id} - reason: No payments identified/, response.message
  end
  
  def test_retrieve_transaction
    assert response = @gateway.authorize(@amount, @visa_card, @options)
    assert_success response
    assert_equal 'Transaction Approved', response.message
    assert response.transaction_id

    assert retrieve_transaction = @gateway.retrieve_transaction(response.order_id, response.transaction_id)
    assert_success retrieve_transaction
    assert_equal 'Transaction Approved', retrieve_transaction.message
  end

  def test_retrieve_declined_transaction
    assert declined_by_issuer_response = @gateway.authorize(@transaction_declined_by_issuer_amount, @visa_card, @options)
    assert_failure declined_by_issuer_response
    assert_equal "Transaction declined by issuer", declined_by_issuer_response.message

    assert retrieve_declined_transaction = @gateway.retrieve_transaction(declined_by_issuer_response.order_id, declined_by_issuer_response.transaction_id)
    assert_failure retrieve_declined_transaction
    assert_equal "Transaction declined by issuer", retrieve_declined_transaction.message
  end

  def test_store_credit_card
    assert response = @gateway.store(@visa_card_without_name, @options)
    assert_success response

    assert_equal 'Transaction Approved', response.message
  end

  def test_store_credit_card_returns_token
    assert response = @gateway.store(@visa_card_without_name, @options)
    assert_success response

    assert_not_nil response.stored_card_token
  end

  def test_store_credit_card_returns_masked_card_num
    assert response = @gateway.store(@visa_card_without_name, @options)
    assert_success response

    ccnum = @visa_card_without_name.number
    
    assert_equal response.params['card.number'], "#{ccnum[0..5]}xxxxxxx#{ccnum[-3..-1]}"
  end
  
  def test_store_credit_card_succeeds_with_unexpected_parameter
    assert response = @gateway.store(@visa_card, @options)
    assert_success response

    assert_not_nil response.stored_card_token
    assert_equal 'Transaction Approved', response.message
  end

  def test_store_card_and_auth_with_token
    assert response = @gateway.store(@visa_card_without_name, @options)
    assert_success response
    card_token = response.stored_card_token
    response = @gateway.authorize(@amount, nil, @options.merge('card.token' => card_token))
    assert_success response
    assert_equal 'Transaction Approved', response.message
  end
  
  def test_store_card_and_auth_with_token_with_error
    assert response = @gateway.store(@visa_card_without_name, @options)
    assert_success response
    card_token = response.stored_card_token
    response = @gateway.authorize(@transaction_declined_refer_to_issuer_amount, nil, @options.merge('card.token' => card_token))
    assert_failure response
    assert_equal 'Transaction declined by issuer', response.message
  end

  def test_invalid_login
    gateway = TnsGateway.new(
                :merchant_id => '',
                :password => ''
              )
    assert response = gateway.authorize(@amount, @visa_card, @options)
    assert_failure response
    assert_equal "Parameter 'merchant' value '' is invalid. Length is 0 characters, but must be at least 1", response.message
  end

  def test_incorrect_merchant_id
    gateway = TnsGateway.new(
                :merchant_id => 'VERYLONGMERCHANTIDENTIFIER',
                :password => 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
              )
    assert response = gateway.authorize(@amount, @visa_card, @options)
    assert_failure response
    assert_match /Parameter 'merchant' value '.*' is invalid. Length is \d+ characters, but must be less than 17/, response.message
  end

end
