require 'digest/sha1'

class Team < ActiveRecord::Base
	validates_length_of :password, :minimum => 5, :if => :password_validation_required? # Validate this further???
	validates_presence_of :number
	validates_presence_of :tournament_id
	validates_presence_of :division
	validates_uniqueness_of :number, :scope => [:tournament_id, :division]
	validates_uniqueness_of :name, :scope => [:tournament_id, :division]
    validates_confirmation_of :password

	belongs_to :tournament
	has_many :sign_ups, :dependent => :destroy
    has_many :scores
	attr_accessor :password, :password_confirmation, :password_existing
    attr_protected :hashed_password


	@@divisions = {"B" => "B", "C" => "C"}
	
	# Returns 
	def getNumber()
		return [number, division].join
	end
	
	# Counterintuitively, self denotes a class (static) method.	
	def self.authenticate(id, password)
		u = find(:first, :conditions=>["id = ?", id])
		return nil if u.nil?
		return u if encrypt(password)==u.hashed_password
		nil
	end

	def self.encrypt(pass)
		return Digest::SHA1.hexdigest(pass)
	end

	def password=(pass) #Rails magic -- gets called whenever a password is assigned (u.password = "secret")
		@password = pass
		self.hashed_password = Team.encrypt(@password)
	end
	def password_validation_required?
		return self.hashed_password.blank? || !self.password.blank? || !self.password_existing.blank?
	end

	def self.divisions
		return @@divisions
	end

    def total_points
      total_points = self.scores.map{|x| x.schedule.counts_for_score ? x.placement : 0}.sum
    end

    def rank_matrix
      # Something like [98, -1, -3, -4, -2, 0, ... ] to sort teams on.
      # 98 is total points
      # 1 is number of first places, etc., negative because we're sorting in increasing order
      places = self.scores.map(&:placement).group_by(&:abs).reduce({}){|a,i| a.merge({i[0] => -i[1].length})}
      num_teams = self.tournament.teams.select{|x| x.division == self.division}.length

      [total_points.abs] + (num_teams+1).times.map{|x| places[x+1] || 0}
    end

  	# Returns list of all schedules that this team still needs to register for using set subtraction.
	def unregistered_events
      self.tournament.schedules.where(["schedules.division=?", self.division]).keep_if(&:is_scheduled_online?) -
      self.sign_ups.includes({:timeslot => :schedule}).map{|x| x.timeslot.schedule}
	end

    def can_register_for_event?(s)
      return false unless s.division == self.division
      return s.tournament.can_register()
    end
end
