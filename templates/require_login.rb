module RequireLogin
  extend ActiveSupport::Concern

  included do
    before_action :require_login!
  end

  def require_login!
    unless logged_in?
      respond_to do |format|
        format.json {
          render json: {
            success: false,
            message: "Authentication required.",
            timestamp: DateTime.now.strftime('%Q').to_i
          }, status: :forbidden
        }
        format.html {
          flash.alert = "Please log in to view this page."
          redirect_to root_path
        }
      end
    end
  end
end