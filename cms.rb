require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/content_for'

def get_files
end

get "/" do
  @files = Dir.glob("data/*").map do |path|
    File.basename(path)
  end
  
  erb :index
end

get "/:filename" do
  file_path = "data/" + params[:filename]

  headers["Content-Type"] = "text/plain"
  File.read(file_path)
end