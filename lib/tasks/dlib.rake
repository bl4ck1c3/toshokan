desc "Read dlib export yaml and create contents in toshokan database"

task :import_from_dlib, [:filename] => :environment do |t, args|
  # load data
  args.with_defaults(:filename => "/tmp/dlib.yaml")
  dlib = load_user_data(args.filename)

  # connect to solr
  solr = RSolr.connect(Blacklight.solr_config)

  # process data
  dlib.each do |cwis, data| 
    puts "Processing data for user #{cwis}"

    user = ensure_user_exists(cwis)
    next unless user
    
    puts '  - bookmarks and tags'
    data[:records].each do |record|
      create_bookmark_and_tags(user, record, solr)
    end

    puts '  - saved searches'
    create_saved_searches(user, data[:saved_searches], true, false)

    puts '  - search alerts'
    create_saved_searches(user, data[:search_alerts], false, true)

    puts '  - journal alerts'
    data[:journal_alerts].each do |alert|      
      create_journal_alert(user, alert, solr)
    end
  end
end

def load_user_data(path)
  data = YAML.load(File.open(path)).with_indifferent_access

  puts "users: #{data.size}"
  [:records, :saved_searches, :search_alerts, :journal_alerts].each do |key|
    puts "#{key}: #{data.map{|cwis,u| u[key].size}.inject(0, :+)}"
  end
  data
end

def ensure_user_exists(cwis)
  ## Make sure that the user exists
  user_data = Riyosha.find_or_create_by_cwis(cwis)
  if user_data
    User.create_or_update_with_user_data(:cas, user_data)
  else
    nil
  end
end

def create_bookmark_and_tags(user, record, solr)
  document = get_document_for_record(record, solr)
  
  if document
    user.bookmark(document)
    record[:tags].each do |tag|
      puts "      #{tag}"
      user.tag(document, tag)
    end
  end
end

def get_document_for_record(record, solr)
  record_id = record[:id]
  tags      = record[:tags]
  fq = case record[:type]
       when 'article'
         ["member_id_ss:#{record_id}"]
       when 'journal'
         ["issn_ss:#{record_id}"]
       when 'book'
         ["member_id_ss:#{record_id}"]
       end
  
  fq << "access_ss:dtu"
  params = {:fq => fq}
  result = solr.toshokan(:params => params).with_indifferent_access
  document = begin 
               id = result[:response][:docs].first[:cluster_id_ss].first
               Hashie::Mash.new({ :id => id })
             rescue => e
               # puts e.class
               # puts e.message
               # puts e.backtrace
             end
  if document
    puts "    #{record[:type]}: #{record[:id]} => #{document.id}"
  else
    puts "    #{record[:type]}: #{record[:id]} => NOT FOUND"
  end
  document
end

def create_saved_searches(user, searches, saved, alerted)

  # note: Issued date in search history will be import date
  searches.each do |search|        

    unless disallowed_syntax(search["query"])
  
      params = {}
      params[:q] = transform_syntax(search["query"])

      if search["type"] != "all"
        # remove plural from type (articles => article)
        params[:f] = {"format" => [search["type"].chop]}.with_indifferent_access
      end

      # hack to not set default search_field keyword      
      params[:search_field] = "all_fields"

      new_search = Search.create(:query_params => params)      
      if search.has_key?("title") && search["title"] != search["query"]
        new_search.title = search["title"]
      end
      
      # TODO should controller, action and locale be set?
      new_search.saved = saved
      new_search.alerted = alerted
      user.searches << new_search
    end
  end    
  user.save
  puts "    imported #{searches.length} searches"
end

def disallowed_syntax(query)
  /^id:\d*/ =~ query
end

def transform_syntax(query)
  # remove exact match
  query.gsub!(/(journaltitle|jo)=/, '\1:')

  query
end

def create_journal_alert(user, dlib_alert, solr)
  
  result = solr.toshokan(
    :params => {:q => dlib_alert.to_s, :fl => 'title_ts', :fq => 'format:journal', :rows => 1, :facet => false})

  if result['response']['numFound'] > 0 
    params = {:query => dlib_alert, :name => result['response']['docs'].first['title_ts'].first}
    alert = Alert.new(params, user)
    if !alert.save
      puts "Could not save alert #{alert.inspect}"
    end
  else
    puts "ISSN #{dlib_alert} could not be found in index"
  end
end