class LinkComponentPreview < ViewComponent::Preview
  layout "view_component_preview"

  # @!group
  def default
    render LinkComponent.new(url: '#') do
      "Top"
    end
  end
  # @!endgroup
end