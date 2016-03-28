require 'faraday_middleware'
require 'appnexusapi/faraday/raise_http_error'

class AppnexusApi::Connection
  def initialize(config)
    @config = config
    @config['uri'] ||= 'https://api.appnexus.com/'
    @connection = Faraday.new(@config['uri']) do |conn|
      if ENV['APPNEXUS_API_DEBUG'].to_s =~ /^(true|1)$/i
        conn.response :logger, Logger.new(STDERR), bodies: true
      end

      conn.request :json
      conn.response :json, :content_type => /\bjson$/
      conn.use AppnexusApi::Faraday::Response::RaiseHttpError
      conn.adapter Faraday.default_adapter
    end
  end

  def is_authorized?
    !@token.nil?
  end

  def login
    response = @connection.run_request(:post, 'auth', { 'auth' => { 'username' => @config['username'], 'password' => @config['password'] } }, {})
    if response.body['response']['error_code']
      fail "#{response.body['response']['error_code']}/#{response.body['response']['error_description']}"
    end
    @token = response.body['response']['token']
  end

  def logout
    @token = nil
  end

  def get(route, params = {}, headers = {})
    run_request(:get, request_url(route, params), nil, headers)
  end

  def post(route, body = nil, params = {}, headers = {})
    run_request(:post, request_url(route, params), body, headers)
  end

  def put(route, body = nil, params = {}, headers = {})
    run_request(:put, request_url(route, params), body, headers)
  end

  def delete(route, body = nil, params = {}, headers = {})
    run_request(:delete, request_url(route, prams), body, headers)
  end

  def run_request(method, route, body, headers)
    login if !is_authorized?
    begin
      @connection.run_request(method, route, body, { 'Authorization' => @token }.merge(headers))
    rescue AppnexusApi::Unauthorized => e
      if @retry == true
        raise AppnexusApi::Unauthorized, e
      else
        @retry = true
        logout
        run_request(method, route, body, headers)
      end
    rescue Faraday::Error::TimeoutError => e
      raise AppnexusApi::Timeout, 'Timeout'
    ensure
      @retry = false
    end
  end

  private

  def request_url(route, params = nil)

    return route unless params.present?

    params = params.delete_if {|key, value| value.nil? }

    @connection.build_url(route, params)
  end
end
