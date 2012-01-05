class AdminController < ApplicationController
  before_filter :is_admin

  def index
    breadcrumbs.add("Admin Panel")
    @teams = @current_tournament.teams

    @signups = SignUp.all
    @num_signups = @signups.length
    @team_signups = @signups.map{|x| x.team.name}.uniq
    @num_team_signups = @team_signups.length
  end

  def events
    breadcrumbs.add("Events")
    @events = @current_tournament.schedules
    @teams_by_division = Team.divisions.inject({}) {|a,i| 
      a.merge(i[0] => Team.count(:conditions=>["division = ?", i[0]]))
    }
    @event_signups = @events.inject({}){|a,i| 
      a.merge(i.id => i.timeslots.map{|x| x.sign_ups.length}.sum )
    }
    @event_capacity = @events.inject({}){ |a,i|
      a.merge(i.id => i.timeslots.map{|x| x.team_capacity - x.sign_ups.length}.sum)
    }
  end

  def scores
    breadcrumbs.add("Scoring")

    @events = @current_tournament.schedules.includes(:scores)
  end
end
