require 'redmine'

class LibrarySupport
  include Configured

  def self.redmine
    Redmine.new LibrarySupport.url, LibrarySupport.api_key
  end

  def self.submit_failed_request order, reason = nil
    return unless order.user.dtu?

    send_mail_link = send_mail_link_for order.user, {
      'subject' => "Manual processing of your request: \"#{order.document['title_ts'].first}\"",
      'body'    => "Your request of \"#{order.document['title_ts'].first}\" has gone to manual processing",
    }

    issue_description = []
    issue_description << "#{phonebook_link_for(order.user) || user}, #{send_mail_link}, requested the following but the request was cancelled from the supplier:\n" if order.user
    issue_description << '<pre>' 
    issue_description << order.document.reject {|k,vs| k.to_s == 'open_url' || vs.blank?}
                                       .collect {|k,vs| "#{I18n.t "toshokan.catalog.show_field_labels.#{k}"}:\n   #{vs.first}"}
                                       .join("\n")
    issue_description << '</pre>'
    issue_description << "\nCancel reason: #{reason}" if reason

    issue = {
      :project_id    => LibrarySupport.project_ids[:failed_requests],
      :subject       => "#{order.user} requests \"#{order.document['title_ts'].first}\"",
      :description   => issue_description.join("\n"),
      :custom_fields => [
        LibrarySupport.custom_fields[:failed_from].merge({
          :value => failed_from_for(order.supplier),
        }),
        LibrarySupport.custom_fields[:dtu_unit].merge({
          :value => dtu_unit_for(order.user),
        }),
      ]
    }

    logger.debug "Creating redmine issue:\n#{issue}"
    response = redmine.create_issue issue

    if response.try :[], "issue"
      order.order_events << OrderEvent.new(:name => 'delivery_manual', :data => response['issue']['id'])
      order.save!
    else
      logger.error "Error submitting failed order to library support Redmine. Redmine response:\n#{response || 'nil'}"
      raise
    end
  end

  def self.submit_assistance_request user, assistance_request
    genre            = assistance_request.genre
    title            = assistance_request.title
    author           = assistance_request.author

    item_description = description_for assistance_request, genre

    # Append indented user notes to item description
    item_description += "\n---\nNotes from user:\n   #{assistance_request.notes.gsub /\n/, "\n   "}\n" unless assistance_request.notes.blank?

    send_mail_link = send_mail_link_for user, {
      'subject'  => "Regarding your #{genre.to_s.gsub /_/, ' '} request",
      'body'     => "\"#{title}\" by #{author}",
    }

    issue_description = []
    issue_description << "User #{phonebook_link_for user} ( CWIS: #{user.user_data['dtu']['matrikel_id']}; #{send_mail_link} ) requests the following:"
    issue_description << "<pre>\n#{item_description}\n</pre>"

    issue = {
      :project_id    => LibrarySupport.project_ids[genre],
      :description   => issue_description.join("\n\n"),
      :subject       => "#{user} requests \"#{title}\"",
      :custom_fields => [
        LibrarySupport.custom_fields[:dtu_unit].merge({
          :value => dtu_unit_for(user),
        }),
        LibrarySupport.custom_fields[:book_suggest].merge({
          :value => (assistance_request.book_suggest ? 'Yes' : 'No'),
        }),
      ],
    }

    case assistance_request.auto_cancel
    when '14'
      issue[:due_date] = Time.now.to_date + 14
    when '30'
      issue[:due_date] = Time.now.to_date + 30
    end

    response = redmine.create_issue issue
    logger.debug "Redmine response:\n#{response}"
    if response
      assistance_request.library_support_issue = response['issue']['id']
      assistance_request.save!
    end
  end

  def self.phonebook_link_for user
    "\"#{user}\":http://www.dtu.dk/Service/Telefonbog/Person?id=#{user.user_data['dtu']['matrikel_id']}&tab=1" if user.dtu?
  end

  def self.send_mail_link_for user, local_params = {}
    return unless user.dtu?

    params = {
      'reply-to' => LibrarySupport.reply_to,
    }.merge local_params

    "\"Send email\":mailto:#{user.email}?#{params.collect {|k,v| "#{k}=#{URI.escape v}"}.join '&'}"
  end

  def self.description_for assistance_request, genre
    sections = 
      case genre
      when :journal_article
        {
          :article => [:title, :author, :doi],
          :journal => [:title, :issn, :volume, :issue, :year, :pages],
        }
      when :conference_article
        {
          :article    => [:title, :author, :doi],
          :conference => [:title, :location, :isxn, :year, :pages],
        }
      when :book
        {
          :book => [:title, :year, :author, :edition, :doi, :isbn, :publisher],
        }
      else
        logger.error "Unknown assistance request genre: #{genre || 'nil'}"
        raise ArgumentError.new "genre should be one of :journal_article, :conference_article or :book, but was #{genre || 'nil'}"
      end

    result = []
    sections.each do |section, fields|
      section_result = []
      fields.each do |field|
        value = assistance_request.send "#{section}_#{field}"
        section_result << "#{section.capitalize} #{field}:\n   #{value.gsub /\n/, "\n   "}" unless value.blank?
      end
      result << section_result.join("\n")
    end
    result.join "\n---\n"
  end

  def self.failed_from_for supplier
    {
      :rd  => 'Reprints Desk',
      :dtu => 'DTU Library - local scan',
    }[supplier]
  end

  def self.dtu_unit_for user
    return unless user.dtu?
    {
      'stud'    => 'Students',
      '25'      => 'DTU Aqua',
      'NNFCB'   => 'DTU Biosustain',
      '54'      => 'DTU Executive School of Business',
      '59'      => 'DTU Cen',
      '28'      => 'DTU Chemical Engineering',
      '26'      => 'DTU Chemistry',
      '11'      => 'DTU Civil Engineering',
      '1'       => 'DTU Compute',
      'Danchip' => 'DTU Danchip',
      'IHK'     => 'DTU Diplom',
      '31'      => 'DTU Electrical Engineering',
      '47'      => 'DTU Energy Conversion',
      '12'      => 'DTU Environment',
      '23'      => 'DTU Food',
      '34'      => 'DTU Fotonik',
      '2'       => 'DTU Informatics',
      '58'      => 'DTU Library',
      '42'      => 'DTU Management Engineering',
      '41'      => 'DTU Mechanical Engineering',
      '33'      => 'DTU Nanotech',
      'NATLAB'  => 'DTU Natlab',
      '48'      => 'DTU Nutech',
      '10'      => 'DTU Physics',
      '30'      => 'DTU Space',
      '27'      => 'DTU Systems Biology',
      '13'      => 'DTU Transport',
      '24'      => 'DTU Vet',
      '46'      => 'DTU Wind Energi',
      '7'       => 'Others',
    }[user.user_data["dtu"]["org_units"].first]
  end
end