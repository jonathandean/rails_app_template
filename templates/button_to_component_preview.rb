class ButtonToComponentPreview < ViewComponent::Preview
  layout "view_component_preview"

  # @!group
  def default
    render ButtonToComponent.new("Default Button To", "/example")
  end

  def no_turbo
    render ButtonToComponent.new("No Turbo Button To", "/example", turbo: false)
  end

  def primary
    render ButtonToComponent.new("Primary Button To", "/example", method: :get, variant: :primary)
  end

  def post
    render ButtonToComponent.new("Primary Post Button To", "/example", method: :post, variant: :primary)
  end

  def disabled
    render ButtonToComponent.new("Disabled Button To", "/example", method: :get, variant: :primary, disabled: true)
  end
  # @!endgroup
end