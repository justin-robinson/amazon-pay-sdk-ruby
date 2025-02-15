# rubocop:disable all

require 'test_helper'

class AmazonPayUnitTest < Minitest::Test
# If using Ruby 2.1: class AmazonPayUnitTest < MiniTest::Unit::TestCase

  MERCHANT_ID = 'MERCHANT_ID'
  ACCESS_KEY = 'ACCESS_KEY'
  SECRET_KEY = 'SECRET_KEY'
  PRIVATE_KEY = OpenSSL::PKey::RSA.generate(2048)
  SANDBOX = true
  AMAZON_ORDER_REFERENCE_ID = 'AMAZON_ORDER_REFERENCE_ID'
  AMAZON_BILLING_AGREEMENT_ID = 'AMAZON_BILLING_AGREEMENT_ID'
  AMOUNT = 'AMOUNT'
  AUTHORIZATION_REFERENCE_ID = 'AUTHORIZATION_REFERENCE_ID'
  CAPTURE_REFERENCE_ID = 'CAPTURE_REFERENCE_ID'
  REFUND_REFERENCE_ID = 'REFUND_REFERENCE_ID'
  MWS_ENDPOINT = "mws.amazonservices.com"
  SANDBOX_STR = "OffAmazonPayments_Sandbox"
  NEXT_PAGE_TOKEN = '1eUc0QkJMVnJpcGgrbDNHclpIUT09IiwibWFya2V0cGxhY2VJZCI6IkEzQlhCMFlOM1hIMTdIIn0'
  START_TIME = '2017-05-20T03:23:21.923Z'
  START_TIME_ENCODED = '2017-05-20T03%3A23%3A21.923Z'
  END_TIME = '2017-05-27T03:23:21.923Z'
  END_TIME_ENCODED = '2017-05-27T03%3A23%3A21.923Z'
  QUERY_ID = '1234-example-order'
  QUERY_ID_TYPE = 'SellerOrderId'
  SUCCESS_URL = 'https://pay.amazon.com/success.html'
  FAILURE_URL = 'https://pay.amazon.com/failure.html'
  SUCCESS_URL_ENCODED = 'https%3A%2F%2Fpay.amazon.com%2Fsuccess.html'
  FAILURE_URL_ENCODED = 'https%3A%2F%2Fpay.amazon.com%2Ffailure.html'

  DEFAULT_HASH = {
    'AWSAccessKeyId' => ACCESS_KEY,
    'SignatureMethod' => 'HmacSHA256',
    'SignatureVersion' => '2',
    'Version' => AmazonPay::API_VERSION
  }

  HEADERS = {
    'Accept'=>'*/*',
    'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
    'User-Agent'=>"#{AmazonPay::SDK_NAME}/#{AmazonPay::VERSION}; (#{@application_name + '/' if @application_name }#{@application_version.to_s + ';' if @application_version} #{RUBY_VERSION}; #{RUBY_PLATFORM})"
  }

  IPN_HEADERS = { 'x-amz-sns-message-type' => 'Notification' }

  IPN_BODY = {
    'Type' => 'Type',
    'MessageId' => 'MessageId',
    'TopicArn' => 'TopicArn',
    'Message' => {
      'NotificationType' => 'NotificationType',
      'SellerId' => 'SellerId',
      'ReleaseEnvironment' => 'ReleaseEnvironment',
      'Version' => 'Version',
      'NotificationData' => 'NotificationData',
      'Timestamp' => 'Timestamp'
    }.to_json,
    'Timestamp' => 'Timestamp',
    'Signature' => 'Signature',
    'SignatureVersion' => 'SignatureVersion',
    'SigningCertURL' => 'https://test.com/test.pem',
    'UnsubscribeURL' => 'UnsubscribeURL',
  }.to_json

  def setup
    @client = AmazonPay::Client.new(MERCHANT_ID, ACCESS_KEY, SECRET_KEY, sandbox: SANDBOX, private_key: PRIVATE_KEY)
    @operation = AmazonPay::Request.new(
      {'Action' => 'Test'},
      {},
      DEFAULT_HASH,
      MWS_ENDPOINT,
      SANDBOX_STR,
      SECRET_KEY,
      :ENV,
      nil,
      nil,
      nil,
      true,
      nil,
      nil,
      false,
      nil,
      nil
    )
    @ipn = AmazonPay::IpnHandler.new(IPN_HEADERS, IPN_BODY)
  end

  def test_sign_payload
    payload_json = '{"key1":"value1"}'
    signed_payload = @client.sign_payload payload_json
    assert verify_signature(signed_payload, payload_json)

    # test hash payload for "same" signature
    payload_object = { key1: 'value1' }
    signed_payload = @client.sign_payload payload_object
    assert verify_signature(signed_payload, payload_json)
  end

  def test_send_request
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}&Action=Test&SignatureMethod=HmacSHA256&SignatureVersion=2&Version=2013-01-01"

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}",
       :headers => HEADERS).to_return(:status => 200)

    res = @operation.send :post, MWS_ENDPOINT, SANDBOX_STR, post_url
    assert_equal(true, res.success)
  end

  def test_send_request_error_500
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}&Action=Test&SignatureMethod=HmacSHA256&SignatureVersion=2&Version=2013-01-01"

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}",
       :headers => HEADERS).to_return(:status => 500)

    error = assert_raises(RuntimeError) {
      @operation.send :post, MWS_ENDPOINT, SANDBOX_STR, post_url
    }
    assert_equal("InternalServerError", error.message )
  end

  def test_send_request_error_503
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}&Action=Test&SignatureMethod=HmacSHA256&SignatureVersion=2&Version=2013-01-01"

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}",
       :headers => HEADERS).to_return(:status => 503)

    error = assert_raises(RuntimeError) {
      @operation.send :post, MWS_ENDPOINT, SANDBOX_STR, post_url
    }
    assert_equal("ServiceUnavailable or RequestThrottled", error.message )
  end

  def test_get_seconds_for_try_count
    value = @operation.send :get_seconds_for_try_count, 1
    assert_equal(1, value)
  end

  def test_response
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}&Action=Test&SignatureMethod=HmacSHA256&SignatureVersion=2&Version=2013-01-01"

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}",
       :headers => HEADERS).to_return(:status => 200, :body => "<root><test>value</test></root>")

    res = @operation.send :post, MWS_ENDPOINT, SANDBOX_STR, post_url

    assert_equal("value", res.to_xml.root.elements[1].text)
    assert_equal("<root><test>value</test></root>", res.body)
    assert_equal("value", res.get_element("root","test"))
    assert_not_equal(res.get_element("root","test"), res.get_element("extra","extra"))
    assert_equal("200", res.code)
  end

  def test_response_error
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}&Action=Test&SignatureMethod=HmacSHA256&SignatureVersion=2&Version=2013-01-01"

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}",
       :headers => HEADERS).to_return(:status => 404)

    res = @operation.send :post, MWS_ENDPOINT, SANDBOX_STR, post_url

    assert_equal(false, res.success)
  end

  def test_signature
    signature = @operation.send :sign, "test signature code"
    assert_equal("VWty3pyWd3Ol4pw3L7nFQ%2FxI6SXXsV5T2aRdoNPVMg0%3D", signature)
  end

  def test_get_service_status
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}&Action=GetServiceStatus&SignatureMethod=HmacSHA256&SignatureVersion=2"\
      "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)

    res = @client.get_service_status
    assert_equal(true, res.success)
  end

  def test_get_order_reference_details
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}"\
      "&AccessToken=address_consent_token"\
      "&Action=GetOrderReferenceDetails"\
      "&AmazonOrderReferenceId=#{AMAZON_ORDER_REFERENCE_ID}"\
      "&SellerId=#{MERCHANT_ID}"\
      "&SignatureMethod=HmacSHA256&SignatureVersion=2"\
      "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}"\
      "&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)

    res = @client.get_order_reference_details(AMAZON_ORDER_REFERENCE_ID, address_consent_token: "address_consent_token")
    assert_equal(true, res.success)
    res = @client.get_order_reference_details(AMAZON_ORDER_REFERENCE_ID, access_token: "address_consent_token")
    assert_equal(true, res.success)
  end

  def test_set_order_reference_details
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}"\
      "&Action=SetOrderReferenceDetails"\
      "&AmazonOrderReferenceId=#{AMAZON_ORDER_REFERENCE_ID}"\
      "&OrderReferenceAttributes.OrderTotal.Amount=#{AMOUNT}"\
      "&OrderReferenceAttributes.OrderTotal.CurrencyCode=USD"\
      "&OrderReferenceAttributes.RequestPaymentAuthorization=false"\
      "&OrderReferenceAttributes.SellerNote=seller_note"\
      "&OrderReferenceAttributes.SellerOrderAttributes.CustomInformation=custom_information"\
      "&OrderReferenceAttributes.SellerOrderAttributes.OrderItemCategories.OrderItemCategory.1=Antiques"\
      "&OrderReferenceAttributes.SellerOrderAttributes.SellerOrderId=seller_order_id"\
      "&OrderReferenceAttributes.SellerOrderAttributes.StoreName=store_name"\
      "&OrderReferenceAttributes.SellerOrderAttributes.SupplementaryData=%7B%22AirlineMetaData%22%20%3A%20%7B%22version%22%3A%201.0%7D%7D"\
      "&SellerId=#{MERCHANT_ID}"\
      "&SignatureMethod=HmacSHA256"\
      "&SignatureVersion=2"\
      "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}"\
      "&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)

    seller_note = 'seller_note'
    seller_order_id = 'seller_order_id'
    store_name = 'store_name'
    custom_information = 'custom_information'
    supplementary_data = '{"AirlineMetaData" : {"version": 1.0}}'
    order_item_categories = ["Antiques"]

    res = @client.set_order_reference_details(
      AMAZON_ORDER_REFERENCE_ID,
      AMOUNT,
      store_name: store_name,
      custom_information: custom_information,
      supplementary_data: supplementary_data,
      order_item_categories: order_item_categories,
      seller_note: seller_note,
      request_payment_authorization: false,
      seller_order_id: seller_order_id
    )
    assert_equal(true, res.success)
  end

  def test_set_order_attributes_without_amount
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}"\
      "&Action=SetOrderAttributes"\
      "&AmazonOrderReferenceId=#{AMAZON_ORDER_REFERENCE_ID}"\
      "&OrderAttributes.PaymentServiceProviderAttributes.PaymentServiceProviderId=#{MERCHANT_ID}"\
      "&OrderAttributes.PaymentServiceProviderAttributes.PaymentServiceProviderOrderId=psp_order_id"\
      "&OrderAttributes.PlatformId=#{MERCHANT_ID}"\
      "&OrderAttributes.RequestPaymentAuthorization=false"\
      "&OrderAttributes.SellerNote=seller_note"\
      "&OrderAttributes.SellerOrderAttributes.CustomInformation=custom_information"\
      "&OrderAttributes.SellerOrderAttributes.OrderItemCategories.OrderItemCategory.1=Antiques"\
      "&OrderAttributes.SellerOrderAttributes.SellerOrderId=seller_order_id"\
      "&OrderAttributes.SellerOrderAttributes.StoreName=store_name"\
      "&OrderAttributes.SellerOrderAttributes.SupplementaryData=%7B%22AirlineMetaData%22%20%3A%20%7B%22version%22%3A%201.0%7D%7D"\
      "&SellerId=#{MERCHANT_ID}"\
      "&SignatureMethod=HmacSHA256"\
      "&SignatureVersion=2"\
      "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}"\
      "&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)

    seller_note = 'seller_note'
    seller_order_id = 'seller_order_id'
    store_name = 'store_name'
    custom_information = 'custom_information'
    supplementary_data = '{"AirlineMetaData" : {"version": 1.0}}'
    order_item_categories = ["Antiques"]
    payment_service_provider_id = MERCHANT_ID
    payment_service_provider_order_id = 'psp_order_id'
    platform_id = MERCHANT_ID

    res = @client.set_order_attributes(
      AMAZON_ORDER_REFERENCE_ID,
      store_name: store_name,
      custom_information: custom_information,
      supplementary_data: supplementary_data,
      order_item_categories: order_item_categories,
      platform_id: platform_id,
      payment_service_provider_id: payment_service_provider_id,
      payment_service_provider_order_id: payment_service_provider_order_id,
      seller_note: seller_note,
      request_payment_authorization: false,
      seller_order_id: seller_order_id
    )
    assert_equal(true, res.success)
  end

  def test_set_order_attributes_using_amount_with_overridden_currency
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}"\
      "&Action=SetOrderAttributes"\
      "&AmazonOrderReferenceId=#{AMAZON_ORDER_REFERENCE_ID}"\
      "&OrderAttributes.OrderTotal.Amount=#{AMOUNT}"\
      "&OrderAttributes.OrderTotal.CurrencyCode=EUR"\
      "&OrderAttributes.PaymentServiceProviderAttributes.PaymentServiceProviderId=#{MERCHANT_ID}"\
      "&OrderAttributes.PaymentServiceProviderAttributes.PaymentServiceProviderOrderId=psp_order_id"\
      "&OrderAttributes.PlatformId=#{MERCHANT_ID}"\
      "&OrderAttributes.RequestPaymentAuthorization=false"\
      "&OrderAttributes.SellerNote=seller_note"\
      "&OrderAttributes.SellerOrderAttributes.CustomInformation=custom_information"\
      "&OrderAttributes.SellerOrderAttributes.OrderItemCategories.OrderItemCategory.1=Antiques"\
      "&OrderAttributes.SellerOrderAttributes.SellerOrderId=seller_order_id"\
      "&OrderAttributes.SellerOrderAttributes.StoreName=store_name"\
      "&OrderAttributes.SellerOrderAttributes.SupplementaryData=%7B%22AirlineMetaData%22%20%3A%20%7B%22version%22%3A%201.0%7D%7D"\
      "&SellerId=#{MERCHANT_ID}"\
      "&SignatureMethod=HmacSHA256"\
      "&SignatureVersion=2"\
      "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}"\
      "&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)

    seller_note = 'seller_note'
    seller_order_id = 'seller_order_id'
    store_name = 'store_name'
    custom_information = 'custom_information'
    supplementary_data = '{"AirlineMetaData" : {"version": 1.0}}'
    order_item_categories = ["Antiques"]
    currency_code = 'EUR'
    payment_service_provider_id = MERCHANT_ID
    payment_service_provider_order_id = 'psp_order_id'
    platform_id = MERCHANT_ID

    res = @client.set_order_attributes(
      AMAZON_ORDER_REFERENCE_ID,
      amount: AMOUNT,
      currency_code: currency_code,
      store_name: store_name,
      custom_information: custom_information,
      supplementary_data: supplementary_data,
      order_item_categories: order_item_categories,
      platform_id: platform_id,
      payment_service_provider_id: payment_service_provider_id,
      payment_service_provider_order_id: payment_service_provider_order_id,
      seller_note: seller_note,
      request_payment_authorization: false,
      seller_order_id: seller_order_id
    )
    assert_equal(true, res.success)
  end

  def test_set_order_attributes_using_amount_with_default_currency
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}"\
      "&Action=SetOrderAttributes"\
      "&AmazonOrderReferenceId=#{AMAZON_ORDER_REFERENCE_ID}"\
      "&OrderAttributes.OrderTotal.Amount=#{AMOUNT}"\
      "&OrderAttributes.OrderTotal.CurrencyCode=USD"\
      "&OrderAttributes.PaymentServiceProviderAttributes.PaymentServiceProviderId=#{MERCHANT_ID}"\
      "&OrderAttributes.PaymentServiceProviderAttributes.PaymentServiceProviderOrderId=psp_order_id"\
      "&OrderAttributes.PlatformId=#{MERCHANT_ID}"\
      "&OrderAttributes.RequestPaymentAuthorization=false"\
      "&OrderAttributes.SellerNote=seller_note"\
      "&OrderAttributes.SellerOrderAttributes.CustomInformation=custom_information"\
      "&OrderAttributes.SellerOrderAttributes.OrderItemCategories.OrderItemCategory.1=Antiques"\
      "&OrderAttributes.SellerOrderAttributes.SellerOrderId=seller_order_id"\
      "&OrderAttributes.SellerOrderAttributes.StoreName=store_name"\
      "&OrderAttributes.SellerOrderAttributes.SupplementaryData=%7B%22AirlineMetaData%22%20%3A%20%7B%22version%22%3A%201.0%7D%7D"\
      "&SellerId=#{MERCHANT_ID}"\
      "&SignatureMethod=HmacSHA256"\
      "&SignatureVersion=2"\
      "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}"\
      "&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)

    seller_note = 'seller_note'
    seller_order_id = 'seller_order_id'
    store_name = 'store_name'
    custom_information = 'custom_information'
    supplementary_data = '{"AirlineMetaData" : {"version": 1.0}}'
    order_item_categories = ["Antiques"]
    payment_service_provider_id = MERCHANT_ID
    payment_service_provider_order_id = 'psp_order_id'
    platform_id = MERCHANT_ID

    res = @client.set_order_attributes(
      AMAZON_ORDER_REFERENCE_ID,
      amount: AMOUNT,
      store_name: store_name,
      custom_information: custom_information,
      supplementary_data: supplementary_data,
      order_item_categories: order_item_categories,
      platform_id: platform_id,
      payment_service_provider_id: payment_service_provider_id,
      payment_service_provider_order_id: payment_service_provider_order_id,
      seller_note: seller_note,
      request_payment_authorization: false,
      seller_order_id: seller_order_id
    )
    assert_equal(true, res.success)
  end

  def test_confirm_order_reference
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}&Action=ConfirmOrderReference&AmazonOrderReferenceId=#{AMAZON_ORDER_REFERENCE_ID}"\
      "&SellerId=#{MERCHANT_ID}"\
      "&SignatureMethod=HmacSHA256"\
      "&SignatureVersion=2"\
      "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)

    res = @client.confirm_order_reference(AMAZON_ORDER_REFERENCE_ID)
    assert_equal(true, res.success)
  end

  def test_confirm_order_reference_using_sca_with_amount_default_currency
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}&Action=ConfirmOrderReference&AmazonOrderReferenceId=#{AMAZON_ORDER_REFERENCE_ID}"\
      "&AuthorizationAmount.Amount=#{AMOUNT}"\
      "&AuthorizationAmount.CurrencyCode=USD"\
      "&FailureUrl=#{FAILURE_URL_ENCODED}"\
      "&SellerId=#{MERCHANT_ID}"\
      "&SignatureMethod=HmacSHA256"\
      "&SignatureVersion=2"\
      "&SuccessUrl=#{SUCCESS_URL_ENCODED}"\
      "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)

    res = @client.confirm_order_reference(
      AMAZON_ORDER_REFERENCE_ID,
      authorization_amount: AMOUNT,
      success_url: SUCCESS_URL,
      failure_url: FAILURE_URL
    )
    assert_equal(true, res.success)
  end

  def test_confirm_order_reference_using_sca_with_amount_overriden_currency
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}&Action=ConfirmOrderReference&AmazonOrderReferenceId=#{AMAZON_ORDER_REFERENCE_ID}"\
      "&AuthorizationAmount.Amount=#{AMOUNT}"\
      "&AuthorizationAmount.CurrencyCode=EUR"\
      "&FailureUrl=#{FAILURE_URL_ENCODED}"\
      "&SellerId=#{MERCHANT_ID}"\
      "&SignatureMethod=HmacSHA256"\
      "&SignatureVersion=2"\
      "&SuccessUrl=#{SUCCESS_URL_ENCODED}"\
      "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)

    res = @client.confirm_order_reference(
      AMAZON_ORDER_REFERENCE_ID,
      authorization_amount: AMOUNT,
      currency_code: 'EUR',
      success_url: SUCCESS_URL,
      failure_url: FAILURE_URL
    )
    assert_equal(true, res.success)
  end

  def test_confirm_order_reference_using_sca_without_amount
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}&Action=ConfirmOrderReference&AmazonOrderReferenceId=#{AMAZON_ORDER_REFERENCE_ID}"\
      "&FailureUrl=#{FAILURE_URL_ENCODED}"\
      "&SellerId=#{MERCHANT_ID}"\
      "&SignatureMethod=HmacSHA256"\
      "&SignatureVersion=2"\
      "&SuccessUrl=#{SUCCESS_URL_ENCODED}"\
      "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)

    res = @client.confirm_order_reference(
      AMAZON_ORDER_REFERENCE_ID,
      success_url: SUCCESS_URL,
      failure_url: FAILURE_URL
    )
    assert_equal(true, res.success)
  end

  def test_confirm_order_reference_with_expect_immediate_authorization_as_true
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}&Action=ConfirmOrderReference&AmazonOrderReferenceId=#{AMAZON_ORDER_REFERENCE_ID}"\
      "&ExpectImmediateAuthorization=true"\
      "&SellerId=#{MERCHANT_ID}"\
      "&SignatureMethod=HmacSHA256"\
      "&SignatureVersion=2"\
      "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)

    res = @client.confirm_order_reference(
      AMAZON_ORDER_REFERENCE_ID,
      expect_immediate_authorization: true
    )
    assert_equal(true, res.success)
  end

  def test_confirm_order_reference_with_expect_immediate_authorization_as_false
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}&Action=ConfirmOrderReference&AmazonOrderReferenceId=#{AMAZON_ORDER_REFERENCE_ID}"\
      "&ExpectImmediateAuthorization=false"\
      "&SellerId=#{MERCHANT_ID}"\
      "&SignatureMethod=HmacSHA256"\
      "&SignatureVersion=2"\
      "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)

    res = @client.confirm_order_reference(
      AMAZON_ORDER_REFERENCE_ID,
      expect_immediate_authorization: false
    )
    assert_equal(true, res.success)
  end

  def test_list_order_reference
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}"\
      "&Action=ListOrderReference"\
      "&CreatedTimeRange.EndTime=#{END_TIME_ENCODED}"\
      "&CreatedTimeRange.StartTime=#{START_TIME_ENCODED}"\
      "&OrderReferenceStatusListFilter.OrderReferenceStatus.1=canceled"\
      "&OrderReferenceStatusListFilter.OrderReferenceStatus.2=open"\
      "&OrderReferenceStatusListFilter.OrderReferenceStatus.3=closed"\
      "&PageSize=1"\
      "&PaymentDomain=NA_USD"\
      "&QueryId=#{QUERY_ID}"\
      "&QueryIdType=#{QUERY_ID_TYPE}"\
      "&SellerId=#{MERCHANT_ID}"\
      "&SignatureMethod=HmacSHA256"\
      "&SignatureVersion=2"\
      "&SortOrder=Descending"\
      "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)

    res = @client.list_order_reference(
      QUERY_ID,
      QUERY_ID_TYPE,
      created_time_range_start: START_TIME,
      created_time_range_end: END_TIME,
      sort_order: 'Descending',
      page_size: 1,
      order_reference_status_list_filter: ['canceled', 'open', 'closed'],
    )
    assert_equal(true, res.success)
  end

  def test_list_order_reference_by_next_token
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}"\
      "&Action=ListOrderReferenceByNextToken"\
      "&NextPageToken=#{NEXT_PAGE_TOKEN}"\
      "&SellerId=#{MERCHANT_ID}"\
      "&SignatureMethod=HmacSHA256"\
      "&SignatureVersion=2"\
      "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)

    res = @client.list_order_reference_by_next_token(
      NEXT_PAGE_TOKEN
    )
    assert_equal(true, res.success)
  end

  def test_get_merchant_account_status
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}"\
      "&Action=GetMerchantAccountStatus"\
      "&SellerId=#{MERCHANT_ID}"\
      "&SignatureMethod=HmacSHA256"\
      "&SignatureVersion=2"\
      "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}"\
      "&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)

    res = @client.get_merchant_account_status
    assert_equal(true, res.success)
  end

  def test_authorize
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}"\
      "&Action=Authorize&AmazonOrderReferenceId=#{AMAZON_ORDER_REFERENCE_ID}"\
      "&AuthorizationAmount.Amount=#{AMOUNT}"\
      "&AuthorizationAmount.CurrencyCode=USD"\
      "&AuthorizationReferenceId=#{AUTHORIZATION_REFERENCE_ID}"\
      "&CaptureNow=capture_now&SellerId=#{MERCHANT_ID}"\
      "&SignatureMethod=HmacSHA256"\
      "&SignatureVersion=2"\
      "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}"\
      "&TransactionTimeout=transaction_timeout&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)

    res = @client.authorize(
      AMAZON_ORDER_REFERENCE_ID, 
      AUTHORIZATION_REFERENCE_ID, 
      AMOUNT, 
      capture_now: "capture_now", 
      transaction_timeout: "transaction_timeout"
    )
    assert_equal(true, res.success)
  end

  def test_get_authorization_details
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}"\
    "&Action=GetAuthorizationDetails"\
    "&AmazonAuthorizationId=amazon_authorization_id"\
    "&SellerId=#{MERCHANT_ID}"\
    "&SignatureMethod=HmacSHA256"\
    "&SignatureVersion=2"\
    "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)

    res = @client.get_authorization_details("amazon_authorization_id")
    assert_equal(true, res.success)
  end

  def test_close_authorization
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}"\
      "&Action=CloseAuthorization&AmazonAuthorizationId=amazon_authorization_id"\
      "&SellerId=#{MERCHANT_ID}"\
      "&SignatureMethod=HmacSHA256"\
      "&SignatureVersion=2"\
      "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)

    res = @client.close_authorization("amazon_authorization_id")
    assert_equal(true, res.success)
  end

  def test_capture
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}"\
      "&Action=Capture&AmazonAuthorizationId=amazon_authorization_id"\
      "&CaptureAmount.Amount=#{AMOUNT}"\
      "&CaptureAmount.CurrencyCode=USD&CaptureReferenceId=#{CAPTURE_REFERENCE_ID}"\
      "&SellerId=#{MERCHANT_ID}"\
      "&SignatureMethod=HmacSHA256"\
      "&SignatureVersion=2"\
      "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)

    res = @client.capture("amazon_authorization_id", CAPTURE_REFERENCE_ID, AMOUNT)
    assert_equal(true, res.success)
  end

  def test_capture_provider
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}"\
      "&Action=Capture&AmazonAuthorizationId=amazon_authorization_id"\
      "&CaptureAmount.Amount=#{AMOUNT}"\
      "&CaptureAmount.CurrencyCode=USD"\
      "&CaptureReferenceId=#{CAPTURE_REFERENCE_ID}"\
      "&ProviderCreditList.member.1.CreditAmount.Amount=10.00"\
      "&ProviderCreditList.member.1.CreditAmount.CurrencyCode=USD"\
      "&ProviderCreditList.member.1.ProviderId=1"\
      "&SellerId=#{MERCHANT_ID}"\
      "&SignatureMethod=HmacSHA256"\
      "&SignatureVersion=2"\
      "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)

    res = @client.capture("amazon_authorization_id", CAPTURE_REFERENCE_ID, AMOUNT, provider_credit_details: [{:provider_id => '1', :amount => '10.00', :currency_code => 'USD'}])
    assert_equal(true, res.success)
  end

  def test_get_capture_details
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}"\
      "&Action=GetCaptureDetails&AmazonCaptureId=amazon_capture_id"\
      "&SellerId=#{MERCHANT_ID}"\
      "&SignatureMethod=HmacSHA256&SignatureVersion=2"\
      "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)

    res = @client.get_capture_details("amazon_capture_id")
    assert_equal(true, res.success)
  end

  def test_cancel_order_reference
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}"\
      "&Action=CancelOrderReference&AmazonOrderReferenceId=#{AMAZON_ORDER_REFERENCE_ID}"\
      "&SellerId=#{MERCHANT_ID}"\
      "&SignatureMethod=HmacSHA256"\
      "&SignatureVersion=2"\
      "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)

    res = @client.cancel_order_reference(AMAZON_ORDER_REFERENCE_ID)
    assert_equal(true, res.success)
  end

  def test_close_order_reference
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}"\
      "&Action=CloseOrderReference"\
      "&AmazonOrderReferenceId=#{AMAZON_ORDER_REFERENCE_ID}"\
      "&SellerId=#{MERCHANT_ID}"\
      "&SignatureMethod=HmacSHA256"\
      "&SignatureVersion=2"\
      "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)

    res = @client.close_order_reference(AMAZON_ORDER_REFERENCE_ID)
    assert_equal(true, res.success)
  end

  def test_refund
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}"\
      "&Action=Refund&AmazonCaptureId=amazon_capture_id"\
      "&RefundAmount.Amount=#{AMOUNT}"\
      "&RefundAmount.CurrencyCode=USD"\
      "&RefundReferenceId=#{REFUND_REFERENCE_ID}"\
      "&SellerId=#{MERCHANT_ID}"\
      "&SignatureMethod=HmacSHA256"\
      "&SignatureVersion=2"\
      "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)

    res = @client.refund("amazon_capture_id", REFUND_REFERENCE_ID, AMOUNT)
    assert_equal(true, res.success)
  end

  def test_refund_provider
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}"\
      "&Action=Refund"\
      "&AmazonCaptureId=amazon_capture_id"\
      "&ProviderCreditReversalList.member.1.CreditReversalAmount.Amount=10.00"\
      "&ProviderCreditReversalList.member.1.CreditReversalAmount.CurrencyCode=USD"\
      "&ProviderCreditReversalList.member.1.ProviderId=1"\
      "&RefundAmount.Amount=#{AMOUNT}"\
      "&RefundAmount.CurrencyCode=USD"\
      "&RefundReferenceId=#{REFUND_REFERENCE_ID}"\
      "&SellerId=#{MERCHANT_ID}"\
      "&SignatureMethod=HmacSHA256"\
      "&SignatureVersion=2"\
      "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)

    res = @client.refund("amazon_capture_id", REFUND_REFERENCE_ID, AMOUNT, provider_credit_reversal_details: [{:provider_id => '1', :amount => '10.00', :currency_code => 'USD'}])
    assert_equal(true, res.success)
  end

  def test_get_refund_details
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}"\
      "&Action=GetRefundDetails"\
      "&AmazonRefundId=amazon_refund_id"\
      "&SellerId=#{MERCHANT_ID}"\
      "&SignatureMethod=HmacSHA256"\
      "&SignatureVersion=2"\
      "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)

    res = @client.get_refund_details("amazon_refund_id")
    assert_equal(true, res.success)
  end

  def test_get_billing_agreement_details
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}"\
      "&Action=GetBillingAgreementDetails"\
      "&AddressConsentToken=address_consent_token"\
      "&AmazonBillingAgreementId=#{AMAZON_BILLING_AGREEMENT_ID}"\
      "&SellerId=#{MERCHANT_ID}"\
      "&SignatureMethod=HmacSHA256"\
      "&SignatureVersion=2"\
      "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)

    res = @client.get_billing_agreement_details(AMAZON_BILLING_AGREEMENT_ID, address_consent_token: "address_consent_token")
    assert_equal(true, res.success)

    post_url = "AWSAccessKeyId=#{ACCESS_KEY}"\
      "&AccessToken=address_consent_token"\
      "&Action=GetBillingAgreementDetails"\
      "&AmazonBillingAgreementId=#{AMAZON_BILLING_AGREEMENT_ID}"\
      "&SellerId=#{MERCHANT_ID}"\
      "&SignatureMethod=HmacSHA256"\
      "&SignatureVersion=2"\
      "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)
    
    res = @client.get_billing_agreement_details(AMAZON_BILLING_AGREEMENT_ID, access_token: "address_consent_token")
    assert_equal(true, res.success)
  end

  def test_set_billing_agreement_details
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}"\
      "&Action=SetBillingAgreementDetails&AmazonBillingAgreementId=#{AMAZON_BILLING_AGREEMENT_ID}"\
      "&BillingAgreementAttributes.SellerBillingAgreementAttributes.CustomInformation=custom_information"\
      "&BillingAgreementAttributes.SellerBillingAgreementAttributes.SellerBillingAgreementId=seller_billing_agreement_id"\
      "&BillingAgreementAttributes.SellerBillingAgreementAttributes.StoreName=store_name"\
      "&BillingAgreementAttributes.SellerNote=seller_note&SellerId=#{MERCHANT_ID}"\
      "&SignatureMethod=HmacSHA256"\
      "&SignatureVersion=2"\
      "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)

    seller_note = 'seller_note'
    store_name = 'store_name'
    custom_information = 'custom_information'
    seller_billing_agreement_id = 'seller_billing_agreement_id'

    res = @client.set_billing_agreement_details(
      AMAZON_BILLING_AGREEMENT_ID, 
      store_name: store_name, 
      seller_billing_agreement_id: seller_billing_agreement_id, 
      custom_information: custom_information, 
      seller_note: seller_note
    )
    assert_equal(true, res.success)
  end

  def test_set_billing_agreement_details_sca_with_amount_overriden_currency
    seller_note = 'seller_note'
    store_name = 'store_name'
    custom_information = 'custom_information'
    seller_billing_agreement_id = 'seller_billing_agreement_id'
    billing_agreement_type = 'MerchantInitiatedTransaction'
    subscription_amount = '1.23'
    subscription_currency_code = 'GBP'

    post_url = "AWSAccessKeyId=#{ACCESS_KEY}"\
      "&Action=SetBillingAgreementDetails&AmazonBillingAgreementId=#{AMAZON_BILLING_AGREEMENT_ID}"\
      "&BillingAgreementAttributes.BillingAgreementType=#{billing_agreement_type}"\
      "&BillingAgreementAttributes.SellerBillingAgreementAttributes.CustomInformation=#{custom_information}"\
      "&BillingAgreementAttributes.SellerBillingAgreementAttributes.SellerBillingAgreementId=#{seller_billing_agreement_id}"\
      "&BillingAgreementAttributes.SellerBillingAgreementAttributes.StoreName=#{store_name}"\
      "&BillingAgreementAttributes.SellerNote=seller_note"\
      "&BillingAgreementAttributes.SubscriptionAmount.Amount=#{subscription_amount}"\
      "&BillingAgreementAttributes.SubscriptionAmount.CurrencyCode=#{subscription_currency_code}"\
      "&SellerId=#{MERCHANT_ID}"\
      "&SignatureMethod=HmacSHA256"\
      "&SignatureVersion=2"\
      "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)

    res = @client.set_billing_agreement_details(
      AMAZON_BILLING_AGREEMENT_ID,
      store_name: store_name,
      seller_billing_agreement_id: seller_billing_agreement_id,
      custom_information: custom_information,
      seller_note: seller_note,
      billing_agreement_type: billing_agreement_type,
      subscription_amount: subscription_amount,
      subscription_currency_code: subscription_currency_code
    )
    assert_equal(true, res.success)
  end

  def test_set_billing_agreement_details_sca_with_amount_default_currency
    seller_note = 'seller_note'
    store_name = 'store_name'
    custom_information = 'custom_information'
    seller_billing_agreement_id = 'seller_billing_agreement_id'
    billing_agreement_type = 'MerchantInitiatedTransaction'
    subscription_amount = '1.23'

    post_url = "AWSAccessKeyId=#{ACCESS_KEY}"\
      "&Action=SetBillingAgreementDetails&AmazonBillingAgreementId=#{AMAZON_BILLING_AGREEMENT_ID}"\
      "&BillingAgreementAttributes.BillingAgreementType=#{billing_agreement_type}"\
      "&BillingAgreementAttributes.SellerBillingAgreementAttributes.CustomInformation=#{custom_information}"\
      "&BillingAgreementAttributes.SellerBillingAgreementAttributes.SellerBillingAgreementId=#{seller_billing_agreement_id}"\
      "&BillingAgreementAttributes.SellerBillingAgreementAttributes.StoreName=#{store_name}"\
      "&BillingAgreementAttributes.SellerNote=seller_note"\
      "&BillingAgreementAttributes.SubscriptionAmount.Amount=#{subscription_amount}"\
      "&BillingAgreementAttributes.SubscriptionAmount.CurrencyCode=USD"\
      "&SellerId=#{MERCHANT_ID}"\
      "&SignatureMethod=HmacSHA256"\
      "&SignatureVersion=2"\
      "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)

    res = @client.set_billing_agreement_details(
      AMAZON_BILLING_AGREEMENT_ID,
      store_name: store_name,
      seller_billing_agreement_id: seller_billing_agreement_id,
      custom_information: custom_information,
      seller_note: seller_note,
      billing_agreement_type: billing_agreement_type,
      subscription_amount: subscription_amount
    )
    assert_equal(true, res.success)
  end

  def test_set_billing_agreement_details_sca_without_amount
    seller_note = 'seller_note'
    store_name = 'store_name'
    custom_information = 'custom_information'
    seller_billing_agreement_id = 'seller_billing_agreement_id'
    billing_agreement_type = 'CustomerInitiatedTransaction'

    post_url = "AWSAccessKeyId=#{ACCESS_KEY}"\
      "&Action=SetBillingAgreementDetails&AmazonBillingAgreementId=#{AMAZON_BILLING_AGREEMENT_ID}"\
      "&BillingAgreementAttributes.BillingAgreementType=#{billing_agreement_type}"\
      "&BillingAgreementAttributes.SellerBillingAgreementAttributes.CustomInformation=#{custom_information}"\
      "&BillingAgreementAttributes.SellerBillingAgreementAttributes.SellerBillingAgreementId=#{seller_billing_agreement_id}"\
      "&BillingAgreementAttributes.SellerBillingAgreementAttributes.StoreName=#{store_name}"\
      "&BillingAgreementAttributes.SellerNote=seller_note"\
      "&SellerId=#{MERCHANT_ID}"\
      "&SignatureMethod=HmacSHA256"\
      "&SignatureVersion=2"\
      "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)

    res = @client.set_billing_agreement_details(
      AMAZON_BILLING_AGREEMENT_ID,
      store_name: store_name,
      seller_billing_agreement_id: seller_billing_agreement_id,
      custom_information: custom_information,
      seller_note: seller_note,
      billing_agreement_type: billing_agreement_type
    )
    assert_equal(true, res.success)
  end

  def test_confirm_billing_agreement
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}"\
      "&Action=ConfirmBillingAgreement&AmazonBillingAgreementId=#{AMAZON_BILLING_AGREEMENT_ID}"\
      "&SellerId=#{MERCHANT_ID}"\
      "&SignatureMethod=HmacSHA256"\
      "&SignatureVersion=2"\
      "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)

    res = @client.confirm_billing_agreement(AMAZON_BILLING_AGREEMENT_ID)
    assert_equal(true, res.success)
  end

  def test_confirm_billing_agreement_sca
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}"\
      "&Action=ConfirmBillingAgreement&AmazonBillingAgreementId=#{AMAZON_BILLING_AGREEMENT_ID}"\
      "&FailureUrl=#{FAILURE_URL_ENCODED}"\
      "&SellerId=#{MERCHANT_ID}"\
      "&SignatureMethod=HmacSHA256"\
      "&SignatureVersion=2"\
      "&SuccessUrl=#{SUCCESS_URL_ENCODED}"\
      "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)

    res = @client.confirm_billing_agreement(
      AMAZON_BILLING_AGREEMENT_ID,
      success_url: SUCCESS_URL,
      failure_url: FAILURE_URL
    )
    assert_equal(true, res.success)
  end

  def test_validate_billing_agreement
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}"\
      "&Action=ValidateBillingAgreement&AmazonBillingAgreementId=#{AMAZON_BILLING_AGREEMENT_ID}"\
      "&SellerId=#{MERCHANT_ID}"\
      "&SignatureMethod=HmacSHA256"\
      "&SignatureVersion=2"\
      "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)

    res = @client.validate_billing_agreement(AMAZON_BILLING_AGREEMENT_ID)
    assert_equal(true, res.success)
  end

  def test_authorize_on_billing_agreement
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}"\
      "&Action=AuthorizeOnBillingAgreement"\
      "&AmazonBillingAgreementId=#{AMAZON_BILLING_AGREEMENT_ID}"\
      "&AuthorizationAmount.Amount=#{AMOUNT}"\
      "&AuthorizationAmount.CurrencyCode=USD"\
      "&AuthorizationReferenceId=#{AUTHORIZATION_REFERENCE_ID}"\
      "&CaptureNow=capture_now"\
      "&SellerId=#{MERCHANT_ID}"\
      "&SellerOrderAttributes.SupplementaryData=%7B%22AirlineMetaData%22%20%3A%20%7B%22version%22%3A%201.0%7D%7D"\
      "&SignatureMethod=HmacSHA256"\
      "&SignatureVersion=2"\
      "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}"\
      "&TransactionTimeout=transaction_timeout&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)

    res = @client.authorize_on_billing_agreement(
      AMAZON_BILLING_AGREEMENT_ID,
      AUTHORIZATION_REFERENCE_ID,
      AMOUNT,
      capture_now: "capture_now",
      transaction_timeout: "transaction_timeout",
      supplementary_data: '{"AirlineMetaData" : {"version": 1.0}}'
    )
    assert_equal(true, res.success)
  end

  def test_create_order_reference_for_id
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}"\
      "&Action=CreateOrderReferenceForId"\
      "&ConfirmNow=confirm_now"\
      "&Id=#{AMAZON_BILLING_AGREEMENT_ID}"\
      "&IdType=id_type"\
      "&OrderReferenceAttributes.OrderTotal.Amount=#{AMOUNT}"\
      "&OrderReferenceAttributes.OrderTotal.CurrencyCode=USD"\
      "&OrderReferenceAttributes.SellerNote=seller_note"\
      "&OrderReferenceAttributes.SellerOrderAttributes.SellerOrderId=seller_order_id"\
      "&OrderReferenceAttributes.SellerOrderAttributes.SupplementaryData=%7B%22AirlineMetaData%22%20%3A%20%7B%22version%22%3A%201.0%7D%7D"\
      "&SellerId=#{MERCHANT_ID}"\
      "&SignatureMethod=HmacSHA256"\
      "&SignatureVersion=2"\
      "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)

    res = @client.create_order_reference_for_id(
      AMAZON_BILLING_AGREEMENT_ID, 
      "id_type", 
      confirm_now: "confirm_now", 
      amount: AMOUNT, 
      seller_note: "seller_note", 
      seller_order_id: "seller_order_id",
      supplementary_data: '{"AirlineMetaData" : {"version": 1.0}}'
    )
    assert_equal(true, res.success)
  end

  def test_close_billing_agreement
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}"\
      "&Action=CloseBillingAgreement"\
      "&AmazonBillingAgreementId=#{AMAZON_BILLING_AGREEMENT_ID}"\
      "&SellerId=#{MERCHANT_ID}"\
      "&SignatureMethod=HmacSHA256"\
      "&SignatureVersion=2"\
      "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)

    res = @client.close_billing_agreement(AMAZON_BILLING_AGREEMENT_ID)
    assert_equal(true, res.success)
  end

  def test_get_provider_credit_details
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}"\
      "&Action=GetProviderCreditDetails"\
      "&AmazonProviderCreditId=amazon_provider_credit_id"\
      "&SellerId=#{MERCHANT_ID}"\
      "&SignatureMethod=HmacSHA256"\
      "&SignatureVersion=2"\
      "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)

    res = @client.get_provider_credit_details("amazon_provider_credit_id")
    assert_equal(true, res.success)
  end

  def test_get_provider_credit_reversal_details
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}"\
      "&Action=GetProviderCreditReversalDetails"\
      "&AmazonProviderCreditReversalId=amazon_provider_credit_reversal_id"\
      "&SellerId=#{MERCHANT_ID}"\
      "&SignatureMethod=HmacSHA256"\
      "&SignatureVersion=2"\
      "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)

    res = @client.get_provider_credit_reversal_details("amazon_provider_credit_reversal_id")
    assert_equal(true, res.success)
  end

  def test_reverse_provider_credit
    post_url = "AWSAccessKeyId=#{ACCESS_KEY}"\
      "&Action=ReverseProviderCredit&AmazonProviderCreditId=amazon_provider_credit_id"\
      "&CreditReversalAmount.Amount=#{AMOUNT}"\
      "&CreditReversalAmount.CurrencyCode=USD"\
      "&CreditReversalReferenceId=credit_reversal_reference_id"\
      "&SellerId=#{MERCHANT_ID}"\
      "&SignatureMethod=HmacSHA256"\
      "&SignatureVersion=2"\
      "&Timestamp=#{@operation.send :custom_escape, Time.now.utc.iso8601}&Version=2013-01-01"
    post_body = ["POST", "mws.amazonservices.com", "/OffAmazonPayments_Sandbox/2013-01-01", post_url].join("\n")

    stub_request(:post, "https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01").with(:body => "#{post_url}"\
      "&Signature=#{@operation.send :sign, post_body}",
       :headers => HEADERS).to_return(:status => 200)

    res = @client.reverse_provider_credit("amazon_provider_credit_id", "credit_reversal_reference_id", AMOUNT)
    assert_equal(true, res.success)
  end

  def test_set_provider_credit_details
    provider_array = [{:provider_id => '1', :amount => '10.00', :currency_code => 'USD'},
                      {:provider_id => '2', :amount => '15.00', :currency_code => 'USD' },
                      {:provider_id => '3', :amount => '20.00', :currency_code => 'USD'}]
    provider_details = @client.send :set_provider_credit_details, provider_array
    hash = {
      "ProviderCreditList.member.1.ProviderId" => '1',
      "ProviderCreditList.member.1.CreditAmount.Amount" => '10.00',
      "ProviderCreditList.member.1.CreditAmount.CurrencyCode" => 'USD',
      "ProviderCreditList.member.2.ProviderId" => '2',
      "ProviderCreditList.member.2.CreditAmount.Amount" => '15.00',
      "ProviderCreditList.member.2.CreditAmount.CurrencyCode" => 'USD',
      "ProviderCreditList.member.3.ProviderId" => '3',
      "ProviderCreditList.member.3.CreditAmount.Amount" => '20.00',
      "ProviderCreditList.member.3.CreditAmount.CurrencyCode" => 'USD'
    }

    assert_equal(hash, provider_details)
  end

  def test_set_provider_credit_reversal_details
    provider_array = [{:provider_id => '1', :amount => '10.00', :currency_code => 'USD'},
                      {:provider_id => '2', :amount => '15.00', :currency_code => 'USD' },
                      {:provider_id => '3', :amount => '20.00', :currency_code => 'USD'}]
    provider_reversal_details = @client.send :set_provider_credit_reversal_details, provider_array
    hash = {
      "ProviderCreditReversalList.member.1.ProviderId" => '1',
      "ProviderCreditReversalList.member.1.CreditReversalAmount.Amount" => '10.00',
      "ProviderCreditReversalList.member.1.CreditReversalAmount.CurrencyCode" => 'USD',
      "ProviderCreditReversalList.member.2.ProviderId" => '2',
      "ProviderCreditReversalList.member.2.CreditReversalAmount.Amount" => '15.00',
      "ProviderCreditReversalList.member.2.CreditReversalAmount.CurrencyCode" => 'USD',
      "ProviderCreditReversalList.member.3.ProviderId" => '3',
      "ProviderCreditReversalList.member.3.CreditReversalAmount.Amount" => '20.00',
      "ProviderCreditReversalList.member.3.CreditReversalAmount.CurrencyCode" => 'USD'
    }

    assert_equal(hash, provider_reversal_details)
  end

  def test_ipn_helpers
    assert_equal('Type', @ipn.type)
    assert_equal('MessageId', @ipn.message_id)
    assert_equal('TopicArn', @ipn.topic_arn)
    assert_equal("{\"NotificationType\":\"NotificationType\",\"SellerId\":\"SellerId\",\"ReleaseEnvironment\":\"ReleaseEnvironment\",\"Version\":\"Version\",\"NotificationData\":\"NotificationData\",\"Timestamp\":\"Timestamp\"}", @ipn.message)
    assert_equal('Timestamp', @ipn.timestamp)
    assert_equal('Signature', @ipn.signature)
    assert_equal('SignatureVersion', @ipn.signature_version)
    assert_equal('https://test.com/test.pem', @ipn.signing_cert_url)
    assert_equal('UnsubscribeURL', @ipn.unsubscribe_url)
    assert_equal('NotificationType', @ipn.notification_type)
    assert_equal('SellerId', @ipn.seller_id)
    assert_equal('ReleaseEnvironment', @ipn.environment)
    assert_equal('Version', @ipn.version)
    assert_equal('NotificationData', @ipn.notification_data)
    assert_equal('Timestamp', @ipn.message_timestamp)
  end

  def test_validate_header
    @ipn.send :validate_header
    assert_equal('Notification', @ipn.headers['x-amz-sns-message-type'])
  end

  def test_validate_subject_error
    error = assert_raises(AmazonPay::IpnWasNotAuthenticError) {
      @ipn.send :validate_subject, [['CN','CN'],['CN','CN'],['CN','CN'],['CN','CN'],['CN','CN']]
    }
    assert_equal("Error - Unable to verify certificate subject issued by Amazon", error.message )
  end

  def test_https_get
    stub_request(:get, "https://test.com/test.pem").with(:headers => {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'User-Agent'=>'Ruby'}).to_return(:status => 200)

    res = @ipn.send :https_get, 'https://test.com/test.pem'

    assert_equal('200', res.code)
  end

  def test_sanitize_response_data
    begin
      unsanitized_file = File.read("./test/unsanitized_log.txt")
      sanitized_file = File.read("./test/sanitized_log.txt")
    rescue 
      unsanitized_file = File.read("./lib/test/unsanitized_log.txt")
      sanitized_file = File.read("./lib/test/sanitized_log.txt")
    end

    data = AmazonPay::Sanitize.new(unsanitized_file)
    assert_equal(sanitized_file, data.sanitize_response_data)
  end

  def test_download_cert_error
    error = assert_raises(AmazonPay::IpnWasNotAuthenticError) {
      @ipn.send :download_cert, 'https://test.com/test.pem'
    }

    assert_equal("Error - certificate is not hosted at AWS URL (https): https://test.com/test.pem", error.message)
  end

  def test_canonical_string
    res = @ipn.send :canonical_string
    assert_equal("Message\n{\"NotificationType\":\"NotificationType\",\"SellerId\":\"SellerId\",\"ReleaseEnvironment\":\"ReleaseEnvironment\",\"Version\":\"Version\",\"NotificationData\":\"NotificationData\",\"Timestamp\":\"Timestamp\"}\nMessageId\nMessageId\nTimestamp\nTimestamp\nTopicArn\nTopicArn\nType\nType\n", res)
  end

  private

  def verify_signature(signed_payload, payload)
    @client.private_key.public_key.verify_pss(
      "sha256",
      Base64.strict_decode64(signed_payload),
      "AMZN-PAY-RSASSA-PSS\n#{payload}",
      salt_length: 20,
      mgf1_hash: "sha256"
    )
  end

end
