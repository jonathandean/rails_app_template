module CssClassesHelper
  def css_classes_for_button_variant(variant, disabled: false)
    variant_classes = if disabled
                        "border-gray-300 bg-white text-gray-400 cursor-not-allowed"
                      else
                        case variant
                        when :primary
                          "border-blue-600 bg-blue-500 hover:bg-blue-600 hover:border-blue-700 text-white"
                        else
                          "border-gray-300 bg-white text-gray-700 hover:bg-gray-50"
                        end
                      end
    "#{variant_classes} border py-2 px-4 rounded-md"
  end
end