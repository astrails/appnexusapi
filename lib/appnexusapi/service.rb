class AppnexusApi::Service

  attr_reader :count

  def initialize(connection)
    @connection = connection
    @count = nil
  end

  def name
    @name ||= begin
      str = self.class.name.split("::").last.gsub("Service", "")
      str.gsub(/(.)([A-Z])/, '\1_\2').downcase
    end
  end

  def plural_name
    name + 's'
  end

  def resource_class
    @resource_class ||= begin
      resource_name = name.capitalize.gsub(/(_(.))/) { |c| $2.upcase }
      AppnexusApi.const_get(resource_name + "Resource")
    end
  end

  def uri_name
    name.gsub('_', '-')
  end

  def plural_uri_name
    uri_name + 's'
  end

  def uri_suffix
    uri_name
  end

  def get(params={})
    return_response = params.delete(:return_response) || false
    params = {
      "num_elements" => 100,
      "start_element" => 0
    }.merge(params)
    response = @connection.get(uri_suffix, params).body['response']
    @count = response["count"]
    if return_response
      response
    elsif response.has_key?(plural_name) || response.has_key?(plural_uri_name)
      key = response.has_key?(plural_name) ? plural_name : plural_uri_name
      response[key].map do |json|
        resource_class.new(json, self)
      end
    elsif response.has_key?(name) || response.has_key?(uri_name)
      key = response.has_key?(name) ? name : uri_name
      [resource_class.new(response[key], self)]
    end
  end

  def create(attributes = {})
    raise(AppnexusApi::NotImplemented, "Service is read-only.") if @read_only
    params = path_params(attributes)
    attributes = { uri_name => attributes }
    response = @connection.post(uri_suffix, attributes, params).body['response']
    if response['error_id']
      response.delete('dbg')
      raise AppnexusApi::BadRequest.new(response.inspect)
    end
    get("id" => response["id"]).first
  end

  def update(id, attributes = {})
    raise(AppnexusApi::NotImplemented, "Service is read-only.") if @read_only
    params = path_params(attributes, id: id)
    attributes = { uri_name => attributes }
    response = @connection.put(uri_suffix, attributes, params).body['response']
    if response['error_id']
      response.delete('dbg')
      raise AppnexusApi::BadRequest.new(response.inspect)
    end
    get("id" => response["id"]).first
  end

  def delete(id, attributes = {})
    raise(AppnexusApi::NotImplemented, "Service is read-only.") if @read_only
    params = path_params(attributes, id: id)
    @connection.delete(uri_suffix, nil, params).body['response']
  end

  private

  def path_params(attributes, params = {})
    return params unless self.class.const_defined?(:EXTRA_PATH_ATTRIBUTES)

    params.merge(attributes.slice(*self.class.const_get(:EXTRA_PATH_ATTRIBUTES)))
  end
end
