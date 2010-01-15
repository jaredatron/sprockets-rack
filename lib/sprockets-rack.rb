require 'sprockets'

class SprocketsRack

  OPTIONS = {
    :never_update  => false,
    :always_update => false,
    :destination   => 'sprockets.js',
  }

  def initialize(app, options = {})
    @app = app
    @options = OPTIONS.merge(options)
    @secretary = Sprockets::Secretary.new(@options)
  end

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