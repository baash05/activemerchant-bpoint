module ActiveMerchant
  module Billing
    class BpointGateway < Gateway
      LIVE_URL = 'https://www.bpoint.com.au/evolve/service.asmx'

      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.supported_countries = ['AU']
      self.homepage_url        = 'http://www.bpoint.com.au'
      self.display_name        = 'BPOINT'
      self.default_currency    = 'AUD'
      self.money_format        = :cents

      def initialize(options = {})
        requires!(options, :login, :password, :merchant_number)
        @options = options
        super
      end

      def authorize(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        add_customer_data(post, options)

        commit('authonly', money, post)
      end

      def purchase(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        add_customer_data(post, options)

        commit('ProcessPayment', money, post)
      end

      def capture(money, authorization, options = {})
        commit('capture', money, post)
      end

      private

      def add_customer_data(post, options)
      end

      def add_address(post, creditcard, options)
      end

      def add_invoice(post, options)
        post[:MerchantReference] = options[:order_id]
      end

      def add_creditcard(post, creditcard)
        post[:CardNumber] = creditcard.number
        post[:ExpiryDate] = "%02d%02s" % [creditcard.month, creditcard.year.to_s[-2..-1]]
        post[:CVC]        = creditcard.verification_value
      end

      def parse(body)
        REXML::Document.new(body)
      end

      def commit(action, money, parameters)
        parameters[:Amount] = amount(money)

        response = parse(ssl_post(LIVE_URL, post_data(action, parameters), 'SOAPAction' => "urn:Eve/#{action}", 'Content-Type' => 'text/xml;charset=UTF-8') )
        success  = response.elements['//ResponseCode'].try(:text) == '0'
        message  = response.elements['//ResponseMessage'].try(:text) || response.elements['//AuthorisationResult'].try(:text)
        options  = { :authorization => response.elements['//AuthoriseId'].try(:text) }

        Response.new(success, message, {}, options)
      end

      def post_data(action, parameters = {})
        xml      = REXML::Document.new
        envelope = xml.add_element('env:Envelope',  { 'xmlns:xsd' =>
                                  'http://www.w3.org/2001/XMLSchema',
                                    'xmlns:xsi' =>
                                  'http://www.w3.org/2001/XMLSchema-instance',
                                    'xmlns:wsdl' => 'urn:Eve', 'xmlns:env' =>
                                  'http://schemas.xmlsoap.org/soap/envelope/',
                                    'xmlns:ns0' => 'urn:Eve'})

        body    = envelope.add_element('env:Body')
        request = body.add_element("ns0:#{action}")
        tnx_request = request.add_element('ns0:txnReq')


        request.add_element('ns0:username').text       = @options[:login]
        request.add_element('ns0:password').text       = @options[:password]
        request.add_element('ns0:merchantNumber').text = @options[:merchant_number]

        parameters.each { |key, value| tnx_request.add_element("ns0:#{key}").text = value }

        xml << REXML::XMLDecl.new('1.0', 'UTF-8')
        xml.to_s
      end
    end
  end
end
