require 'rubygems'
require 'sinatra'
require 'haml'
require 'dm-core'
require 'dm-aggregates'

gem 'ruby-openid', '>=2.1.2'
require 'openid'
require 'openid/store/filesystem'

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
  property :parent, Integer, :default => 0 
  property :created_at, DateTime
  property :modified_at, DateTime

  belongs_to :chapter
end

#Chapter.auto_upgrade! 
#Comment.auto_upgrade!
  def openid_consumer
    @openid_consumer ||= OpenID::Consumer.new(session,
        OpenID::Store::Filesystem.new("#{File.dirname(__FILE__)}/tmp/openid"))  
  end
 
  def root_url
    request.url.match(/(^.*\/{2}[^\/]*)/)[1]
  end
get '/' do
  @chapters = Chapter.all
  @chapter_count = Hash.new
  @chapters.each do |chapter|
    @chapter_count[chapter.id] = chapter.comments.count
  end 
  @most_commented = @chapter_count.sort{|a,b| a[1]<=>b[1]}.reverse
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

get '/login' do    
  haml :login
end

post '/login/openid' do
  openid = params[:openid_identifier]
  begin
    oidreq = openid_consumer.begin(openid)
  rescue OpenID::DiscoveryFailure => why
    "Sorry, we couldn't find your identifier '#{openid}'"
  else
    oidreq.add_extension_arg('sreg','required','email')	  
    redirect oidreq.redirect_url(root_url, root_url + "/login/openid/complete")
  end
end

get '/login/openid/complete' do
  oidresp = openid_consumer.complete(params, request.url)

  case oidresp.status
    when OpenID::Consumer::FAILURE
      "Did not work ;_;"
    when OpenID::Consumer::SETUP_NEEDED
      "Request failed, setup needed"
    when OpenID::Consumer::CANCEL
      "Login cancelled."
    when OpenID::Consumer::SUCCESS
      "Login successfull! Hallo
      #{params.to_s},#{oidresp.extension_response('http://openid.net/sreg/1.0',false).to_s}"
  end
end
