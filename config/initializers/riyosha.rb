# encoding: utf-8

Rails.application.config.to_prepare do
  Riyosha.configure do |config|
    config.url      = Toshokan::Application.config.auth[:api_url]
  end

  if Rails.application.config.auth[:stub]
    Riyosha.config.test_mode = true
    Riyosha.config.add_mock('1234', {
        'id'         => '1234',
        'email'      => 'someone@example.com',
        'dtu'        => {
          'firstname' => 'Firstname',
          'lastname'  => 'Lastname',
          'user_type' => 'dtu_empl'
        }
      }
    )
  end
end
