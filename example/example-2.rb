#Module for rudderstack service:
require 'rudder_analytics_sync'
include RudderAnalyticsSync

#Domains::Analytics::RudderstackService.identify(id)
module Domains::Analytics
  class RudderstackService
    attr_accessor :client
      def initialize
        analytics = RudderAnalyticsSync::Client.new(
		  write_key: '2HtV3iH9jQ8x3KZ85KG9zPFMcHT', # required
		  data_plane_url: 'https://rudderstacz.dataplane.rudderstack.com',
		  stub: true,
		  on_error: proc { |error_code, error_body, exception, response|
		    # defaults to an empty proc
		  }
		)

		@client = analytics
      end

      # Identifies a unique user in rudderstack
      # https://www.rudderstack.com/docs/sources/event-streams/sdks/rudderstack-ruby-sdk/
      # === Parameters
      #
      # user_id (integer) 
      # === Response
      #
      # nil
      def identify(user_id)
      	user = User.find_by(id: user_id)
      	if !user
      		return
      	end
      	properties = get_properties(user, 'account_created')

		client.identify(
		  user_id: user.id,
		  traits: properties,
		)
      end

      # Tracks an event attributed to a user
      # https://www.rudderstack.com/docs/sources/event-streams/sdks/rudderstack-ruby-sdk/
      # === Parameters
      #
      # user_id (integer)
      # event_uid (string) 
      # context (object)
      # === Response
      #
      # nil
      def track(user_id, event_uid, context=nil)
      	user = User.find_by(id: user_id)
      	if !user
      		return
      	end

      	properties = get_properties(user, event_uid, context)
      	puts properties, "sending..."

		client.track(
		  user_id: user.id,
		  event: event_uid,
		  properties: properties
		)
      end

      def get_properties(user, event_uid, context)
      	base_properties = {
			email: user.email, 
			tier: user.tier,
			fir_name: user.fir_name,
			las_name: user.las_name,
			billing_type: user.profile&.billing_type,
			clinic_id: user.profile&.clinic_id 
  		}

      	additional_properties = case event_uid
      	when 'account_created'
      		{}
		when 'induction_scheduled'
			{
				cal_event: CalEvent.find_by(id: context[:cal_event_id])
			}
		when 'induction_attended'
			{
				cal_event: CalEvent.find_by(id: context[:cal_event_id])
			}
		when 'appointment_scheduled'
			{
				cal_event: CalEvent.find_by(id: context[:cal_event_id])
			}
		when 'appointment_updated'
			{
				cal_event: CalEvent.find_by(id: context[:cal_event_id])
			}
		when 'course_complete'
		when 'discharge_finalized'
		when 'user_status_updated'
		when 'user_merge'
		when 'no_show_potential'
		when 'user_logged_in'
		when 'drug_test_ordered'
		else
			{}
		end

		return base_properties.merge(additional_properties)
	end
  end
end