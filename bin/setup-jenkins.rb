$stdout.sync = true

gems = %w{trollop watir cucumber simplecov rails whenever haml-rails sass-rails coffee-rails uglifier jquery-rails bootstrap-sass therubyracer bcrypt-ruby sqlite3 capybara rspec-rails sdoc}
gems.each do |g|
  begin
    system("gem install #{g}")
    Gem.clear_paths
    puts "Installed #{g}"
  rescue LoadError
    puts "Couldn't install #{g}"
  end
end

