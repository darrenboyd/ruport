require 'test/unit'
require 'ruport'

###########################################################################
#
#  NOTE:
#
#  As it stands, we haven't found a more clever way to test the formatting
#  system than to just create a bunch of renderers and basic formatters for
#  different concepts we're trying to test.  Patches and ideas welcome:
#
#  list.rubyreports.org
############################################################################

#============================================================================
# These two renderers represent the two styles that can be used when defining
# renderers in Ruport.  The OldSchoolRenderer approach has largely been
# deprecated, but still has uses in edge cases that we need to support.
#============================================================================

class OldSchoolRenderer < Ruport::Renderer

  def run
    formatter do
      build_header
      build_body
      build_footer
    end
  end

end               

class VanillaRenderer < Ruport::Renderer
  stage :header,:body,:footer
end


# This formatter implements some junk output so we can be sure
# that the hooks are being set up right.  Perhaps these could
# be replaced by mock objects in the future.
class DummyText < Ruport::Formatter
  
  renders :text, :for => OldSchoolRenderer
  
  def prepare_document
    output << "p"
  end

  def build_header
    output << "header\n"
  end

  def build_body
    output << "body\n"
  end

  def build_footer
    output << "footer\n"
  end

  def finalize_document
    output << "f"
  end
end   


class TestRenderer < Test::Unit::TestCase

  def test_trivial
    actual = OldSchoolRenderer.render(:text)
    assert_equal "header\nbody\nfooter\n", actual
  end

  def test_using_io
    require "stringio"
    out = StringIO.new
    a = OldSchoolRenderer.render(:text) { |r| r.io = out }
    out.rewind
    assert_equal "header\nbody\nfooter\n", out.read
    assert_equal "", out.read
  end

  def test_formats
    assert_equal( {}, Ruport::Renderer.formats )
    assert_equal( { :text => DummyText },OldSchoolRenderer.formats )
  end

  def test_method_missing
    actual = OldSchoolRenderer.render_text
    assert_equal "header\nbody\nfooter\n", actual
  end

  def test_formatter
    # normal instance mode
    rend = OldSchoolRenderer.new
    rend.send(:use_formatter,:text)

    assert_kind_of Ruport::Formatter, rend.formatter
    assert_kind_of DummyText, rend.formatter

    # render mode
    OldSchoolRenderer.render_text do |r|
      assert_kind_of Ruport::Formatter, r.formatter
      assert_kind_of DummyText, r.formatter
    end

    assert_equal "body\n", rend.formatter { build_body }.output

    rend.formatter.clear_output
    assert_equal "", rend.formatter.output
  end  
  
  def test_options_act_like_indifferent_hash
     opts = Ruport::Renderer::Options.new
     opts.foo = "bar"
     assert_equal "bar", opts[:foo]
     assert_equal "bar", opts["foo"]    
     
     opts["f"] = "bar"
     assert_equal "bar", opts[:f]
     assert_equal "bar", opts.f
     assert_equal "bar", opts["f"]
     
     opts[:apple] = "banana"
     assert_equal "banana", opts.apple
     assert_equal "banana", opts["apple"]
     assert_equal "banana", opts[:apple]
  end     
  
end


class TestFormatterWithLayout < Test::Unit::TestCase
  # This formatter is meant to check out a special case in Ruport's renderer,
  # in which a layout method is called and yielded to when defined
  class WithLayout < DummyText
     renders :text_with_layout, :for => VanillaRenderer 
     
     def layout     
       output << "---\n"
       yield
       output << "---\n"
     end
     
  end

  def test_layout
     assert_equal "---\nheader\nbody\nfooter\n---\n", 
                  VanillaRenderer.render_text_with_layout
  end

end


