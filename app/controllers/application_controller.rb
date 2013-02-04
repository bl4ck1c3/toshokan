require 'netaddr'

class ApplicationController < ActionController::Base
  include Blacklight::Controller

  layout 'blacklight'

  rescue_from ActionController::RoutingError, :with => :render_not_found

  protect_from_forgery

  before_filter :authenticate

  # Authenticate users if certain criteria are met.
  # - No authentication will be done if user is already logged in.
  # - No authentication will be done if an authentication provider 
  #   has not been chosen. This will also check for sticky choice
  #   from :auth_provider cookie.
  def authenticate
    # Use sticky auth provider if it isn't already set in session
    session[:auth_provider] ||= cookies[:auth_provider]

    # No authentication if user is already logged in
    unless session[:user_id]
      # Only do authentication if an auth provider has been chosen
      if session[:auth_provider]
        # Return URL could be set by the authentication provider selection page
        session[:return_url] ||= request.url
        # Recreate user abilities on each login
        @current_ability = nil
        redirect_to polymorphic_url(:new_user_session)
      end
    end
  end

  helper_method :guest_user, :current_or_guest_user

  def current_user
    user = logged_in_user || guest_user
    user.walk_in = walk_in_request?
    return user
  end

  def logged_in_user
    if session[:user_id]
      user = User.find session[:user_id]
      user.impersonating = session.has_key? :original_user_id if user
      return user
    end
  end

  def walk_in_request?
    result = false
    remote = NetAddr::CIDR.create request.remote_ip
    Rails.application.config.walk_in[:ips].each do |ip|
      if ip.include? '-'
        # Range 
        lower, upper = NetAddr::CIDR.create($1), NetAddr::CIDR.create($2) if ip =~ /^(\S*)\s*-\s*(\S*)$/
        result ||= (lower..upper).include? remote
      elsif ip.include? '*'
        # Wildcard
        result ||= NetAddr.wildcard(ip).matches? remote
      else 
        # Standard
        result ||= NetAddr::CIDR.create(ip).matches? remote
      end
    end
    return result
  end

  def guest_user
    User.new
  end

  def current_or_guest_user
    current_user
  end

  # Call this to bail out quickly and easily when something is not found.
  # It will be rescued and rendered as a 404
  def not_found
    raise ActionController::RoutingError.new 'Not found'
  end

  # Render 401
  def deny_access
    render(:file => 'public/401', :format => :html, :status => :unauthorized, :layout => nil)
  end

  # Render a 404 response. This should not be called directly. Instead you should call #not_found
  # which will raise exception, rescue it and call this render method
  def render_not_found(exception)
    render :file => 'public/404', :format => :html, :status => :not_found, :layout => nil
  end
end
