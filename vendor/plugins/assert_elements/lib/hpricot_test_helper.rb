require 'hpricot'
require 'hpricot_patches'

# Test your HTML with Hpricot
#
# The HpricotTestHelper is added to Test::Unit::TestCase, so you can quickly
# and easily parse the HTML returned by your tests, and examine (and assert
# against) that HTML to ensure that certain elements were created correctly.
#
# The "workhorse" of this module, and the method you'll probably use most,
# is +assert_elements+.  It's syntax and common usage is based on Core Rails'
# +assert_select+ method, however by using Hpricot assert_elements is
# (hopefully) a lot faster, supports more CSS queries, and also supports
# XPath queries.
#
# Like +assert_select+, +assert_elements+ will accept a block of code to
# execute.  The code inside this block runs identically to code outside of
# the block, except that methods in +HpricotTestHelper+ (such as +tag+,
# +element+, and +assert_elements+) will run as though the HTML of the page
# consisted only of the elements which were selected by the outer
# +assert_elements+ call.  An example may help at this point.
#
# Assume that the HTML of your page looked like this:
#
#  <html>
#   <body>
#    <div id="one">
#     <p>
#      Something.
#     </p>
#     <div id="nested">
#      <p>
#       Blah blah
#      </p>
#     </div>
#    </div>
#    <div id="two">
#     <p>
#      Something else.
#     </p>
#    </div>
#   </body>
#  </html>
#
# If your test method called:
#
#  elements("div")
#
# Then you would get all three +div+ elements in that HTML.  However, if you
# ran this:
#
#  assert_elements("#one") do
#    elements("div")
#  end
#
# Then the +elements+ call would only get two +div+ elements -- +#one+ and
# +#nested+.  The div +#two+ wasn't in the "search tree" for the +elements+
# call because we'd narrowed the "scope" of our searched down to just the
# div +#one+.
#
# Something that should be noted here, though, is that the element or elements
# that are matched form part of the output -- you don't get just the contents
# of the matched elements.
#
# This documentation just touches on what +assert_elements+ and friends can
# do for you.  More detail on how to use +assert_elements+, including more
# usage examples, is available in the method-level documentation.
# 
module HpricotTestHelper
  # Returns the inner textual content of the first HTML element that is
  # matched by the given CSS or XPath query.  The textual content is
  # basically the HTML with the tags stripped out, so for a piece of HTML
  # like this:
  #
  #  <div id="test">
  #   <p>
  #    I <em>really</em> love <tt>assert_elements</tt>!
  #   </p>
  #  </div>
  #
  # Calling +tag('#test')+ will return the string "I really love
  # assert_elements!".
  #
  def tag(css_query)
    parsed_response.content_for(css_query)
  end
  
  # Returns the inner textual content of all elements that are matched by the
  # given CSS or XPath query.  The textual content is basically the HTML
  # with the tags stripped out, so for a piece of HTML like this:
  #
  #  <p class="comment">
  #   I <em>really</em> love <tt>assert_elements</tt>!
  #  </p>
  #  <p class="sidebar">
  #   <tt>assert_elements</tt> is the greatest.
  #  </p>
  #  <p class="comment">
  #   Testing is greatly enhanced with <tt>assert_elements</tt>.
  #  </p>
  #
  # Calling +tags('.comment')+ will return the array:
  #
  #  [
  #   "I really love assert_elements!",
  #   "Testing is greatly enhanced with assert_elements."
  #  ]
  #
  def tags(css_query)
    parsed_response.content_for_all(css_query)
  end
  
  # Returns the first HTML element matched by the given CSS/XPath query.
  # The element is a raw +Hpricot::Elem+ object, which provides all sorts of
  # possibilities for interesting manipulations.  See the Hpricot API docs
  # at http://code.whytheluckystiff.net/doc/hpricot/ for more details.
  #
  def element(css_query)
    parsed_response.search(css_query).first
  end
  
  # Returns an array of all the HTML elements matched by the given CSS/XPath
  # query.  The elements are returned as +Hpricot::Elem+ objects; see
  # +element+ for more details.
  #
  def elements(css_query)
    parsed_response.search(css_query)
  end
  
  # This is the workhorse of +HpricotTestHelper+.  It is capable of asserting
  # a variety of conditions about a block of HTML, and is also capable of
  # restricting the HTML searched by the calls in a block of code passed in.
  #
  # The basic flow of an +assert_elements+ call is as follows:
  #
  #  # First, we search for a set of elements within the HTML we've got;
  #  # Next, we make sure that the elements we've matched meet all the
  #    criteria that were set for us (more on valid criteria below);
  #  # Finally, if we've been given a block and all the criteria match,
  #    then we run the block against the restricted chunk of HTML, which just
  #    contains the HTML of the matched elements.
  #
  # = Validation Criteria =
  #
  # By default, +assert_elements+ will pass if at least one element is matched
  # by the CSS/XPath query you provide.  However, you often want to be more
  # specific about what qualifies as "good" HTML, so
  # +assert_elements+ takes any combination of the following qualifiers:
  #
  #  :text -- Only select elements whose inner text (that is, the contents of
  #     the selected element(s) with any inline HTML tags stripped out)
  #     equals the provided string or matches the provided regular expression.
  #  :html -- Only select elements whose inner HTML (the contents of the
  #     selected element(s)) equals the provided string or matches the
  #     provided regular expression.
  #  :count -- only pass if exactly this many elements are matched;
  #  :minimum -- only pass if at least this many elements are matched;
  #  :maximum -- only pass if no more than this many elements are matched.
  #
  # For example, if you wanted to only match paragraphs which contained the
  # word 'foo' in their text, and wanted to fail if more than 3 elements were
  # found, you could do:
  #
  #  assert_elements "p", :text => /foo/, :maximum => 3
  #
  # There are a range of shortcuts available, which do roughly what you'd
  # expect.  If you set +equality+ to be something of the following types, they
  # get mapped to the given criteria:
  #
  #  Numeric (N) -- :count => N
  #  Range (N..M) -- :minimum => N, :maximum => M
  #  String (S) -- :text => S
  #  Regexp (R) -- :text => R
  #  Nil -- :minimum => 1
  #  True -- :minimum => 1
  #  False -- :count => 0
  #
  # This means that the following assertion will pass if there's at least one
  # paragraph that contains the word foo:
  #
  #  assert_elements "p", /foo/
  #
  # While this will ensure that there's between 3 and 5 paragraphs in the
  # output:
  #
  #  assert_elements "p", 3..5
  #
  # You can mix these shortcuts with explicit criteria selectors, like this:
  #
  #  assert_elements "p", /foo/, 0..3
  #
  # Which will make sure there's no more than 3 paragraphs which contain the
  # string 'foo' in them.
  #
  # = Blocks =
  #
  # Like +assert_select+, +assert_elements+ can take a block of code to
  # execute within the context of selected element(s).  This block is only
  # run if all of the criteria for the +assert_elements+ call are met.  So,
  # if you ask +assert_elements+ to run a block of code like this:
  #
  #  assert_elements "p", :minimum => 3 do
  #    puts "I got here!"
  #  end
  #
  # Then "I got here!" will only be printed if there are at least three
  # paragraphs in the HTML.
  #
  # Within your block, the entire HTML that is available to other
  # +assert_elements+ and related calls (like +tag+ and +element+) is the
  # HTML elements which were selected by the initial +assert_elements+ call.
  # This is particularly useful when you want to do checks on a bunch of
  # elements under a certain higher-level element, like a form or table, like
  # this:
  #
  #  assert_elements "//form[@id='login_form']" do
  #    assert_elements "/form/input[@id='login_username']"
  #    assert_elements "/form/input[@id='login_password']"
  #    assert_elements "/form/input[@type='submit']"
  #  end
  #
  def assert_elements css_query, equality = nil, extra_equalities = {}, &block
    message = equality.delete(:message) if equality.is_a?(Hash)

    case equality
      when Numeric then equality = {:count => equality}
      when Range then equality = {:minimum => equality.to_a.first, :maximum => equality.to_a.last }
      when String then equality = {:text => equality}
      when Regexp then equality = {:text => equality}
      when NilClass then equality = {:minimum => 1}
      when TrueClass then equality = {:minimum => 1}
      when FalseClass then equality = {:count => 0}
      when Hash then nil
      else raise ArgumentError.new("Unknown type for equality specification, #{equality.class}")
    end

    equality.merge!(extra_equalities)

    els = get_elements(css_query, equality.reject {|k,v| ![:text,:html].include?(k) }) if els.nil?

    n = equality.delete(:count)
    equality[:minimum], equality[:maximum] = n, n if n
    
    equality.merge!({:minimum => 1}) if (equality.keys & [:minimum, :maximum]).empty?

    min, max = equality[:minimum], equality[:maximum]
    message ||= %(Expected #{count_description(min, max)} matching "#{css_query}", found #{els.length}.)
    assert els.size >= min, message if min
    assert els.size <= max, message if max
    if equality.keys.include?(:minimum)
      assert(els.size >= equality[:minimum], message)
    end
    if equality.keys.include?(:maximum)
      assert(els.size <= equality[:maximum], message)
    end

    # Block handler!
    if block
      self.dup.instance_eval do
        @response = @response.dup
        @response.body = els.to_html
        instance_eval &block
      end
    end
  end
  
  protected
  # produce a parse tree of the response.
  def parsed_response
    Hpricot.parse(@response.body)
  end

  # Run the CSS/XPath query, then filter out stuff that doesn't match the
  # text or HTML we want.
  def get_elements css_query, filters
    els = elements(css_query)
    case filters[:text]
      when String then els.reject! {|t| !t.should_contain(filters[:text]) }
      when Regexp then els.reject! {|t| !t.should_match(filters[:text]) }
    end
    case filters[:html]
      when String then els.reject! {|t| !t.html_should_contain(filters[:html]) }
      when Regexp then els.reject! {|t| !t.html_should_match(filters[:html]) }
    end
    els
  end

  private
  def count_description(min, max) #:nodoc:
    pluralize = lambda {|word, quantity| word << (quantity == 1 ? '' : 's')}
          
    if min && max
      if (max != min)
        "between #{min} and #{max} elements"
      else
        "#{min} #{pluralize['element', min]}"
      end
    elsif min && !(min == 1 && max == 1)
      "at least #{min} #{pluralize['element', min]}"
    elsif max
      "at most #{max} #{pluralize['element', max]}"
    end
  end
end
