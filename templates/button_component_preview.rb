class ButtonComponentPreview < ViewComponent::Preview
  layout "view_component_preview"

  # @!group
  def default
    render ButtonComponent.new do
      "Default Button"
    end
  end

  def primary
    render ButtonComponent.new(variant: :primary) do
      "Primary Button"
    end
  end

  def submit
    render ButtonComponent.new(variant: :primary, type: "submit") do
      "Submit Button"
    end
  end

  def disabled
    render ButtonComponent.new(variant: :primary, type: "submit", disabled: true) do
      "Disabled Button"
    end
  end
  # @!endgroup
end