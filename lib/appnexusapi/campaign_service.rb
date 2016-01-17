class AppnexusApi::CampaignService < AppnexusApi::Service
  def update(id, attributes={})
    raise(AppnexusApi::NotImplemented, "Service is read-only.") if @read_only
    advertiser_id = attributes.delete(:advertiser_id)
    attributes = {name => attributes }
    params = {id: id, advertiser_id: advertiser_id}.to_query
    response = @connection.put([uri_suffix, params].join('?'), attributes).body['response']
    if response['error_id']
      response.delete('dbg')
      raise AppnexusApi::BadRequest.new(response.inspect)
    end
    true
  end
end