class TestRendererWithManyHooks < Test::Unit::TestCase
  # This provides a way to check several hooks that Renderer supports
  class RendererWithManyHooks < Ruport::Renderer

    add_format DummyText, :text

    prepare :document

    option :subtitle, :subsubtitle

    stage :header
    stage :body
    stage :footer

    finalize :document

    def setup
      options.apple = true
    end

  end

  def test_hash_options_setters
    a = RendererWithManyHooks.render(:text, :subtitle => "foo",
                                       :subsubtitle => "bar") { |r|
      assert_equal "foo", r.options.subtitle
      assert_equal "bar", r.options.subsubtitle
    }
  end

  def test_data_accessors
   a = RendererWithManyHooks.render(:text, :data => [1,2,4]) { |r|
     assert_equal [1,2,4], r.data
   }
  
   b = RendererWithManyHooks.render_text(%w[a b c]) { |r|
     assert_equal %w[a b c], r.data
   }
  
   c = RendererWithManyHooks.render_text(%w[a b f],:snapper => :red) { |r|
     assert_equal %w[a b f], r.data
     assert_equal :red, r.options.snapper
   }
  end

  def test_stage_helper
    assert RendererWithManyHooks.stages.include?('body')
  end
 
  def test_finalize_helper
    assert_equal :document, RendererWithManyHooks.final_stage
  end

  def test_prepare_helper
   assert_equal :document, RendererWithManyHooks.first_stage
  end

  def test_finalize_again
   assert_raise(Ruport::Renderer::StageAlreadyDefinedError) { 
     RendererWithManyHooks.finalize :report 
   }
  end

  def test_prepare_again
   assert_raise(Ruport::Renderer::StageAlreadyDefinedError) { 
     RendererWithManyHooks.prepare :foo 
   }
  end

  def test_renderer_using_helpers
   actual = RendererWithManyHooks.render(:text)
   assert_equal "pheader\nbody\nfooter\nf", actual

   actual = RendererWithManyHooks.render_text
   assert_equal "pheader\nbody\nfooter\nf", actual
  end

  def test_setup
   actual = false
   RendererWithManyHooks.render_text { |r|
     actual = r.options.apple
   }
   assert actual
  end

  def test_option_helper
   RendererWithManyHooks.render_text do |r|
     r.subtitle = "Test Report"
     assert_equal "Test Report", r.options.subtitle
   end
  end

  def test_required_option_helper
   a = RendererWithManyHooks.dup
   a.required_option :title

   a.render_text do |r|
     r.title = "Test Report"
     assert_equal "Test Report", r.options.title
   end

  end

  def test_without_required_option
   a = RendererWithManyHooks.dup
   a.required_option :title

   assert_raise(Ruport::Renderer::RequiredOptionNotSet) { a.render(:text) }
  end
 
end


class TestRendererWithRunHook < Test::Unit::TestCase

  class RendererWithRunHook < Ruport::Renderer
    
    include AutoRunner

    add_format DummyText, :text

    required_option :foo,:bar
    stage :header
    stage :body
    stage :footer

    def run
      formatter.output << "|"
    end

  end

  def test_renderer_with_run_hooks
    assert_equal "|header\nbody\nfooter\n", 
       RendererWithRunHook.render_text(:foo => "bar",:bar => "baz")
  end

end


class TestRendererWithHelperModule < Test::Unit::TestCase

  class RendererWithHelperModule < VanillaRenderer

    add_format DummyText, :stub

    module Helpers
      def say_hello
        "Hello Dolly"
      end
    end
  end   

  def test_renderer_helper_module
    RendererWithHelperModule.render_stub do |r|
      assert_equal "Hello Dolly", r.formatter.say_hello
    end
  end
end


class TestMultiPurposeFormatter < Test::Unit::TestCase
  # This provides a way to check the multi-format hooks for the Renderer
  class MultiPurposeFormatter < Ruport::Formatter 

     renders [:html,:text], :for => VanillaRenderer

     def build_header
       a = 10

       text { output << "Foo: #{a}\n" }
       html { output << "<b>Foo: #{a}</b>\n" } 
     end

     def build_body
       html { output << "<pre>\n" }
       output << options.body_text
       html { output << "\n</pre>\n" }
     end

  end   

  def test_multi_purpose
    text = VanillaRenderer.render_text(:body_text => "foo")
    assert_equal "Foo: 10\nfoo", text
    html = VanillaRenderer.render_html(:body_text => "bar")
    assert_equal "<b>Foo: 10</b>\n<pre>\nbar\n</pre>\n",html
  end


  def test_method_missing_hack_formatter
    assert_equal [:html,:text], MultiPurposeFormatter.formats

    a = MultiPurposeFormatter.new
    a.format = :html
    
    visited = false
    a.html { visited = true }

    assert visited
    
    visited = false
    a.text { visited = true }
    assert !visited

    assert_raises(NoMethodError) do
      a.pdf { 'do nothing' }
    end
  end

end


class TestFormatterErbHelper < Test::Unit::TestCase
  class ErbFormatter < Ruport::Formatter
     
    renders :terb, :for  => VanillaRenderer
    
    def build_body    
       # demonstrate local binding
       @foo = "bar"                         
       if options.binding
         output << erb("Binding Override: <%= reverse %>", 
                       :binding => options.binding) 
       else   
         output << erb("Default Binding: <%= @foo %>") 
       end   
    end
    
  end

   #FIXME: need to test file

   def test_self_bound
     assert_equal "Default Binding: bar", VanillaRenderer.render_terb
   end
   
   def test_custom_bound
     a = [1,2,3]
     arr_binding = a.instance_eval { binding }
     assert_equal "Binding Override: 321", 
                   VanillaRenderer.render_terb(:binding => arr_binding)
   end
end


