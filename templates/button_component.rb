# frozen_string_literal: true

class ButtonComponent < ViewComponent::Base

  attr_reader :variant_classes, :type, :disabled
  def initialize(variant: :default, type: "button", disabled: false)
    @type = type
    @disabled = disabled
    if disabled
      @variant_classes = "border-gray-300 bg-white text-gray-400 cursor-not-allowed"
    else
      case variant
      when :primary
        @variant_classes = "border-blue-600 bg-blue-500 hover:bg-blue-600 hover:border-blue-700 text-white"
      else
        @variant_classes = "border-gray-300 bg-white text-gray-700 hover:bg-gray-50"
      end
    end
  end
end
