class Auth0Controller < ApplicationController

  def callback
    # OmniAuth stores the informatin returned from Auth0 and the IdP in request.env['omniauth.auth'].
    # In this code, you will pull the raw_info supplied from the id_token and assign it to the session.
    # Refer to https://github.com/auth0/omniauth-auth0#authentication-hash for complete information on 'omniauth.auth' contents.
    auth_info = request.env['omniauth.auth']
    auth0_id = auth_info['extra']['raw_info']['sub']
    user = User.find_or_create_by!(auth0_id: auth0_id)
    session[:user_id] = user.id
    session[:user_info] = auth_info['extra']['raw_info']

    # Redirect to the URL you want after successful auth
    flash.notice = "You are now logged in!"
    redirect_to root_path
  end

  def failure
    # Handles failed authentication -- Show a failure page (you can also handle with a redirect)
    flash.alert = request.params['message']
    redirect_to root_path
  end

  def logout
    reset_session
    redirect_to logout_url, allow_other_host: true
  end

  private

  def logout_url
    request_params = {
      returnTo: root_url,
      client_id: ENV.fetch('AUTH0_CLIENT_ID')
    }

    URI::HTTPS.build(host: ENV.fetch('AUTH0_DOMAIN'), path: '/v2/logout', query: to_query(request_params)).to_s
  end

  def to_query(hash)
    hash.map { |k, v| "#{k}=#{CGI.escape(v)}" unless v.nil? }.reject(&:nil?).join('&')
  end
end
