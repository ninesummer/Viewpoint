module Viewpoint::EWS::Types
  class Contact
    include Viewpoint::EWS
    include Viewpoint::EWS::Types
    include Viewpoint::EWS::Types::Item

    CONTACT_KEY_PATHS = {
      given_name:         [:given_name, :text],
      surname:            [:surname, :text],
      yomi_given_name:    [:yomi_given_name, :text],
      yomi_surname:       [:yomi_surname, :text],
      display_name:       [:display_name, :text],
      company_name:       [:company_name, :text],
      yomi_company_name:  [:yomi_company_name, :text],
      email_addresses:    [:email_addresses, :elems],
      physical_addresses: [:physical_addresses, :elems],
      phone_numbers:      [:phone_numbers, :elems],
      department:         [:department, :text],
      job_title:          [:job_title, :text],
      office_location:    [:office_location, :text],
    }

    CONTACT_KEY_TYPES = {
      email_addresses:    :build_email_addresses,
      physical_addresses: :build_physical_addresses,
      phone_numbers:      :build_phone_numbers
    }

    CONTACT_KEY_ALIAS = {
      first_name:      :given_name,
      last_name:       :surname,
      yomi_first_name: :yomi_given_name,
      yomi_last_name:  :yomi_surname,
      emails:          :email_addresses,
      addresses:       :physical_addresses,
      title:           :job_title,
      company:         :company_name,
      office:          :office_location,
    }

    # Updates the specified item attributes
    #
    # Uses `SetItemField` if value is present and `DeleteItemField` if value is blank
    # @param updates [Hash] with (:attribute => value)
    # @param options [Hash]
    # @option options :conflict_resolution [String] one of 'NeverOverwrite', 'AutoResolve' (default) or 'AlwaysOverwrite'
    def update_item!(attributes, opts={})
      contact = {}
      updates = map_attributes_to_updates(attributes)
      contact[:item_changes] = [{ item_id: self.item_id, updates: build_updates(updates) }]
      contact[:conflict_resolution] = opts[:conflict_resolution] || "AutoResolve"
      update_contact(contact)
    end


    private


    def update_contact(data)
      rm = ews.update_item(data).response_messages.first
      if rm && rm.success?
        self.get_all_properties!
        self
      else
        raise EwsCreateItemError, "Could not update Contact. #{rm.code}: #{rm.message_text}"
      end
    end

    def map_attributes_to_updates(attributes)
      attributes.reduce([]) do |memo, (attribute, value)|
        is_indexed = FIELD_URIS[attribute][:ftype] == :indexed_field_uRI rescue nil
        if is_indexed
          memo |= expanded_index_field(attribute, value)
        else
          memo << { attribute => value }
        end
        memo
      end
    end

    def expanded_index_field(attribute, values)
      Array.wrap(values).map do |value|
        { attribute => value }
      end
    end

    # EWS Item Updates Array
    #
    # Uses `SetItemField` if value is present and `DeleteItemField` if value is blank
    # @return [Array]
    def build_updates(updates)
      updates.reduce([]) do |memo, update|
        attribute, value = update.to_a.first # { attribute => value }

        # Special Case for PhysicalAddresses
        if attribute == :physical_addresses
          update = build_physical_address_update(attribute, value)
          memo << update if update
          next memo
        end

        field_uri_name = attribute
        field_index    = value[:key] rescue nil
        item_field     = build_item_field(field_uri_name, field_index)

        memo << get_item_field_update(item_field, attribute, value) if item_field
        memo
      end
    end

    def build_physical_address_update(attribute, value)
      field_uri_name = value.keys.first rescue nil
      field_index = value.values.first[:key] rescue nil

      item_field = build_item_field(field_uri_name, field_index)
      if item_field
        get_item_field_update(item_field, attribute, value)
      end
    end

    def build_item_field(field_uri_name, field_index=nil)
      item_field = nil
      if FIELD_URIS.include?(field_uri_name)
        item_uri = FIELD_URIS[field_uri_name][:text]
        item_ftype = FIELD_URIS[field_uri_name][:ftype] 
      end
      if item_uri
        field_type = item_ftype || :field_uRI
        item_field = { field_type => { field_uRI: item_uri } }
        item_field[field_type].merge!({ field_index: field_index }) if field_index && field_type == :indexed_field_uRI
      end
      item_field
    end

    def get_item_field_update(field, attribute, value)
      if is_blank_value(attribute, value)
        { delete_item_field: field }
      else
        item = Viewpoint::EWS::Template::Contact.new(attribute => value)
        { set_item_field: field.merge(contact: { sub_elements: map_sub_elements(item) }) }
      end
    end

    # Remap attributes to sub elements because ews_builder #dispatch_field_item! uses #build_xml!
    def map_sub_elements(item)
      item.to_ews_item({ update: true }).map do |name, value|
        map_sub_element(name, value)
      end
    end

    def map_sub_element(name, value)
      case value
      when Hash
        node = { name => {} }
        value.each do |attrib_key, attrib_value|
          attrib_key = camel_case(attrib_key) unless attrib_key == :text
          node[name][attrib_key] = attrib_value
        end
        node
      when String
        { name => { text: value } }
      when Array
        { name => { sub_elements: value } }
      else
        { name => value }
      end
    end

    def is_blank_value(attribute, value)
      value.blank? ||
        (attribute == :email_addresses && value[:text].blank?) ||
        (attribute == :phone_numbers && value[:text].blank?) ||
        (attribute == :physical_addresses && value.values.first[:text].blank?)
    end

    def build_phone_number(phone_number)
      Types::PhoneNumber.new(ews, phone_number)
    end

    def build_phone_numbers(phone_numbers)
      return [] if phone_numbers.nil?
      phone_numbers.collect { |pn| build_phone_number(pn[:entry]) }
    end

    def build_email_address(email)
      Types::EmailAddress.new(ews, email)
    end

    def build_email_addresses(users)
      return [] if users.nil?
      users.collect { |u| build_email_address(u[:entry]) }
    end

    def build_physical_address(address_ews)
      Types::PhysicalAddress.new(ews, address_ews)
    end

    def build_physical_addresses(addresses)
      return [] if addresses.nil?
      addresses.collect { |a| build_physical_address(a[:entry]) }
    end

    def key_paths
      super.merge(CONTACT_KEY_PATHS)
    end

    def key_types
      super.merge(CONTACT_KEY_TYPES)
    end

    def key_alias
      super.merge(CONTACT_KEY_ALIAS)
    end


  end
end
