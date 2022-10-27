# frozen_string_literal: true

class ButtonToComponent < ViewComponent::Base
  include CssClassesHelper
  attr_reader :name, :url, :method, :disabled, :button_classes, :turbo
  def initialize(name, url, method: :get, variant: :default, disabled: false, turbo: true)
    @name = name
    @url = url
    @method = method
    @disabled = disabled
    @turbo = turbo
    @button_classes = css_classes_for_button_variant(variant, disabled: disabled)
  end

  def call
    button_to name, url, method: method, data: { turbo: turbo }, disabled: disabled, class: button_classes
  end
end
