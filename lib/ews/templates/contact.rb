module Viewpoint::EWS
  module Template
    class Contact < OpenStruct

      # Available parameters
      PARAMETERS = %w{
        saved_item_folder_id file_as given_name company_name
        email_addresses physical_addresses phone_numbers
        job_title department office_location manager assistant_name 
        surname
      }.map(&:to_sym).freeze

      # Returns a new Contact template
      def initialize(opts = {})
        super opts.dup
      end

      # EWS CreateItem container
      # @return [Hash]
      def to_ews_create(opts = {})
        structure = {}

        if self.saved_item_folder_id
          if self.saved_item_folder_id.kind_of?(Hash)
            structure[:saved_item_folder_id] = saved_item_folder_id
          else
            structure[:saved_item_folder_id] = { id: saved_item_folder_id }
          end
        end
      
        structure[:items] = [{ contact: to_ews_item }]
        puts "STRUCTURE: #{structure}"
        structure
      end

      # EWS Item hash
      #
      # Puts all known parameters in the required structure
      # @return [Hash]
      def to_ews_item
        item_parameters = {}

        PARAMETERS.each do |key|
          if !(value = self.send(key)).nil?

            # Convert non duplicable values to String
            case value
            when NilClass, FalseClass, TrueClass, Symbol, Numeric
              value = value.to_s
            end

            # Convert attributes
            case key
            when :email_addresses
              item_parameters[key] = value.each_with_index.map do |email, index|
                item = { entry: {} }
                item[:entry][:key] = "EmailAddress#{index + 1}"
                item[:entry][:text] = email[:text]
                item
              end
            when :physical_addresses
              item_parameters[key] = value.map do |address|
                item = { entry: {} }
                item[:entry][:key] = address[:key] if address[:key].present?
                item[:entry][:street] = address[:street]
                item[:entry][:city] = address[:city]
                item[:entry][:state] = address[:state]
                item[:entry][:country_or_region] = address[:country_or_region]
                item[:entry][:postal_code] = address[:postal_code]
                item
              end
            when :phone_numbers
              item_parameters[key] = value.map do |num|
                item = { entry: {} }
                item[:entry][:key] = num[:key] if num[:key].present?
                item[:entry][:text] = num[:text]
                item
              end
            else
              item_parameters[key] = value
            end
          end
        end

        item_parameters
      end
    end
  end
end
