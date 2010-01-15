require 'FileUtils'
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe SprocketsRack do

  passthrough_app = Proc.new{|env| env}
  env = {}

  def random_destination
    path = "tmp/sprocketized#{rand(100)}.js"
    FileUtils.rm(path)  if File.exists?(path)
    path
  end

  it "should instantiate a sprockets secretary with the given options" do
    Sprockets::Secretary.should_receive(:new).with({
      :never_update  => false,
      :always_update => false,
      :destination   => 'sprockets.js',
      :include_views => false,
      :another       => :option,
    })
    SprocketsRack.new(passthrough_app, {
      :never_update  => false,
      :always_update => false,
      :destination   => 'sprockets.js',
      :include_views => false,
      :another       => :option,
    })
  end

  describe "#root" do
    it "should default to '.'" do
      SprocketsRack.new(passthrough_app).send(:root).should == '.'
      SprocketsRack.new(passthrough_app,{:root => 'somewhere/else'}).send(:root).should == 'somewhere/else'
    end
  end

  describe "#destination" do
    it "should default to ':root/sprockets.js'" do
      SprocketsRack.new(passthrough_app).send(:destination).should == './sprockets.js'
      SprocketsRack.new(passthrough_app,{
        :root => 'someplace'
      }).send(:destination).should == 'someplace/sprockets.js'
    end
    it "should join :root and :destination" do
      SprocketsRack.new(passthrough_app,{
        :root => 'someplace',
        :destination => 'application.js'
      }).send(:destination).should == 'someplace/application.js'
      SprocketsRack.new(passthrough_app,{
        :root => 'someplace',
        :destination => '/tmp/application.js'
      }).send(:destination).should == '/tmp/application.js'
    end
  end

  describe "#call" do
    it "should take an env, pass it to the app and return that return value" do
      SprocketsRack.new(passthrough_app,{:destination => random_destination}).call(env).should == env
    end
  end

  describe "#needs_updating?" do
    it "should return true if :always_update => true" do
      SprocketsRack.new(passthrough_app, {:always_update => true}).send(:needs_updating?).should == true
    end

    it "should return false if :never_update => true" do
      SprocketsRack.new(passthrough_app, {:never_update => true}).send(:needs_updating?).should == false
    end

    it "should return true if we've never sprocketized before" do
      sprockets_rack = SprocketsRack.new(passthrough_app,{
        :source_files          => ['spec/javascripts/layout.js'],
        :destination           => random_destination,
      })
      sprockets_rack.send(:needs_updating?).should == true
      sprockets_rack.call(env)
      sprockets_rack.send(:needs_updating?).should == false
    end

    it "should return true if the source files mtimes change" do
      FileUtils.cp('spec/javascripts/layout.js', 'tmp/layout.js')
      File.utime(File.atime('tmp/layout.js'), File.mtime('tmp/layout.js') - 1000, 'tmp/layout.js')
      sprockets_rack = SprocketsRack.new(passthrough_app,{
        :source_files          => ['tmp/layout.js'],
        :destination           => random_destination,
      })
      sprockets_rack.send(:needs_updating?).should == true
      sprockets_rack.call(env)
      sprockets_rack.send(:needs_updating?).should == false
      FileUtils.touch('tmp/layout.js')
      sprockets_rack.send(:needs_updating?).should == true
    end

    it "should return true if the destination file does not exist" do
      destination = random_destination
      sprockets_rack = SprocketsRack.new(passthrough_app,{
        :source_files          => ['spec/javascripts/layout.js'],
        :destination           => destination,
      })
      sprockets_rack.send(:needs_updating?).should == true
      sprockets_rack.call(env)
      sprockets_rack.send(:needs_updating?).should == false
      FileUtils.rm(destination)
      File.exists?(destination).should == false
      sprockets_rack.send(:needs_updating?).should == true
    end
  end

  describe "#update" do
    it "should write to the destination file" do
      destination = random_destination
      sprockets_rack = SprocketsRack.new(passthrough_app,{
        :source_files          => ['spec/javascripts/layout.js'],
        :destination           => destination,
      })
      sprockets_rack.call(env)
      File.read(destination).should =~ /#{Regexp.escape(File.read('spec/javascripts/layout.js').split("\n").first)}/
      FileUtils.rm(destination)
    end
  end

end
