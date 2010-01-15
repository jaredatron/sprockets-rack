require 'sprockets'

class Sprockets::Rack

  OPTIONS = {
    :never_update          => false,
    :always_update         => false,
    :source_files          => [],
    :load_path             => [],
    :destination           => 'sprockets.js',
    :include_views         => false,
  }

  # Initialize the middleware.
  #
  # @param app [#call] The Rack application
  def initialize(app, options = {})
    @app = app
    @options = OPTIONS.merge(options)

    if @options[:include_views]
      require File.join(File.dirname(__FILE__),'rack/include_views')
      extend Sprockets::Rack::IncludeViews
      initialize_view_inclusion
    end

    @secretary = Sprockets::Secretary.new(@options)
  end

  # Process a request, checking the JavaScript files for changes
  # and update them if necessary.
  #
  # @param env The Rack request environment
  # @return [(#to_i, {String => String}, Object)] The Rack response
  def call(env)
    update  if needs_updating?
    @app.call(env)
  end

  private

  def root
    @options[:root] ||= '.'
  end

  def destination
    @options[:destination] ||= File.join(root,'sprockets.js')
    unless @options[:destination][0..0] == '/'
      @options[:destination] = File.join(root,@options[:destination])
    end
    @options[:destination]
  end

  def needs_updating?
    return true   if @options[:always_update]
    return false  if @options[:never_update]
    !defined?(@source_last_modified) || @source_last_modified < @secretary.source_last_modified || !File.exists?(destination)
  end

  # updates the destination source
  def update
    @secretary.reset!
    File.open(destination, 'w') do |file|
      file.write @secretary.concatenation.to_s
      @source_last_modified = @secretary.source_last_modified
    end
  end

end