require File.dirname(__FILE__) + '/abstract_unit'

class HpricotTestHelperTest < Test::Unit::TestCase
	class AssertElementsController
		attr_accessor :body
	end

	def setup
		@response = AssertElementsController.new
	end

	def assert_failure(message, &block)
		e = assert_raise(Test::Unit::AssertionFailedError, &block)
		assert_match(message, e.message) if Regexp === message
		assert_equal(message, e.message) if String === message
	end
	
	def test_trivial_assert_element
		@response.body = "<html><head><title>Foo</title></head><body></body></html>"
		
		assert_elements("//title")
		assert_equal "Foo", tag("//title")
		assert_equal "Foo", element("//title").inner_html
		assert_failure(/./) { assert_elements("//h1") }
	end

	def test_tag_with_no_match
		@response.body = "<div>foo</div>"
		
		assert_nil tag("#nonexistent")
	end
end
