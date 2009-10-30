require 'rubygems'
require 'sinatra'
require 'haml'
require 'dm-core'
require 'dm-aggregates'

helpers do

def partial(name, options = {})
  item_name = name.to_sym
    counter_name = "#{name}_counter".to_sym
      if collection = options.delete(:collection)
	          collection.enum_for(:each_with_index).collect do |item,index|
		        haml_partial name, options.merge(:locals => {item_name => item, counter_name => index+1})
			    end.join
			      elsif object = options.delete(:object)
			          haml_partial name, options.merge(:locals => {item_name => object, counter_name => nil})
				    else
					        haml "_#{name}".to_sym, options.merge(:layout => false)
						  end
						  end
end

enable :sessions

DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/data.db")

class Chapter
  include DataMapper::Resource
  property :id, Serial
  property :title, String
  property :body, Text
  property :created_at, DateTime
  
  has n, :comments
end

class Comment
  include DataMapper::Resource
  property :id, Serial
  property :tags, Text
  property :owner, String
  property :body, String
  
  belongs_to :chapter
end

#Chapter.auto_migrate! 
#Comment.auto_migrate!

get '/' do
  haml :index 
end

get "/edit_chapter/:id" do
  @id = params[:id]

  haml :edit_chapter
end

get "/new_chapter" do
  haml :new_chapter
end

post "/new_chapter" do
  @chapter = Chapter.new
  @chapter.title = params[:title]
  @chapter.body = params[:body]
  @chapter.save

  redirect "/show_chapter/#{@chapter.id}"
end

get "/show_chapter/:id" do
  @chapter = Chapter.get(params[:id])
  @count = Chapter.count
  haml :show_chapter

end

get "/chapters" do
  @chapters = Chapter.all
  haml :chapters
end

get '/comment/:chapter' do
   @chapter = params[:chapter]
   haml :comment
end

post '/comment/:chapter' do
  comment = Comment.new
  comment.attributes = { :tags => params[:tags], :owner => params[:owner], :body => params[:body]}
  #comment.save
  c = Chapter.get(params[:chapter])
  c.comments << comment
  c.save
  session["owner"] = params[:owner]
  redirect "/show_chapter/#{params[:chapter]}" 
end
