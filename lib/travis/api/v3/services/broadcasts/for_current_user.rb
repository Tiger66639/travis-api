module Travis::API::V3
  class Services::Broadcasts::ForCurrentUser < Service
    def run!
      raise LoginRequired unless access_control.logged_in?
      query.for_user(access_control.user)
    end
  end
end
