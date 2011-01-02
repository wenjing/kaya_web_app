module ApplicationHelper
  
  # Return a title on a per-page basis.
  def title
    base_title = "Kaya Meet"
    if @title.nil?
      base_title
    else
      "#{base_title} | #{@title}"
    end
  end
  
  def logo
    image_tag("logo_04.png", :alt => "Kaya Meet")
  end
end
