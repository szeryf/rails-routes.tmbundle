require "#{ENV['TM_SUPPORT_PATH']}/lib/textmate.rb"
require "#{ENV['TM_SUPPORT_PATH']}/lib/ui.rb"
require "#{ENV['TM_SUPPORT_PATH']}/lib/progress.rb"
require "#{ENV['TM_SUPPORT_PATH']}/lib/exit_codes.rb"
require "#{ENV['TM_SUPPORT_PATH']}/lib/escape.rb"

require 'rubygems'
require 'active_support'
require 'action_controller'

def setup
  input = STDIN.read
  if input.empty?
    input = TextMate::UI.request_string( :title   => "Enter path",
                                         :prompt  => "Enter path or url expression:",
                                         :default => "edit_user_path" ).strip
  end

  unless input =~ /(.+)_(path|url)/
    TextMate.exit_show_tool_tip "Input should end with _path or _url: #{input}"
  end

  path = $1.to_sym

  def req f, d
    d.parameters = {'summary' => "loading #{f}"}
    require "#{ENV['TM_PROJECT_DIRECTORY']}/config/#{f}"
  end

  TextMate.call_with_progress({}) do |dialog|
    begin
      req 'boot.rb', dialog
      req 'routes.rb', dialog
    rescue
      # do it the hard way :(
      req 'environment.rb', dialog
    end
  end

  route = ActionController::Routing::Routes.named_routes[path]
  TextMate.exit_show_tool_tip "No definition for #{path}" unless route

  begin
    defaults   = route.defaults
    controller = defaults[:controller]
    action     = defaults[:action]
  rescue Exception => e
    TextMate.exit_show_tool_tip "Expected defaults hash, got: #{defaults.inspect}\nException: #{e}"
  end

  return controller, action
end

def find_views controller, action
  Dir["#{ENV['TM_PROJECT_DIRECTORY']}/app/views/#{controller}/#{action}*"]
end

def find_controller controller
  "#{ENV['TM_PROJECT_DIRECTORY']}/app/controllers/#{controller}_controller.rb"
end

def choose files
  idx = if files.size > 1
    items = files.map{|f| f.gsub(ENV['TM_PROJECT_DIRECTORY'] + '/', '')}
    TextMate::UI.menu(items) or TextMate.exit_discard
  else
    0
  end
  files[idx]
end

def find_line_number file, action
  if file =~ /_controller\.rb$/
    # FIXME this only works in Ruby >= 1.8.7
    line_no = 1 + IO.readlines(file).index { |line| line =~ /def\b.*\b#{action}\b/ } rescue 0
    #line_no = 0
    #IO.readlines(file).each do |line|
  	#line_no += 1
  	#break if line =~ /def\b.*\b#{action}\b/
    #end
  end
end