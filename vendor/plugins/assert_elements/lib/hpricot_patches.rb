class Hpricot::Elem
  def should_contain(value)
    self.inner_text.include?(value)
  end

  def should_match(regex)
    self.inner_text.match(regex)
  end

  def html_should_contain(value)
    self.inner_html.include?(value)
  end

  def html_should_match(regex)
    self.inner_html.match(regex)
  end
  
  # courtesy of 'thomas' from the comments
  # of _whys blog - get in touch if you want a better credit!
  def inner_text
    self.children.collect do |child|
      child.is_a?(Hpricot::Text) ? child.content : ((child.respond_to?("inner_text") && child.inner_text) || "")
    end.join.strip
  end
end

class Hpricot::Doc
  def content_for(css_query)
    (c = self.search(css_query).first) ? c.inner_text : nil
  end

  def content_for_all(css_query)
    self.search(css_query).collect(&:inner_text)
  end
end
