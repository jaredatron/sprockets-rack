require 'sprockets'
require 'tempfile'

module Sprockets::Rack::IncludeViews

  OPTIONS = Sprockets::Rack::OPTIONS.merge!({
    :controller_expression => 'CONTROLLER',
    :action_expression     => 'ACTION',
  })

  def initialize_view_inclusion
    @options[:tmp] ||= File.join(root,'tmp')
    @options[:views] ||= 'app/views'
    @options[:source_files].push(views_tempfile.path)
    @options[:load_path].unshift(@options[:views])
  end

  def call(env)
    update_views  if views_need_updating?
    super
  end

  private
  
  def views_tempfile
    @views_tempfile ||= ::Tempfile.new("views", @options[:tmp])
  end

  # regenerates the temp javascript file that requires all the js files found in the views
  # wrapping them in `if (controller && action)` statments
  def update_views
    source_files = find_js_files_in_views

    javascript = ";\n\n" +
    "/* =====================================\n" +
    "/* ==== VIEW CONDITIONAL JAVASCRIPT ====\n" +
    "/* ===================================== */\n\n"

    javascript << source_files.map do |source_file|
      controller, action = source_file.sub(/\.js$/,'').split('/')
      "if (#{@options[:controller_expression]} == '#{controller}' && #{@options[:action_expression]} == '#{action}'){\n\n" +
      "//= require <#{File.join(@options[:views],source_file)}>\n\n" +
      "} /* end if controller:'#{controller}' && action:'#{action}' */\n\n"
    end.join("\n")

    javascript << "\n\n" +
    "/* ============================================\n" +
    "/* ==== END OF VIEW CONDITIONAL JAVASCRIPT ====\n" +
    "/* ============================================ */\n\n"

    views_tempfile.truncate(0)
    views_tempfile.write(javascript)
    views_tempfile.flush

    @source_files = source_files
    @mtimes = source_files.map{|f| File.mtime(File.join(@options[:views],f)) }
  end

  def views_need_updating?
    # yes if we have not compiled since the app was started
    return true  unless defined?(@source_files) and defined?(@mtimes)

    current_source_files = find_js_files_in_views
    # yes, if the source files have changed
    return true  if current_source_files.sort != @source_files.sort

    current_mtimes = current_source_files.map{|f| File.mtime(File.join(@options[:views],f)) }
    destination_file_mtime = views_tempfile.mtime
    # yes, if any source files were modified after the last time we compiled
    return true  if current_mtimes.any?{|t| t > destination_file_mtime }

    # yes, if any source file mtimes have changed
    return true  if @source_files.any? do |source_file|
      last_mtime = @mtimes[@source_files.index(source_file)]
      current_mtime = current_mtimes[current_source_files.index(source_file)]
      last_mtime != current_mtime
    end

    false
  end

  def find_js_files_in_views
    Dir[File.join(@options[:views],'*/[^_]*.js')].map do |path|
      path.sub(@options[:views].sub(/\/*$/,'/'),'')
    end
  end

end