# -*- coding: utf-8 -*-
require 'test_helper'

class RemoteTnsTest < Test::Unit::TestCase

  def setup
    # each order number has to be unique
    File.open("tns_last_used_order_id.txt", File::RDWR|File::CREAT) do |file|
      @order_id = file.read.chomp
      file.rewind
      file.puts(@order_id.to_i + 1)
    end
    
    @gateway = TnsGateway.new(fixtures(:tns_auth_capture1))
    @gateway_auth_capture2 = TnsGateway.new(fixtures(:tns_auth_capture2))
    @gateway_purchase = TnsGateway.new(fixtures(:tns_purchase1))
    @gateway_purchase2 = TnsGateway.new(fixtures(:tns_auth_capture2))

    @amount                                      = 12000
    @unprocessable_transaction_amount            = 12010
    @transaction_declined_refer_to_issuer_amount = 12001
    @transaction_declined_by_issuer_amount       = 12005
    @response_timeout_amount                     = 12068
    @expired_amount                              = 12054
    @insufficient_credit_amount                  = 12051

    @visa_card                            = credit_card('4987654321098769', :month => 5, :year => 13)
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
      :ip_address => '10.10.10.10',
      :order_id => @order_id,
      :billing_address => address,
      :description => 'Store Purchase',
      :vpc_MerchTxnRef => '1234'
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

  def test_authorize_with_multiple_merchants
    assert response = @gateway_auth_capture2.authorize(@amount, @visa_card, @options)
    assert_success response
    assert_equal 'Transaction Approved', response.message
  end

  def test_authorize_fails_without_cvv
    assert response = @gateway.authorize(@amount, @visa_card_without_cvv, @options)
    assert_failure response
    assert_equal "Parameter 'card.securityCode' is required. value: null - reason: No CSC value was provided", response.message
  end

  def test_authorize_fails_with_invalid_cvv_code
    assert response = @gateway.authorize(@amount, @visa_card_with_invalid_cvv_code, @options)
    assert_failure response
    assert_equal 'Transaction blocked due to Risk or 3D Secure blocking rules', response.message
  end

  def test_authorize_fails_with_unprocessed_cvv_code
    assert response = @gateway.authorize(@amount, @visa_card_with_unprocessed_cvv_code, @options)
    assert_failure response
    assert_equal 'Transaction blocked due to Risk or 3D Secure blocking rules', response.message
  end

  def test_authorize_fails_with_unregistered_cvv_code
    assert response = @gateway.authorize(@amount, @visa_card_with_unregistered_cvv_code, @options)
    assert_failure response
    assert_equal 'Transaction blocked due to Risk or 3D Secure blocking rules', response.message
  end

  # FIXME: for some reason this allows duplicate transactions to be
  # authorized with the same transaction id
  # def test_authorize_must_have_unique_id
  #   assert response = @gateway.authorize(@amount, @visa_card, @options)
  #   assert_success response
  #   assert_equal 'Transaction Approved', response.message

  #   assert response = @gateway.authorize(@amount, @visa_card, @options)
  #   assert_failure response
  #   assert_equal 'Transaction or Order ID supplied already exists, but the transaction parameters do not match. To retry a transaction, the parameters must be the same. For new transactions, order.id must be unique and transaction.id must be unique for the order.', response.message
  # end

  def test_authorize_with_invalid_credit_card
    assert response = @gateway.authorize(@amount, @invalid_visa_card, @options)
    assert_failure response
    assert_equal 'Transaction declined by issuer', response.message
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
    amount = @amount
    assert response = @gateway.authorize(amount, @visa_card, @options)
    assert_success response
    assert_equal 'Transaction Approved', response.message
    assert response.authorization
    # assert capture = @gateway.capture(amount, auth.authorization)
    # assert_success capture
  end

  # def test_failed_capture
  #   assert response = @gateway.capture(@amount, '')
  #   assert_failure response
  #   assert_equal 'REPLACE WITH GATEWAY FAILURE MESSAGE', response.message
  # end

  def test_invalid_login
    gateway = TnsGateway.new(
                :login => '',
                :password => ''
              )
    assert response = gateway.authorize(@amount, @visa_card, @options)
    assert_failure response
    assert_equal "Parameter 'apiPassword' value '' is invalid. Length is 0 characters, but must be at least 32", response.message
  end
end
