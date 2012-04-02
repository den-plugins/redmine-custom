module CustomUsersHelper
  include CustomFieldsHelper

  def custom_field_tag(name, custom_value)
      custom_field = custom_value.custom_field
      field_name = "#{name}[custom_field_values][#{custom_field.id}]"
      field_id = "#{name}_custom_field_values_#{custom_field.id}"

      case custom_field.field_format
      when "date"
        text_field_tag(field_name, custom_value.value, :id => field_id, :size => 10, :autocomplete => "off") +
        calendar_for(field_id)
      when "text"
        text_area_tag(field_name, custom_value.value, :id => field_id, :rows => 3, :style => 'width:90%')
      when "bool"
        check_box_tag(field_name, '1', custom_value.true?, :id => field_id) + hidden_field_tag(field_name, '0')
      when "list"
        blank_option = custom_field.is_required? ?
                         (custom_field.default_value.blank? ? "<option value=\"\">--- #{l(:actionview_instancetag_blank_option)} ---</option>" : '') :
                         '<option></option>'
        select_tag(field_name, blank_option + options_for_select(custom_field.possible_values, custom_value.value), :id => field_id)
      else
        text_field_tag(field_name, custom_value.value, :id => field_id)
      end
  end

  def custom_field_label_tag(name, custom_value)
    content_tag "label", custom_value.custom_field.name +
  	(custom_value.custom_field.is_required? ? " <span class=\"required\">*</span>" : ""),
  	:for => "#{name}_custom_field_values_#{custom_value.custom_field.id}",
  	:class => (custom_value.errors.empty? ? nil : "error" )
  end

  def custom_field_tag_with_label(name, custom_value)
    custom_field_label_tag(name, custom_value) + custom_field_tag(name, custom_value)
  end

end
