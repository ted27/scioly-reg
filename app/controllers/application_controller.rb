class ApplicationController < ActionController::Base
  protect_from_forgery
  before_filter :setup

  def setup
	breadcrumbs.add 'Home', root_path

	@current_tournament = Tournament.get_current()
	@all_schedules = Schedule.find(:all, :order => "event ASC")
	
	if not session[:team].nil?
		@dont_forget = SignUp.getTeamUnregistered(session[:team])
	end
  end

  def is_admin
	  if session[:user].nil?
		  redirect_to :root
		  return
	  end
	  if not User.is_admin(session[:user])
			  redirect_to :root
			  return
	  else
			  breadcrumbs.add("Admin", admin_index_url)
	  end
  end
end
