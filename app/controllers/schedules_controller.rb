class SchedulesController < ApplicationController
  ####
  # A "schedule" means a "scheduled event" for a given
  # tournament and division. In other words, a "schedule"
  # is what a team registers to.
  ###

  before_filter :is_admin, :only => [:new, :destroy, :batchnew, :edit, :create, :update, :scores, :savescores, :batchcreate, :all_pdfs]
  protect_from_forgery :except => :destroy

  def new
    breadcrumbs.add("New Event")
    @schedule = Schedule.new()
  end

  def batchnew
    breadcrumbs.add("New Event", new_schedule_url())
    @can_load_default_events = DefaultEvent.for_year(@current_tournament.date.year).present?
    breadcrumbs.add("Batch Mode")
  end

  def edit
    @schedule = Schedule.find(params[:id])
    breadcrumbs.add("Events", admin_events_url())
    breadcrumbs.add(@schedule.humanize, schedule_url(@schedule))
    breadcrumbs.add("Edit")
  end

  def update
    @schedule = Schedule.find(params[:id])
    @schedule.update_attributes(schedule_params)
    @schedule.updateTimeSlots if params[:schedule_online] == "true"
    @schedule.timeslots.destroy_all if params[:schedule_online] == "false"
    redirect_to edit_schedule_url(@schedule)
  end

  def create
    @schedule = @current_tournament.schedules.create(schedule_params)
    if @schedule
      if params[:schedule_online] == "true"
        @schedule.updateTimeSlots()
      end
      redirect_to :schedules
    else
      flash[:message] = "Error creating the event schedule. "
      flash[:error] = @schedule.errors.full_messages.first
      render :new
    end
  end

  def batchcreate
    schedules = params[:batch].split("\n")
    @errors = []

    schedules.each do |s|
      a = s.strip.split("\t")

      if a.length < 7
        @errors << "Schedule #{a[0]} does not have enough fields."
        next
      end

      if a[0] == 'Event Name' || s[0] == '#'
        next
      end

      event, division, room, starttime, endtime, num_timeslots, teams_per_slot = [
        a[0],
        a[1],
        a[2],
        a[3] == 'TBD' ? nil : Time.zone.parse(a[3]).to_time,
        a[4] == 'TBD' ? nil : Time.zone.parse(a[4]).to_time,
        a[5].to_i,
        a[6].to_i
      ]

      schedule = @current_tournament.schedules.where(
        :event => event,
        :division => division,
      ).first_or_create

      success = schedule.update_attributes(
        :room => room,
        :starttime => starttime,
        :endtime => endtime,
        :num_timeslots => num_timeslots,
        :teams_per_slot => teams_per_slot
      )

      if success
        if schedule.num_timeslots != 0
          res = schedule.updateTimeSlots
          if !res.is_a?(Array)
            @errors << "#{res} with #{a[0]}. No timeslots have been created for this event."
          end
        end
      else
        @errors << schedule.errors.full_messages.first
      end
    end

    flash[:error] = @errors.join("<br />") unless @errors.empty?

    if not flash[:error]
      redirect_to admin_events_url
    else
      render :batchnew
    end
  end

  def index
    breadcrumbs.add('Register For Events')
    if not @team.nil?
      @has_registered = Hash.new()
      @all_schedules[@team.division].map{ |e| @has_registered[e.id] = e.hasTeamRegistered(@team)}
    end
    render :list
  end

  def show
    @schedule = Schedule.find(params[:id])
    breadcrumbs.add("Division #{@schedule.division} Events", division_schedules_url(@schedule.division))
    @scores = @schedule.scores.includes(team: :tournament)
    breadcrumbs.add(@schedule.event)
    if @schedule.nil?
      flash[:message] = "Event not found!"
      # render :somethingelse
    end

    @allslots = @schedule.timeslots.sort { |x,y| x.begins <=> y.begins }
    @currentreg = nil
    if @team
      @currentreg = SignUp.find_by_team_id_and_timeslot_id(@team, @allslots.map{|x| x.id})
    end

    respond_to do |format|
      format.html do
        render :show
      end
      format.pdf do
        if !@is_admin
          flash[:error] = 'You must be a tournament administrator to download event registration PDFs. Please contact the tournament director if you need a PDF for yourself.'
          return redirect_to schedule_url(@schedule)
        end

        render :pdf => @schedule.event.gsub(/[^a-zA-Z]/, '_') + "_" + @schedule.division
      end
    end
  end

  def all_pdfs
    respond_to do |format|
      format.pdf do
        @schedules = @current_tournament.schedules.includes(:timeslots => :occupants).find_all { |e| e.is_scheduled_online? }
        render :pdf => "ScienceOlympiadRegistration-#{@current_tournament.human_times[:date_filename]}"
      end
    end
  end

  def destroy
    @schedule = Schedule.find(params[:id])
    @schedule.destroy
    redirect_to :admin_events
  end

  def scores
    @schedule = Schedule.find(params[:schedule_id], :include => :scores)
    @teams = @current_tournament.teams.where("division = ?", @schedule.division).includes(:tournament)
    @placements = @teams.inject({}) { |a,i|
      s = @schedule.scores.select{|x| x.team_id == i.id}.first
      if s
        a.merge(i.id => s.placement)
      else
        a.merge(i.id => "")
      end
    }
    breadcrumbs.add("Scoring", "/admin/scores")
    breadcrumbs.add(@schedule.humanize)
  end

  def savescores
    @schedule = Schedule.find(params[:schedule_id])
    @teams = @current_tournament.teams.where("division = ?", @schedule.division).includes(:tournament)

    @schedule.scores.each(&:destroy)

    if params[:score_action] == 'Reset Scores'
      return redirect_to schedule_scores_path(@schedule)
    end

    all_successful = true
    errors = []
    params[:placings].each do |k,v|
      placing = @schedule.scores.new({:team_id => k, :placement => v})
      all_successful = placing.save && all_successful
      errors << placing.errors.full_messages.first unless placing.errors.empty?
    end

    if params[:scores_withheld] == "true"
      @schedule.update_attribute(:scores_withheld, true)
    else
      @schedule.update_attribute(:scores_withheld, false)
    end

    if errors.empty?
      redirect_to admin_scores_url()
    else
      flash[:error] = errors.join("<br>")
      redirect_to schedule_scores_url(@schedule)
    end
  end

private

  def schedule_params
    params.fetch(:schedule, {}).permit(:event, :division, :room,
                                       :starttime, :endtime, :custom_info,
                                       :counts_for_score, :num_timeslots,
                                       :teams_per_slot)
  end
end
