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
        structure
      end

      # EWS Item hash
      #
      # Puts all known parameters in the required structure
      # @return [Hash]
      def to_ews_item(opts={})
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
            when :physical_addresses
              if opts[:update]
                item_parameters[key] ||= []
                item_parameters[key] << set_physical_addresses_for_update(value)
              else
                item_parameters[key] = set_physical_addresses_for_create(value)
              end
            when :email_addresses
              item_parameters[key] = set_email_addresses(value, opts)
            when :phone_numbers
              item_parameters[key] = set_phone_numbers(value, opts)
            else
              item_parameters[key] = value
            end
          end
        end

        item_parameters
      end


      private


      def set_physical_addresses_for_update(address)
        field = address.keys.first
        {
          entry: { 
            Key: address[field][:key],
            sub_elements: [{ field => { text: address[field][:text] } }]
          }
        }
      end

      def set_physical_addresses_for_create(addresses)
        Array.wrap(addresses).map do |address|
          item = { entry: {} }
          item[:entry][:key] = address[:key] if address[:key].present?
          item[:entry][:street] = address[:street] if address[:street].present?
          item[:entry][:city] = address[:city] if address[:city].present?
          item[:entry][:state] = address[:state] if address[:state].present?
          item[:entry][:country_or_region] = address[:country_or_region] if address[:country_or_region].present?
          item[:entry][:postal_code] = address[:postal_code] if address[:postal_code].present?
          item
        end
      end

      def set_phone_numbers(phone_numbers, opts)
        Array.wrap(phone_numbers).map do |num|
          item = { entry: {} }
          item[:entry][get_key_name(opts)] = num[:key] if num[:key].present?
          item[:entry][:text] = num[:text] if num[:text].present?
          item
        end
      end

      def set_email_addresses(emails, opts)
        Array.wrap(emails).each_with_index.map do |email, index|
          item = { entry: {} }
          item[:entry][get_key_name(opts)] = email[:key]  if email[:key].present?
          item[:entry][:text] = email[:text] if email[:text].present?
          item
        end
      end

      # NOTE: Capitalized Key required only when Updating
      def get_key_name(opts={})
        key_name = opts[:update] ? :Key : :key
      end

    end
  end
end
