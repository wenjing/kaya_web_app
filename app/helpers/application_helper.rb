module ApplicationHelper
  
  # Return a title on a per-page basis.
  def title
    base_title = "Kaya Mobile App"
    if @title.nil?
      base_title
    else
      "#{base_title} | #{@title}"
    end
  end
  
  def logo
    image_tag("kaya-logo-2-blueletter-on-white-3.jpg", :alt => "Kaya Mobile App", :class => "round")
  end
end
