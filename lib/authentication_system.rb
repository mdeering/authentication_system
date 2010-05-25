module AuthenticationSystem

  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration)
  end

  class Configuration

    attr_accessor :application_name, :login_url

    def initialize
      @application_name = 'Application'
      @login_url        = 'login_url'
    end

  end

  def self.included(base)
    configure do |c|
    end
    base.send :helper_method, :current_user, :logged_in?
    base.send :before_filter, :login_required
  end

  protected

    def authenticated?
      logged_in?
    end

    def authorized?
      false
    end

    def current_user
      @current_user ||= ( (current_user_session && current_user_session.record) || login_from_basic_auth)
    end

    def login_required
      return authentication_failed unless authenticated?
      return authorization_failed  unless authorized?
      true
    end

    def logged_in?
      current_user.present?
    end

  private

    def authentication_failed
      respond_to do |accepts|
        accepts.html do
          store_location
          flash[:error] = t 'flash.authentication_failed'
          redirect_to_login
        end
        accepts.all do
          headers['WWW-Authenticate'] = "Basic realm=\"#{ AuthenticationSystem.configuration.application_name }\""
          head :unauthorized
        end
      end
      false
    end

    def authorization_failed
      respond_to do |accepts|
        accepts.html do
          flash[:error] = t 'flash.authorization_failed'
          redirect_to_login
        end
        accepts.all { head :forbidden }
      end
      false
    end

    def current_user_session
      @current_user_session ||= UserSession.find
    end

    def login_from_basic_auth
      authenticate_with_http_basic do |email, password|
        @current_user_session = UserSession.create(email, password)
        @current_user_session.record
      end
    end

    def redirect_to_login
      redirect_to request.env['HTTP_REFERER'] || send(AuthenticationSystem.configuration.login_url)
    end

    def store_location
      session[:return_to] = request.request_uri
    end

end