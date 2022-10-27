# frozen_string_literal: true

class ButtonComponent < ViewComponent::Base
  include CssClassesHelper
  attr_reader :button_classes, :type, :disabled
  def initialize(variant: :default, type: "button", disabled: false)
    @type = type
    @disabled = disabled
    @button_classes = css_classes_for_button_variant(variant, disabled: disabled)
  end
end
