module ApplicationHelper
  include CustomNamedRoutes

  # Adding current user role to page class
  def body_class
    classes = []
    if logged_in?
      classes << 'logged-in'
      classes << 'staff' if current_user.is_staff?
      classes << current_user.role
    else
      classes << 'logged-out'
    end
    classes.join ' '
  end

  # Return a title on a per-page basis.
  def title
    base_title = ""
    if @title.nil?
      base_title
    else
      "#{@title}"
    end
  end

  # Add class="active" to navigation item of current page
  def cp(path)
    "active" if current_page?(path)
  end

  def link_to_add_fields(name, f, association)
    new_object = f.object.send(association).klass.new
    id = new_object.object_id
    fields = f.fields_for(association, new_object, child_index: id) do |builder|
      render(association.to_s.singularize + "_fields", f: builder)
    end
    link_to(name, '#', class: "add_fields", data: {id: id, fields: fields.gsub("\n", "")})
  end

  def json_for(target, options = {})
    options[:scope] ||= self
    options[:url_options] ||= url_options
    target.active_model_serializer.new(target, options).to_json
  end

  # Search items 
  def autocomplete_items
    return [] unless current_user.is_staff?
    current_course.students.map do |u|
      { :name => [u.first_name, u.last_name].join(' '), :id => u.id }
    end
  end

  def success_button_class(classes = nil)
    [classes, 'button radius tiny'].compact.join(' ')
  end

  def table_link_to(name = nil, options = nil, html_options = nil, &block)
    html_options ||= {}
    html_options[:class] = [html_options[:class], 'button radius tiny'].compact.join(' ')
    link_to name, options, html_options, &block
  end

  # Commas in numbers!
  def points(value)
    number_with_delimiter(value)
  end


end
