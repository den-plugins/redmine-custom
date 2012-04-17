module Delayed
  module ScheduledJob
    
    def self.included(base)
      base.extend(ClassMethods)
      base.class_eval do
        @@logger = Delayed::Worker.logger
        cattr_reader :logger
      end
    end

    def perform_with_schedule
      perform_without_schedule
      schedule! # only schedule if job did not raise
    end

    # schedule this "repeating" job unless already scheduled
    def schedule!(run_at = nil)
      run_at ||= self.class.run_at
      Delayed::Job.enqueue(self, 0, run_at) unless self.class.scheduled?(self.to_yaml)
    end

    # re-schedule this job instance
    def reschedule!
      schedule! Time.now
    end

    module ClassMethods

      def method_added(name)
        if name.to_sym == :perform && !instance_methods(false).map(&:to_sym).include?(:perform_without_schedule)
          alias_method_chain :perform, :schedule
        end
      end

      def run_at
        run_interval.respond_to?(:from_now) ? run_interval.from_now : run_interval
      end

      def run_interval
        @run_interval ||= 1.hour
      end

      def run_every(time)
        @run_interval = time
      end

      #

      def schedule(run_at = nil)
        schedule!(run_at) unless scheduled?
      end
      
      def schedule!(run_at = nil)
        new.schedule!(run_at)
      end

      def scheduled?(handler = nil)
        Delayed::Job.find(:all, :conditions => ["handler = ? and run_at = ?", "#{handler}", run_interval]).count > 0
      end

    end

  end
end
