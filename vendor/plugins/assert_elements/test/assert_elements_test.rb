#--
# Copyright (c) 2006 Assaf Arkin (http://labnotes.org)
# Under MIT and/or CC By license.
#++

require "#{File.dirname(__FILE__)}/abstract_unit"

unless defined?(ActionMailer)
  begin
    $:.unshift(File.dirname(__FILE__) + "/../../../actionmailer/lib")
    require 'action_mailer'
  rescue LoadError
    require 'rubygems'
    gem 'actionmailer'
  end
end

class AssertElementsTest < Test::Unit::TestCase
  class AssertElementsController < ActionController::Base
    def response_with=(content)
      @content = content
    end

    def response_with(&block)
      @update = block
    end

    def html()
      render :text=>@content, :layout=>false, :content_type=>Mime::HTML
      @content = nil
    end

    def rescue_action(e)
      raise e
    end
  end

  AssertionFailedError = Test::Unit::AssertionFailedError

  def setup
    @controller = AssertElementsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def assert_failure(message, &block)
    e = assert_raises(AssertionFailedError, &block)
    assert_match(message, e.message) if Regexp === message
    assert_equal(message, e.message) if String === message
  end

  #
  # Test assert elements.
  #

  def test_assert_elements
    render_html %Q{<div id="1"></div><div id="2"></div>}
    assert_elements "div", 2
    assert_failure(/Expected 1 element matching \"div\", found 2/) { assert_elements "div", 1 }
    assert_failure(/Expected 3 elements matching \"div\", found 2/) { assert_elements "div", 3 }
    assert_failure(/Expected at most 1 element matching \"div\", found 2/) { assert_elements "div", :maximum => 1 }
    assert_failure(/Expected at least 1 element matching \"p\", found 0/) { assert_elements "p" }
  end


  def test_equality_true_false
    render_html %Q{<div id="1"></div><div id="2"></div>}
    assert_nothing_raised               { assert_elements "div" }
    assert_raises(AssertionFailedError) { assert_elements "p" }
    assert_nothing_raised               { assert_elements "div", true }
    assert_raises(AssertionFailedError) { assert_elements "p", true }
    assert_raises(AssertionFailedError) { assert_elements "div", false }
    assert_nothing_raised               { assert_elements "p", false }
  end


  def test_equality_string_and_regexp
    render_html %Q{<div id="1">foo</div><div id="2">foo</div>}
    assert_nothing_raised               { assert_elements "div", "foo" }
    assert_raises(AssertionFailedError) { assert_elements "div", "bar" }
    assert_nothing_raised               { assert_elements "div", :text=>"foo" }
    assert_raises(AssertionFailedError) { assert_elements "div", :text=>"bar" }
    assert_nothing_raised               { assert_elements "div", /(foo|bar)/ }
    assert_raises(AssertionFailedError) { assert_elements "div", /foobar/ }
    assert_nothing_raised               { assert_elements "div", :text=>/(foo|bar)/ }
    assert_raises(AssertionFailedError) { assert_elements "div", :text=>/foobar/ }
    assert_raises(AssertionFailedError) { assert_elements "p", :text=>/foobar/ }
  end


  def test_equality_of_html
    render_html %Q{<p>\n<em>"This is <strong>not</strong> a big problem,"</em> he said.\n</p>}
    text = "\"This is not a big problem,\" he said."
    html = "<em>\"This is <strong>not</strong> a big problem,\"</em> he said."
    assert_nothing_raised               { assert_elements "p", text }
    assert_raises(AssertionFailedError) { assert_elements "p", html }
    assert_nothing_raised               { assert_elements "p", :html=>html }
    assert_raises(AssertionFailedError) { assert_elements "p", :html=>text }
  end


  def test_counts
    render_html %Q{<div id="1">foo</div><div id="2">foo</div>}
    assert_nothing_raised               { assert_elements "div", 2 }
    assert_failure(/Expected 3 elements matching \"div\", found 2/) do
      assert_elements "div", 3
    end
    assert_nothing_raised               { assert_elements "div", 1..2 }
    assert_failure(/Expected between 3 and 4 elements matching \"div\", found 2/) do
      assert_elements "div", 3..4
    end
    assert_nothing_raised               { assert_elements "div", :count=>2 }
    assert_failure(/Expected 3 elements matching \"div\", found 2/) do
      assert_elements "div", :count=>3
    end
    assert_nothing_raised               { assert_elements "div", :minimum=>1 }
    assert_nothing_raised               { assert_elements "div", :minimum=>2 }
    assert_failure(/Expected at least 3 elements matching \"div\", found 2/) do
      assert_elements "div", :minimum=>3
    end
    assert_nothing_raised               { assert_elements "div", :maximum=>2 }
    assert_nothing_raised               { assert_elements "div", :maximum=>3 }
    assert_failure(/Expected at most 1 element matching \"div\", found 2/) do
      assert_elements "div", :maximum=>1
    end
    assert_nothing_raised               { assert_elements "div", :minimum=>1, :maximum=>2 }
    assert_failure(/Expected between 3 and 4 elements matching \"div\", found 2/) do
      assert_elements "div", :minimum=>3, :maximum=>4
    end
  end

  def test_nested_assert_elements
    render_html %Q{<div id="1">foo</div><div id="2">foo</div>}
    assert_elements "div" do
      assert_equal 2, elements("div").size
      assert_elements elements("#1")
      assert_elements elements("#2")
    end
    assert_elements "div" do
      assert_elements "div" do
        assert_equal 2, elements("div").size
        # Testing in a group is one thing
        assert_elements "#1,#2"
        # Testing individually is another.
        assert_elements "#1"
        assert_elements "#2"
        assert_elements "#3", false
      end
    end
    
    assert_failure(/Expected at least 1 element matching \"#4\", found 0\./) do
      assert_elements "div" do
        assert_elements "#4"
      end
    end
  end


  def test_assert_elements_text_match
    render_html %Q{<div id="1"><span>foo</span></div><div id="2"><span>bar</span></div>}
    assert_elements "div" do
      assert_nothing_raised               { assert_elements "div", "foo" }
      assert_nothing_raised               { assert_elements "div", "bar" }
      assert_nothing_raised               { assert_elements "div", /\w*/ }
      assert_nothing_raised               { assert_elements "div", /\w*/, :count=>2 }
      assert_raises(AssertionFailedError) { assert_elements "div", :text=>"foo", :count=>2 }
      assert_nothing_raised               { assert_elements "div", :html=>"<span>bar</span>" }
      assert_nothing_raised               { assert_elements "div", :html=>"<span>bar</span>" }
      assert_nothing_raised               { assert_elements "div", :html=>/\w*/ }
      assert_nothing_raised               { assert_elements "div", :html=>/\w*/, :count=>2 }
      assert_raises(AssertionFailedError) { assert_elements "div", :html=>"<span>foo</span>", :count=>2 }
    end
  end

  #
  # Test elements.
  #


  def test_elements
    render_html %Q{<div id="1"></div><div id="2"></div>}
    assert 2, elements("div").size
    assert 0, elements("p").size
  end


  def test_nested_elements
    render_html %Q{<div id="1">foo</div><div id="2">foo</div>}
    assert_elements "div" do
      assert_equal 2, elements("div").size
      elements("div").each do |element|
        # Testing as a group is one thing
        assert !elements("#1,#2").empty?
        # Testing individually is another
        assert !elements("#1").empty?
        assert !elements("#2").empty?
      end
    end
  end

  def test_nested_elements_failure
    render_html %Q{<div></div>}
    assert_elements "div" do
      assert_failure(/Expected at least 1 element matching "span", found 0/) { assert_elements "span" }
    end
  end

  def test_nested_elements_failure_with_xpath
    render_html %Q{<div></div>}
    assert_elements "//div" do
      assert_failure(/Expected at least 1 element matching "\/\/span", found 0/) { assert_elements "//span" }
    end
  end

  def test_complex_xpath_query
    render_html %Q{<div></div>}
    assert_elements "//div" do
      assert_failure(/Expected at least 1 element matching "\/\/span\[@class='foo',@id='bar'\]", found 0/) { assert_elements "//span[@class='foo',@id='bar']" }
    end
  end

  def test_nested_xpath_queries
    render_html %Q{<html><body><ul id="one"><li><a href="/one">one</a></li></ul><ul id="two"><li><a href="/two">two</a></ul></ul></body></html>}
    
    # So we can pick out an anchor by href OK...
    assert_elements "//a[@href='/one']"
    
    # And we don't get anchors that don't exist...
    assert_failure(/./) { assert_elements("//a[@href='/three']") }
    
    # And we can pick out an anchor with it's associated list...
    assert_elements "//ul[@id='one']/li/a[@href='/one']"
    
    # And with the li glossed over...
    assert_elements "//ul[@id='one']//a[@href='/one']"
    
    # We fail when we're given a tree that doesn't exist in one hit, of course...
    assert_failure(/./) { assert_elements("//ul[@id='one']//a[@href='two']") }

    # But what about the world of nested elements?
    assert_elements "//ul[@id='one']" do
	   # We *do* have this link
      assert_elements "//a[@href='/one']"
      # But not this one
      assert_failure(/./) { assert_elements("//a[@href='/two']") }
      
      # And our XPath queries should be rooted at the ul we selected initially
      assert_elements "/ul/li/a[@href='/one']"
      # Not at the li level
      assert_failure(/./) { assert_elements "/li/a[@href='/one']" }
    end

    # Once we're out of the block, we should be back to testing the entire document
    assert_elements "//ul[@id='one']"
    assert_elements "//ul[@id='two']"
  end

  def test_multiple_requests
    render_html %Q{<div id="1">hi</div>}
    assert_elements "/div[@id='1']"
    assert_equal "hi", tag("/div[@id='1']")
    
    # We should have no parsed document at the moment
    assert_nil @assert_elements_parsed_document
    
    render_html %Q{<div id="2">hey there</div>}
    assert_elements "/div[@id='2']"
    assert_equal "hey there", tag("/div[@id='2']")
  end
    
  protected
    def render_html(html)
      @controller.response_with = html
      get :html
    end
end
